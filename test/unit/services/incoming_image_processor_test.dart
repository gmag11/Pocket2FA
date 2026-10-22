import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/l10n/app_localizations_en.dart';
import 'package:pocket2fa/services/incoming_image_processor.dart';

import '../../helpers/pump.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('parses image and rejected descriptors', () {
    final image = IncomingImageDescriptor.fromMap({
      'kind': 'image',
      'path': '/tmp/image.png',
      'mimeType': 'image/png',
      'name': 'image.png',
    });
    expect(image.isRejected, isFalse);
    expect(image.path, '/tmp/image.png');
    expect(image.mimeType, 'image/png');
    expect(image.name, 'image.png');

    final rejected = IncomingImageDescriptor.fromMap({
      'kind': 'rejected',
      'reason': 'tooLarge',
    });
    expect(rejected.isRejected, isTrue);
    expect(rejected.rejectionReason, 'tooLarge');
    expect(rejected.path, isNull);

    final fallback = IncomingImageDescriptor.fromMap({'kind': 'other'});
    expect(fallback.rejectionReason, 'unsupported');
  });

  test('builds rejection and failure messages', () {
    expect(
      incomingRejectionMessage(l10n, 'multiple', '32 MB'),
      l10n.oneImageAtATime,
    );
    expect(
      incomingRejectionMessage(l10n, 'tooLarge', '32 MB'),
      l10n.imageTooLarge('32 MB'),
    );
    expect(
      incomingRejectionMessage(l10n, 'unreadable', '32 MB'),
      l10n.unreadableImage,
    );
    expect(
      incomingRejectionMessage(l10n, 'unsupported', '32 MB'),
      l10n.unsupportedFile,
    );
    expect(incomingRejectionMessage(l10n, null, '32 MB'), l10n.unsupportedFile);

    expect(
      incomingFailureMessage(
        l10n,
        IncomingImageFailureKind.noQr,
        maxFileSize: '32 MB',
      ),
      l10n.noQrInImage,
    );
    expect(
      incomingFailureMessage(
        l10n,
        IncomingImageFailureKind.serverMissing,
        maxFileSize: '32 MB',
      ),
      l10n.serverRequiredForImage,
    );
    expect(
      incomingFailureMessage(
        l10n,
        IncomingImageFailureKind.unreadable,
        maxFileSize: '32 MB',
      ),
      l10n.unreadableImage,
    );
    expect(
      incomingFailureMessage(
        l10n,
        IncomingImageFailureKind.invalidQr,
        maxFileSize: '32 MB',
      ),
      isNull,
    );
  });

  test('deletes working copies safely', () async {
    final dir = Directory.systemTemp.createTempSync('incoming_image_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/copy.png')..writeAsBytesSync(const [1]);

    await deleteIncomingWorkingCopy(file.path);
    expect(file.existsSync(), isFalse);

    await deleteIncomingWorkingCopy(null);
    await deleteIncomingWorkingCopy('');
    await deleteIncomingWorkingCopy('${dir.path}/missing.png');
  });

  testWidgets('rejects a process request without a server host', (
    tester,
  ) async {
    late BuildContext context;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );

    final outcome = await const IncomingImageProcessor().process(
      path: '/tmp/image.png',
      serverHost: '',
      context: context,
    );

    expect(outcome, isA<IncomingImageFailure>());
    expect(
      (outcome as IncomingImageFailure).kind,
      IncomingImageFailureKind.serverMissing,
    );
    expect(IncomingImageProcessor.maxFileBytes, 32 * 1024 * 1024);
  });
}
