import 'package:flutter/material.dart';
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

  const NewCodeScreen({super.key, required this.userEmail, required this.serverHost, this.groups});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.createNewCodeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text(AppLocalizations.of(context)!.chooseHowToCreate, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            // Prominent primary action: Scan QR
            SizedBox(
              height: 62,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
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
                },
                icon: const Icon(Icons.qr_code_scanner, size: 28, color: Colors.white),
                label: Text(AppLocalizations.of(context)!.scanQRCode, style: const TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F63E6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 64),
            Center(child: Text(AppLocalizations.of(context)!.alternateMethods, style: const TextStyle(color: Colors.grey))),
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
                label: Text(AppLocalizations.of(context)!.selectImageButton, style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final result = await navigator.push(MaterialPageRoute(builder: (c) => AdvancedFormScreen(userEmail: userEmail, serverHost: serverHost, groups: groups)));
                if (result is AccountEntry) {
                  // Forward created entry back to HomePage using saved NavigatorState
                  navigator.pop(result);
                }
              },
              icon: const Icon(Icons.edit),
              label: Text(AppLocalizations.of(context)!.useAdvancedForm, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 12),
            // Space before the cancel button to separate it from the alternate methods
            const SizedBox(height: 64),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(AppLocalizations.of(context)!.back, style: const TextStyle(fontSize: 16)),
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
                    Text('$userEmail - $serverHost', style: const TextStyle(color: Colors.grey)),
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
