import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Parse otpauth URL and build AccountEntry using the service
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    // Parse QR content to create entry
    var entry = await EntryCreationService.parseOtpAuthUrl(
      qrContent, 
      context,
      sourceTag: 'QrScannerScreen'
    );
    
    if (entry == null) return null;
    
    // Attempt immediate upload if server host present
    if (widget.serverHost.isNotEmpty && mounted) {
      try {
        final serverEntry = await EntryCreationService.createEntryOnServer(
          entry,
          serverHost: widget.serverHost,
          groups: widget.groups,
          context: context,
          sourceTag: 'QrScannerScreen'
        );
        
        if (serverEntry != null && serverEntry.synchronized && mounted) {
          Navigator.of(context).pop(serverEntry);
          return null;
        }
      } catch (e) {
        developer.log('QrScannerScreen: Error handling server entry: $e', name: 'QrScannerScreen');
      }
    }
    
    return entry;
  }

  void _onQrDetected(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    _isProcessing = true;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      final entry = await _parseAndCreateEntry(barcode.rawValue!);
      if (entry != null && mounted) {
        Navigator.of(context).pop(entry);
      }
    }

    _isProcessing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
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
                  const Text('Position the QR code in the frame', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
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
