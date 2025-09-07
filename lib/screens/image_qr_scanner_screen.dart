import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/entry_creation_service.dart';
import 'dart:developer' as developer;

class ImageQrScannerScreen extends StatefulWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups;

  const ImageQrScannerScreen({
    super.key,
    required this.userEmail,
    required this.serverHost,
    this.groups,
  });

  @override
  State<ImageQrScannerScreen> createState() => _ImageQrScannerScreenState();
}

class _ImageQrScannerScreenState extends State<ImageQrScannerScreen> {
  bool _isPicking = false;
  bool _isProcessing = false;

  Future<void> _pickAndScanImage() async {
    if (_isPicking || _isProcessing) return;
    _isPicking = true;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      _isPicking = false;
      return;
    }

    setState(() { _isProcessing = true; });

    try {
      final controller = MobileScannerController();
      final capture = await controller.analyzeImage(image.path);
      await controller.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null) {
          final entry = await _parseAndCreateEntry(barcode.rawValue!);
          if (entry != null && mounted) {
            Navigator.of(context).pop(entry);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No QR code found in image'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      developer.log('ImageQrScannerScreen: Scan image failed: $e', name: 'ImageQrScannerScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scanning image: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
      _isPicking = false;
    }
  }

  // Parse otpauth URL and build AccountEntry using our service
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    // Parse QR content to create entry
    var entry = await EntryCreationService.parseOtpAuthUrl(
      qrContent, 
      context,
      sourceTag: 'ImageQrScannerScreen'
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
          sourceTag: 'ImageQrScannerScreen'
        );
        
        if (serverEntry != null && serverEntry.synchronized && mounted) {
          Navigator.of(context).pop(serverEntry);
          return null;
        }
      } catch (e) {
        developer.log('ImageQrScannerScreen: Error handling server entry: $e', name: 'ImageQrScannerScreen');
      }
    }
    
    return entry;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select QR Image')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 100, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Select an image from gallery containing a QR code', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isPicking || _isProcessing ? null : _pickAndScanImage,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: const Text(
                  'Select Image',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F63E6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Scanning QR from image...'),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
