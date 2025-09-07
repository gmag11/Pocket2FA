import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/api_service.dart';
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

  // Parse otpauth URL and build AccountEntry (adapted from QrScannerScreen, no group)
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    try {
      final uri = Uri.parse(qrContent);
      if (uri.scheme != 'otpauth' || (uri.host != 'totp' && uri.host != 'hotp')) {
        throw Exception('Not a valid TOTP/HOTP QR code (expected otpauth://totp/ or hotp/)');
      }

      final otpType = uri.host.toLowerCase();
      final params = uri.queryParameters;

      // Log decoded URL and parsed fields (mask secret)
      try {
        String maskSecret(String s) {
          final key = 'secret=';
          final lower = s.toLowerCase();
          final idx = lower.indexOf(key);
          if (idx == -1) return s;
          final start = idx + key.length;
          var end = s.indexOf('&', start);
          if (end == -1) end = s.length;
          return '${s.substring(0, start)}***REDACTED***${s.substring(end)}';
        }
        final masked = maskSecret(uri.toString());
        developer.log('ImageQrScannerScreen: decoded URL from image: $masked', name: 'ImageQrScannerScreen');
        developer.log('ImageQrScannerScreen: parsed query fields: issuer=${params['issuer']}, label_query=${params['label']}, algorithm=${params['algorithm']}, digits=${params['digits']}, period=${params['period']}, counter=${params['counter']}', name: 'ImageQrScannerScreen');
      } catch (_) {
        developer.log('ImageQrScannerScreen: logging failed', name: 'ImageQrScannerScreen');
      }

      // Extract secret (required)
      final secret = params['secret']?.trim();
      if (secret == null || secret.isEmpty || RegExp(r'^[A-Z2-7]+$').hasMatch(secret.toUpperCase()) == false) {
        throw Exception('Invalid or missing secret (must be uppercase Base32)');
      }

      // Parse label and issuer
      final issuer = params['issuer']?.trim() ?? '';
      String label = '';
      if (uri.path.isNotEmpty && uri.path != '/') {
        label = uri.path.startsWith('/') ? uri.path.substring(1) : uri.path;
        try { label = Uri.decodeComponent(label); } catch (_) {}
      } else {
        label = params['label'] ?? '';
      }

      String service = issuer.isNotEmpty ? issuer : '';
      String account = label.trim();
      String group = ''; // No group for QR/image creates

      // If label contains colon and no issuer, split for service:account
      if (label.contains(':') && service.isEmpty) {
        final parts = label.split(':');
        service = parts.first.trim();
        account = parts.sublist(1).join(':').trim();
      }

      if (account.isEmpty) account = 'Unknown';
      if (service.isEmpty) {
        service = account.split('@').firstOrNull ?? account;
      }

      // Log final parsed values
      developer.log('ImageQrScannerScreen: final parsed - service="$service" account="$account" group="$group"', name: 'ImageQrScannerScreen');

      // Defaults and params
      final algorithm = params['algorithm']?.toUpperCase() ?? 'SHA1';
      final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
      final period = int.tryParse(params['period'] ?? (otpType == 'totp' ? '30' : '0')) ?? (otpType == 'totp' ? 30 : 0);

      // Build local entry (no group)
      var entry = AccountEntry(
        id: -1,
        service: service,
        account: account,
        seed: secret,
        group: group,
        groupId: null,
        otpType: otpType.toUpperCase(),
        icon: null,
        digits: digits,
        algorithm: algorithm,
        period: period,
        localIcon: null,
        synchronized: false,
      );

      // Attempt immediate upload if server host present
      if (widget.serverHost.isNotEmpty) {
        try {
          developer.log('ImageQrScannerScreen: Attempting immediate create for ${entry.service}', name: 'ImageQrScannerScreen');
          final response = await ApiService.instance.createAccountFromEntry(entry, groupId: entry.groupId);
          var serverEntry = AccountEntry.fromMap(response).copyWith(synchronized: true);
          if (mounted) Navigator.of(context).pop(serverEntry);
          return null;
        } catch (e) {
          developer.log('ImageQrScannerScreen: Immediate create failed: $e (keeping local unsynced)', name: 'ImageQrScannerScreen');
        }
      }

      return entry;
    } catch (e) {
      developer.log('ImageQrScannerScreen: Parsing failed: $e', name: 'ImageQrScannerScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error parsing QR from image: $e'), backgroundColor: Colors.red));
      }
      return null;
    }
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
