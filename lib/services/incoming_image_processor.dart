import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/account_entry.dart';
import '../models/group_entry.dart';
import 'entry_creation_service.dart';
import 'log_service.dart';
import 'qr_image_scanner.dart';

/// A file received from an external source before it has been processed.
///
/// Android share intake delivers this through the method channel; desktop drop
/// intake builds it after copying the dropped file into the app cache.
class IncomingImageDescriptor {
  const IncomingImageDescriptor.image({
    required this.path,
    this.mimeType,
    this.name,
  }) : rejectionReason = null;

  const IncomingImageDescriptor.rejected(this.rejectionReason)
      : path = null,
        mimeType = null,
        name = null;

  final String? path;
  final String? mimeType;
  final String? name;
  final String? rejectionReason;

  bool get isRejected => rejectionReason != null;

  factory IncomingImageDescriptor.fromMap(Map<Object?, Object?> map) {
    final kind = map['kind']?.toString();
    if (kind == 'image') {
      return IncomingImageDescriptor.image(
        path: map['path']?.toString() ?? '',
        mimeType: map['mimeType']?.toString(),
        name: map['name']?.toString(),
      );
    }
    return IncomingImageDescriptor.rejected(
      map['reason']?.toString() ?? 'unsupported',
    );
  }
}

/// Why an accepted image did not produce an account.
enum IncomingImageFailureKind {
  noQr,
  invalidQr,
  unreadable,
  serverMissing,
}

/// Typed result of processing one shared or dropped image.
sealed class IncomingImageOutcome {
  const IncomingImageOutcome();
}

final class IncomingImageSuccess extends IncomingImageOutcome {
  const IncomingImageSuccess(this.entry);

  /// Server entry when the upload succeeded, or the local entry marked as
  /// pending when the server could not be reached.
  final AccountEntry entry;
}

final class IncomingImageFailure extends IncomingImageOutcome {
  const IncomingImageFailure(this.kind, {this.detail});

  final IncomingImageFailureKind kind;
  final String? detail;
}

/// Scans one incoming image and, when it holds a valid OTP QR, creates and
/// uploads the account through the same services as the gallery flow.
class IncomingImageProcessor {
  const IncomingImageProcessor();

  /// Upper bound shared with the Android and desktop intake copies.
  static const int maxFileBytes = 32 * 1024 * 1024;

  Future<IncomingImageOutcome> process({
    required String path,
    required String serverHost,
    required BuildContext context,
    List<GroupEntry>? groups,
    String sourceTag = 'IncomingImage',
  }) async {
    if (serverHost.isEmpty) {
      LogService.instance.log(
          '$sourceTag: rejected image because no server is configured',
          name: sourceTag);
      return const IncomingImageFailure(IncomingImageFailureKind.serverMissing);
    }

    final String? qrText;
    try {
      qrText = await const QrImageScanner().decodeFile(path);
    } on QrImageUnreadableException catch (e) {
      LogService.instance.log('$sourceTag: unreadable image: $e',
          name: sourceTag);
      return IncomingImageFailure(IncomingImageFailureKind.unreadable,
          detail: e.message);
    } catch (e) {
      // The plugin can also throw instead of returning an error code.
      LogService.instance.log('$sourceTag: image decode failed: $e',
          name: sourceTag);
      return IncomingImageFailure(IncomingImageFailureKind.unreadable,
          detail: e.toString());
    }

    if (qrText == null) {
      LogService.instance.log('$sourceTag: no QR found in image',
          name: sourceTag);
      return const IncomingImageFailure(IncomingImageFailureKind.noQr);
    }

    // The parser reports a non-OTP QR itself (and shows the existing parse
    // error), so callers must not add a second message for invalidQr.
    final entry = await EntryCreationService.parseOtpAuthUrl(
      qrText,
      context.mounted ? context : null,
      sourceTag: sourceTag,
    );
    if (entry == null) {
      return const IncomingImageFailure(IncomingImageFailureKind.invalidQr);
    }

    final created = await EntryCreationService.createEntryOnServer(
      entry,
      serverHost: serverHost,
      groups: groups,
      context: context.mounted ? context : null,
      sourceTag: sourceTag,
    );

    // createEntryOnServer returns the local unsynchronized entry when the
    // upload fails, which the offline-first retry manager uploads later.
    return IncomingImageSuccess(created ?? entry);
  }
}

/// A localized message for a rejection reported by native share intake or by
/// the desktop drop target.
String incomingRejectionMessage(
    AppLocalizations l10n, String? reason, String maxFileSize) {
  switch (reason) {
    case 'multiple':
      return l10n.oneImageAtATime;
    case 'tooLarge':
      return l10n.imageTooLarge(maxFileSize);
    case 'unreadable':
      return l10n.unreadableImage;
    case 'unsupported':
    default:
      return l10n.unsupportedFile;
  }
}

/// A localized message for a processed image that did not create an account.
/// `null` means the existing flow already reported the outcome (invalidQr).
String? incomingFailureMessage(
  AppLocalizations l10n,
  IncomingImageFailureKind kind, {
  required String maxFileSize,
}) {
  switch (kind) {
    case IncomingImageFailureKind.noQr:
      return l10n.noQrInImage;
    case IncomingImageFailureKind.serverMissing:
      return l10n.serverRequiredForImage;
    case IncomingImageFailureKind.unreadable:
      return l10n.unreadableImage;
    case IncomingImageFailureKind.invalidQr:
      return null;
  }
}

/// Deletes a working copy created by share or drop intake, ignoring failures.
Future<void> deleteIncomingWorkingCopy(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // A leftover file is harmless: the next process start cleans the staging
    // directory.
  }
}
