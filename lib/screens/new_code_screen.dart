import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import '../l10n/app_localizations.dart';
import '../models/group_entry.dart';
import '../models/account_entry.dart';
import 'advanced_form_screen.dart';
import 'qr_scanner_screen.dart';
import 'image_qr_scanner_screen.dart';

class NewCodeScreen extends StatelessWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups; // forwarded from HomePage

  const NewCodeScreen(
      {super.key,
      required this.userEmail,
      required this.serverHost,
      this.groups});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createNewCodeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(l10n.chooseHowToCreate,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            // Prominent primary action: Scan QR
            SizedBox(
              height: 62,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  // Check if platform supports camera scanning
                  // mobile_scanner only works on Android, iOS, macOS, and web
                  final isSupportedPlatform = !kIsWeb &&
                      (Platform.isAndroid ||
                          Platform.isIOS ||
                          Platform.isMacOS);

                  if (!isSupportedPlatform) {
                    // Platform doesn't support camera scanning
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(l10n.noCameraMessage),
                        backgroundColor: Colors.orange,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }

                  try {
                    final result = await navigator.push(MaterialPageRoute(
                      builder: (c) => QrScannerScreen(
                        userEmail: userEmail,
                        serverHost: serverHost,
                        groups: groups,
                      ),
                    ));
                    if (result is AccountEntry) {
                      // Forward created entry back to HomePage using saved NavigatorState
                      navigator.pop(result);
                    }
                  } catch (e) {
                    // Handle camera not available error
                    if (e.toString().contains('MissingPluginException') ||
                        e.toString().contains('No implementation found')) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.noCameraMessage),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('${l10n.qrScannerError}: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.qr_code_scanner,
                    size: 28, color: Colors.white),
                label: Text(l10n.scanQRCode,
                    style: const TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F63E6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 64),
            Center(
                child: Text(l10n.alternateMethods,
                    style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final result = await navigator.push(MaterialPageRoute(
                    builder: (c) => ImageQrScannerScreen(
                      userEmail: userEmail,
                      serverHost: serverHost,
                      groups: groups,
                    ),
                  ));
                  if (result is AccountEntry) {
                    navigator.pop(result);
                  }
                },
                icon: const Icon(Icons.image),
                label: Text(l10n.selectImageButton,
                    style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final result = await navigator.push(MaterialPageRoute(
                    builder: (c) => AdvancedFormScreen(
                        userEmail: userEmail,
                        serverHost: serverHost,
                        groups: groups)));
                if (result is AccountEntry) {
                  // Forward created entry back to HomePage using saved NavigatorState
                  navigator.pop(result);
                }
              },
              icon: const Icon(Icons.edit),
              label: Text(l10n.useAdvancedForm,
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            // Space before the cancel button to separate it from the alternate methods
            const SizedBox(height: 64),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.back, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            // Push the user/server line to the bottom
            const Expanded(child: SizedBox.shrink()),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.userAtHost(userEmail, serverHost),
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
