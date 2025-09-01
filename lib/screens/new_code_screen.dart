import 'package:flutter/material.dart';
import '../models/group_entry.dart';
import 'advanced_form_screen.dart';

class NewCodeScreen extends StatelessWidget {
  final String userEmail;
  final String serverHost;
  final List<GroupEntry>? groups; // forwarded from HomePage

  const NewCodeScreen({super.key, required this.userEmail, required this.serverHost, this.groups});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(title: const Text('Create new code')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Text('Choose how to create a new code:', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            // Prominent primary action: Scan QR
            SizedBox(
              height: 62,
              child: ElevatedButton.icon(
                onPressed: () {}, // not implemented yet
                icon: const Icon(Icons.qr_code_scanner, size: 28, color: Colors.white),
                label: const Text('Scan a QR code', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F63E6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
            const SizedBox(height: 64),
            const Center(child: Text('Alternate methods', style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.image),
              label: const Text('Select an image'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (c) => AdvancedFormScreen(userEmail: userEmail, serverHost: serverHost, groups: groups)));
              },
              icon: const Icon(Icons.edit),
              label: const Text('Use the advanced form'),
            ),
            const SizedBox(height: 12),
            // Space before the cancel button to separate it from the alternate methods
            const SizedBox(height: 64),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
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
