import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../l10n/app_localizations.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/entry_creation_service.dart';
import 'dart:developer' as developer;

class QrScannerScreen extends StatefulWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups;

  const QrScannerScreen({
    super.key,
    required this.userEmail,
    required this.serverHost,
    this.groups,
  });

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _isProcessing = false;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  // Parse otpauth URL and build AccountEntry using the service
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    developer.log('QrScannerScreen: Processing QR content',
        name: 'QrScannerScreen');

    // Parse QR content to create entry
    var entry = await EntryCreationService.parseOtpAuthUrl(qrContent, context,
        sourceTag: 'QrScannerScreen');

    if (entry == null) {
      developer.log('QrScannerScreen: Failed to parse QR content',
          name: 'QrScannerScreen');
      return null;
    }

    developer.log(
        'QrScannerScreen: Entry created from QR: ${entry.service}/${entry.account}',
        name: 'QrScannerScreen');

    // Attempt immediate upload if server host present
    if (widget.serverHost.isNotEmpty && mounted) {
      try {
        developer.log('QrScannerScreen: Attempting server upload',
            name: 'QrScannerScreen');
        final serverEntry = await EntryCreationService.createEntryOnServer(
            entry,
            serverHost: widget.serverHost,
            groups: widget.groups,
            context: context,
            sourceTag: 'QrScannerScreen');

        if (serverEntry != null && serverEntry.synchronized) {
          developer.log(
              'QrScannerScreen: Server upload successful, returning entry',
              name: 'QrScannerScreen');
          return serverEntry;
        } else {
          developer.log(
              'QrScannerScreen: Server upload returned null or unsynchronized entry',
              name: 'QrScannerScreen');
        }
      } catch (e) {
        developer.log('QrScannerScreen: Error during server upload: $e',
            name: 'QrScannerScreen');
      }
    } else {
      developer.log(
          'QrScannerScreen: Skipping server upload (no server or not mounted)',
          name: 'QrScannerScreen');
    }

    // Return the local entry
    return entry;
  }

  void _onScan(Code result) async {
    if (_isProcessing || !result.isValid || result.text == null) return;

    setState(() {
      _isProcessing = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final qrErrorMsg = l10n.qrScannerError;

    try {
      developer.log('QrScannerScreen: QR detected, processing...',
          name: 'QrScannerScreen');
      final entry = await _parseAndCreateEntry(result.text!);

      if (entry != null && mounted) {
        developer.log('QrScannerScreen: Returning with entry',
            name: 'QrScannerScreen');
        Navigator.of(context).pop(entry);
      }
    } catch (e) {
      developer.log('QrScannerScreen: Error in QR detection: $e',
          name: 'QrScannerScreen');
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text('$qrErrorMsg: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQRCode),
      ),
      body: Stack(
        children: [
          ReaderWidget(
            onScan: _onScan,
            showFlashlight: true,
          ),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
