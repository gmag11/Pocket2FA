import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/entry_creation_service.dart';
import 'dart:developer' as developer;
import '../l10n/app_localizations.dart';

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
      developer.log('ImageQrScannerScreen: Analyzing image for QR code', name: 'ImageQrScannerScreen');
      final controller = MobileScannerController();
      final capture = await controller.analyzeImage(image.path);
      await controller.dispose();

      if (capture != null && capture.barcodes.isNotEmpty) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null) {
          developer.log('ImageQrScannerScreen: QR code found in image, processing', name: 'ImageQrScannerScreen');
          final entry = await _parseAndCreateEntry(barcode.rawValue!);
          
          if (entry != null && mounted) {
            developer.log('ImageQrScannerScreen: Returning with entry', name: 'ImageQrScannerScreen');
            Navigator.of(context).pop(entry);
            return; // Importante: salir después de navegar
          }
        }
      } else {
        developer.log('ImageQrScannerScreen: No QR code found in image', name: 'ImageQrScannerScreen');
          if (mounted) {
            final noQrMsg = AppLocalizations.of(context)?.noQrInImage ?? 'No QR code found in image';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(noQrMsg), backgroundColor: Colors.orange)
            );
          }
      }
    } catch (e) {
      developer.log('ImageQrScannerScreen: Scan image failed: $e', name: 'ImageQrScannerScreen');
      if (mounted) {
        final err = AppLocalizations.of(context)?.errorScanningImage(e.toString()) ?? 'Error scanning image: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
      _isPicking = false;
    }
  }

  // Parse otpauth URL and build AccountEntry using our service
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    developer.log('ImageQrScannerScreen: Processing QR content', name: 'ImageQrScannerScreen');
    
    // Parse QR content to create entry
    var entry = await EntryCreationService.parseOtpAuthUrl(
      qrContent, 
      context,
      sourceTag: 'ImageQrScannerScreen'
    );
    
    if (entry == null) {
      developer.log('ImageQrScannerScreen: Failed to parse QR content', name: 'ImageQrScannerScreen');
      return null;
    }
    
    developer.log('ImageQrScannerScreen: Entry created from QR: ${entry.service}/${entry.account}', name: 'ImageQrScannerScreen');
    
    // Attempt immediate upload if server host present
    if (widget.serverHost.isNotEmpty && mounted) {
      try {
        developer.log('ImageQrScannerScreen: Attempting server upload', name: 'ImageQrScannerScreen');
        final serverEntry = await EntryCreationService.createEntryOnServer(
          entry,
          serverHost: widget.serverHost,
          groups: widget.groups,
          context: context,
          sourceTag: 'ImageQrScannerScreen'
        );
        
        if (serverEntry != null && serverEntry.synchronized) {
          developer.log('ImageQrScannerScreen: Server upload successful, returning entry', name: 'ImageQrScannerScreen');
          return serverEntry;
        } else {
          developer.log('ImageQrScannerScreen: Server upload returned null or unsynchronized entry', name: 'ImageQrScannerScreen');
        }
      } catch (e) {
        developer.log('ImageQrScannerScreen: Error during server upload: $e', name: 'ImageQrScannerScreen');
      }
    } else {
      developer.log('ImageQrScannerScreen: Skipping server upload (no server or not mounted)', name: 'ImageQrScannerScreen');
    }
    
    // Retornar la entrada local
    return entry;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.selectQrImageTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 100, color: Colors.grey),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.selectImageFromGallery, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isPicking || _isProcessing ? null : _pickAndScanImage,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                  AppLocalizations.of(context)!.selectImageButton,
                  style: const TextStyle(color: Colors.white),
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
              Text(AppLocalizations.of(context)!.scanningFromImage),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(AppLocalizations.of(context)!.back),
            ),
          ],
        ),
      ),
    );
  }
}
