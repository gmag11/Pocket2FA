import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import '../services/api_service.dart';
import 'dart:developer' as developer;
import 'dart:convert'; // for Base32 validation helper

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

  // Helper to validate Base32 (uppercase, only A-Z 2-7)
  bool _isValidBase32(String secret) {
    final cleaned = secret.toUpperCase().replaceAll(RegExp(r'[^A-Z2-7]'), '');
    if (cleaned.length < 16 || cleaned.length % 8 != 0) return false;
    try {
      // Simple check; for full validation, could use a Base32 decoder
      base64Url.decode(cleaned.replaceAll('=', '').padRight((cleaned.length + 7) ~/ 8 * 8, '='));
      return true;
    } catch (_) {
      return false;
    }
  }

  // Parse otpauth URL and build AccountEntry
  Future<AccountEntry?> _parseAndCreateEntry(String qrContent) async {
    try {
      final uri = Uri.parse(qrContent);
      if (uri.scheme != 'otpauth' || (uri.host != 'totp' && uri.host != 'hotp')) {
        throw Exception('Not a valid TOTP/HOTP QR code (expected otpauth://totp/ or hotp/)');
      }

      final otpType = uri.host.toLowerCase();
      final params = uri.queryParameters;

      // Extract secret (required)
      final secret = params['secret']?.trim();
      if (secret == null || secret.isEmpty || !_isValidBase32(secret)) {
        throw Exception('Invalid or missing secret (must be uppercase Base32)');
      }

      // Parse label: issuer:account (e.g., "Example:hello@example.com" -> group="Example", account="hello@example.com")
      final label = params['label'] ?? '';
      String service = '', account = label, group = '';
      if (label.contains(':')) {
        final parts = label.split(':');
        service = parts.first.trim(); // issuer as service/group
        account = parts.sublist(1).join(':').trim();
        group = service; // Use issuer as group if present
      } else {
        account = label.trim();
        if (account.isEmpty) account = 'Unknown';
      }
      if (service.isEmpty) service = account.split('@').firstOrNull ?? 'Unknown';

      // Defaults and params
      final algorithm = params['algorithm']?.toUpperCase() ?? 'SHA1';
      final digits = int.tryParse(params['digits'] ?? '6') ?? 6;
      final period = int.tryParse(params['period'] ?? (otpType == 'totp' ? '30' : '0')) ?? (otpType == 'totp' ? 30 : 0);

      // Build local entry
      var entry = AccountEntry(
        id: -1,
        service: service,
        account: account,
        seed: secret,
        group: group,
        groupId: null, // Will be set if groups provided and group matches
        otpType: otpType.toUpperCase(),
        icon: null,
        digits: digits,
        algorithm: algorithm,
        period: period,
        localIcon: null,
        synchronized: false,
      );

      // If groups provided, try to find matching groupId
      if (widget.groups != null && group.isNotEmpty) {
        final matchingGroup = widget.groups!.firstWhere(
          (g) => g.name.toLowerCase() == group.toLowerCase(),
          orElse: () => GroupEntry(id: 0, name: group, twofaccountsCount: 0),
        );
        if (matchingGroup.id != 0) {
          entry = entry.copyWith(groupId: matchingGroup.id);
        }
      }

      // Attempt immediate upload if server host implies online (or check connectivity)
      if (widget.serverHost.isNotEmpty) {
        try {
          developer.log('QrScannerScreen: Attempting immediate create for ${entry.service}', name: 'QrScannerScreen');
          final response = await ApiService.instance.createAccountFromEntry(entry, groupId: entry.groupId);
          // On success, update with server data
          var serverEntry = AccountEntry.fromMap(response).copyWith(synchronized: true);
          // Populate group name if server returned group_id but not group
          if (serverEntry.group.isEmpty && serverEntry.groupId != null && widget.groups != null) {
            final groupMatch = widget.groups!.firstWhere(
              (g) => g.id == serverEntry.groupId,
              orElse: () => GroupEntry(id: serverEntry.groupId!, name: group, twofaccountsCount: 0),
            );
            if (groupMatch.name.isNotEmpty) {
              serverEntry = serverEntry.copyWith(group: groupMatch.name);
            }
          }
          if (mounted) {
            Navigator.of(context).pop(serverEntry); // Return synced entry
          }
          return null; // Already popped
        } catch (e) {
          developer.log('QrScannerScreen: Immediate create failed: $e (keeping local unsynced)', name: 'QrScannerScreen');
          // Fall through to local entry
        }
      }

      // Return local unsynced entry on failure or no server
      return entry;
    } catch (e) {
      developer.log('QrScannerScreen: Parsing failed: $e', name: 'QrScannerScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error parsing QR: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  void _onQrDetected(BarcodeCapture capture) async {
    if (_isProcessing || capture.barcodes.isEmpty) return;
    _isProcessing = true;

    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      final entry = await _parseAndCreateEntry(barcode.rawValue!);
      if (entry != null) {
        if (mounted) {
          Navigator.of(context).pop(entry);
        }
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
