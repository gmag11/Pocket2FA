import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/entry_creation_service.dart';
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
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  Future<void> _pickAndScanImage() async {
    if (_isPicking || _isProcessing) return;
    _isPicking = true;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      _isPicking = false;
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    MobileScannerController? controller;
    String? processedImagePath;

    try {
      // Read and preprocess the image
      final imageFile = File(image.path);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image if it's too large (max 1500px on longest side)
      img.Image processedImage = decodedImage;
      const maxSize = 1500;

      if (decodedImage.width > maxSize || decodedImage.height > maxSize) {
        if (decodedImage.width > decodedImage.height) {
          processedImage = img.copyResize(decodedImage,
              width: maxSize, interpolation: img.Interpolation.linear);
        } else {
          processedImage = img.copyResize(decodedImage,
              height: maxSize, interpolation: img.Interpolation.linear);
        }
      }

      // Increase contrast to help detection
      processedImage =
          img.adjustColor(processedImage, contrast: 1.3, brightness: 1.1);

      // Save processed image to temp file
      final tempDir = imageFile.parent.path;
      processedImagePath = '$tempDir/processed_qr.jpg';
      final processedFile = File(processedImagePath);
      await processedFile
          .writeAsBytes(img.encodeJpg(processedImage, quality: 95));

      // Initialize controller and analyze image
      controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: [BarcodeFormat.qrCode],
      );

      final capture = await controller.analyzeImage(processedImagePath);

      if (capture != null && capture.barcodes.isNotEmpty) {
        final barcode = capture.barcodes.first;
        if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
          final entry = await _parseAndCreateEntry(barcode.rawValue!);

          if (entry != null && mounted) {
            Navigator.of(context).pop(entry);
            return;
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(l10n.errorScanningImage('Failed to parse QR code')),
                backgroundColor: Colors.red,
              ),
            );
          }
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noQrInImage),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.noQrInImage), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.errorScanningImage(e.toString())),
            backgroundColor: Colors.red));
      }
    } finally {
      // Dispose controller
      await controller?.dispose();

      // Clean up temporary file
      if (processedImagePath != null) {
        try {
          final tempFile = File(processedImagePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      _isPicking = false;
    }
  }

  // Parse otpauth URL and build AccountEntry using our service
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    // Parse QR content to create entry
    var entry = await EntryCreationService.parseOtpAuthUrl(qrContent, context,
        sourceTag: 'ImageQrScannerScreen');

    if (entry == null) {
      return null;
    }

    // Attempt immediate upload if server host present
    if (widget.serverHost.isNotEmpty && mounted) {
      try {
        final serverEntry = await EntryCreationService.createEntryOnServer(
            entry,
            serverHost: widget.serverHost,
            groups: widget.groups,
            context: context,
            sourceTag: 'ImageQrScannerScreen');

        if (serverEntry != null && serverEntry.synchronized) {
          return serverEntry;
        }
      } catch (e) {
        // Continue with local entry if server upload fails
      }
    }

    // Return the local entry
    return entry;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.selectQrImageTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 100, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.selectImageFromGallery,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed:
                    _isPicking || _isProcessing ? null : _pickAndScanImage,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                  l10n.selectImageButton,
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F63E6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(l10n.scanningFromImage),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.back),
            ),
          ],
        ),
      ),
    );
  }
}
