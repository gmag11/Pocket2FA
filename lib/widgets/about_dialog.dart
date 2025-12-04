import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class AboutDialogContent extends StatelessWidget {
  final String appVersion;

  const AboutDialogContent({super.key, required this.appVersion});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    void launch(String urlString) async {
      final url = Uri.parse(urlString);
      final messenger = ScaffoldMessenger.of(context);
      final errorMsg = '${l10n.couldNotOpenUrl}: $urlString';

      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }

    Widget buildLink(String url, IconData icon) {
      final displayUrl = url.replaceFirst('https://', '');
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: GestureDetector(
          onTap: () => launch(url),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayUrl,
                      style: Theme.of(context).textTheme.bodyLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AlertDialog(
      contentPadding: const EdgeInsets.all(24.0),
      title: null,
      actions: null,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Image.asset(
              'assets/icon.png',
              width: 72,
              height: 72,
            ),
          ),
          Text(l10n.appTitle,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(l10n.aboutVersion(appVersion),
              style: Theme.of(context).textTheme.bodyMedium),
          buildLink('https://github.com/gmag11/Pocket2FA', Icons.code),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              l10n.requires2fauth,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          buildLink('https://github.com/Bubka/2FAuth', Icons.code),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.aboutClose),
            ),
          ),
        ],
      ),
    );
  }
}
