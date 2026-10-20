import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
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

    try {
      // Decode the QR directly from the original file. The decoder already
      // scans its own downscaled pyramid, so pre-shrinking the image here only
      // loses the detail of small QR codes in large screenshots.
      final codeResult = await zx.readBarcodeImagePathString(
          image.path,
          DecodeParams(
            tryHarder: true,
            tryInverted: true,
            tryRotate: true,
            tryDownscale: true,
            maxSize: 4000, // safety bound; common screenshots are untouched
          ));

      if (codeResult.isValid &&
          codeResult.text != null &&
          codeResult.text!.isNotEmpty) {
        final entry = await _parseAndCreateEntry(codeResult.text!);

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
