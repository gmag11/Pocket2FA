import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/account_entry.dart';
import '../models/server_connection.dart';
import '../services/settings_service.dart';

Future<void> launchExternal(Uri uri, ScaffoldMessengerState messenger) async {
  // Capture localized text before any await to avoid using BuildContext across async gaps
  final couldNotOpen =
      AppLocalizations.of(messenger.context)?.couldNotOpenUrl ??
          'Could not open URL';
  try {
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (!ok && Platform.isLinux) {
        await Process.run('xdg-open', [uri.toString()]);
      }
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [uri.toString()]);
    } else {
      await launchUrl(uri);
    }
  } catch (e) {
    developer.log('HomePage: cannot launch $uri: $e', name: 'HomePage');
    if (messenger.mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text('$couldNotOpen: $e'),
      ));
    }
  }
}

class BottomBar extends StatelessWidget {
  final SettingsService settings;
  final List<ServerConnection> servers;
  final String? selectedServerId;
  final int? selectedAccountIndex;
  final bool serverReachable;
  final VoidCallback onOpenSelector;
  final VoidCallback? onOpenAccounts;
  final ValueChanged<AccountEntry>? onNewAccount;
  final bool isManageMode;
  final Set<int> selectedAccountIds;
  final VoidCallback onToggleManageMode;
  final VoidCallback onDeleteSelected;

  const BottomBar({
    required this.settings,
    required this.servers,
    required this.selectedServerId,
    required this.selectedAccountIndex,
    required this.onOpenSelector,
    this.onOpenAccounts,
    this.onNewAccount,
    required this.serverReachable,
    required this.isManageMode,
    required this.selectedAccountIds,
    required this.onToggleManageMode,
    required this.onDeleteSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isManageMode) ...[
                // Manage mode: show Delete and Done buttons
                ElevatedButton(
                  onPressed:
                      selectedAccountIds.isNotEmpty ? onDeleteSelected : null,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    backgroundColor: selectedAccountIds.isNotEmpty
                        ? Colors.red
                        : Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(l10n.delete,
                      style: const TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onToggleManageMode,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    minimumSize: const Size(0, 36),
                  ),
                  child: Text(l10n.done),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Always show server/account information, even in edit mode
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reachability indicator: icon + tooltip + semantics for accessibility
                  Tooltip(
                    message: serverReachable ? l10n.online : l10n.offline,
                    child: Semantics(
                      label: serverReachable
                          ? l10n.serverReachable
                          : l10n.serverUnreachable,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Icon(
                          serverReachable ? Icons.cloud : Icons.cloud_off,
                          size: 14,
                          color: serverReachable ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onOpenSelector,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 6.0),
                      child: Builder(builder: (ctx) {
                        // Compute display text from the selected server/account safely
                        String displayText;
                        if (servers.isEmpty) {
                          displayText = l10n.noServer;
                        } else {
                          final srv = selectedServerId != null
                              ? servers.firstWhere(
                                  (s) => s.id == selectedServerId,
                                  orElse: () => servers.first)
                              : servers.first;
                          // Show only the server/user email. Do not display the selected
                          // account name in this top/bottom summary to avoid confusion.
                          final acct = (srv.userEmail.isNotEmpty)
                              ? srv.userEmail
                              : l10n.noEmail;
                          displayText = '$acct - ${Uri.parse(srv.url).host}';
                        }
                        return Text(displayText,
                            style: const TextStyle(color: Colors.grey));
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
