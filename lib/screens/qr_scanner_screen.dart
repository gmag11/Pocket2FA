import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
  MobileScannerController? _controller;
  bool _isProcessing = false;
  bool _hasCamera = true;
  bool _isInitializing = true;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _initializeScanner();
  }

  Future<void> _initializeScanner() async {
    try {
      _controller = MobileScannerController();
      // Don't start the controller here, let MobileScanner widget handle it
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      developer.log('QrScannerScreen: Error initializing scanner: $e',
          name: 'QrScannerScreen');
      if (mounted) {
        setState(() {
          _hasCamera = false;
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Only dispose if controller was successfully created
    try {
      _controller?.dispose();
    } catch (e) {
      developer.log('QrScannerScreen: Error disposing controller: $e',
          name: 'QrScannerScreen');
    }
    super.dispose();
  }

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

  void _onQrDetected(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });
    // Capture localized strings and messenger before async gaps
    final messenger = ScaffoldMessenger.of(context);
    final qrErrorMsg = l10n.qrScannerError;

    try {
      // Pause the detector to avoid multiple detections
      try {
        await _controller?.stop();
      } catch (e) {
        developer.log(
            'QrScannerScreen: Error stopping controller (ignored): $e',
            name: 'QrScannerScreen');
      }

      final barcode = capture.barcodes.first;
      if (barcode.rawValue != null) {
        developer.log('QrScannerScreen: QR detected, processing...',
            name: 'QrScannerScreen');
        final entry = await _parseAndCreateEntry(barcode.rawValue!);

        // If the entry is not null, return to the previous screen with the entry
        if (entry != null && mounted) {
          developer.log('QrScannerScreen: Returning with entry',
              name: 'QrScannerScreen');
          Navigator.of(context).pop(entry);
        }
      }
    } catch (e) {
      developer.log('QrScannerScreen: Error in QR detection: $e',
          name: 'QrScannerScreen');
      if (mounted) {
        messenger.showSnackBar(SnackBar(
            content: Text('$qrErrorMsg: $e'), backgroundColor: Colors.red));
      }
    } finally {
      // Ensure _isProcessing is reset even if there's an error
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while initializing
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.scanQRCode),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If there was an initialization error or no camera, show error message
    if (!_hasCamera) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.scanQRCode),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  l10n.noCameraAvailable,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.noCameraMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.back),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQRCode),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller?.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onQrDetected,
            fit: BoxFit.cover,
            errorBuilder: (context, error) {
              // Handle scanner errors (e.g., no camera available)
              developer.log('QrScannerScreen: MobileScanner error: $error',
                  name: 'QrScannerScreen');

              // Update state to show error screen
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    _hasCamera = false;
                  });
                }
              });

              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          ),
          // Scanning guide overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(l10n.positionQr,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
