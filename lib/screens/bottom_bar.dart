import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import '../screens/accounts_screen.dart';
import '../screens/settings_screen.dart';
import 'new_code_screen.dart';

Future<void> launchExternal(Uri uri, ScaffoldMessengerState messenger) async {
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
    messenger.showSnackBar(SnackBar(
      content: Text('Could not open URL: $e'),
    ));
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

  const BottomBar({
    required this.settings,
    required this.servers,
    required this.selectedServerId,
    required this.selectedAccountIndex,
    required this.onOpenSelector,
    this.onOpenAccounts,
    this.onNewAccount,
    required this.serverReachable,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasServers = servers.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: hasServers
                    ? () async {
                        // Open the new code screen and wait for a created AccountEntry
                        final srv = selectedServerId != null
                            ? servers.firstWhere((s) => s.id == selectedServerId, orElse: () => servers.first)
                            : servers.first;
                        final acct = (srv.userEmail.isNotEmpty) ? srv.userEmail : 'no email';
                        final host = Uri.parse(srv.url).host;
                        final result = await Navigator.of(context).push(MaterialPageRoute(builder: (c) => NewCodeScreen(userEmail: acct, serverHost: host, groups: srv.groups)));
                        if (result is AccountEntry && onNewAccount != null) {
                          onNewAccount!(result);
                        }
                      }
                    : null,
                icon: const Icon(Icons.qr_code, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: hasServers ? const Color(0xFF4F63E6) : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                label: const Text('New', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: hasServers
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);

                        final srv = selectedServerId != null
                            ? servers.firstWhere((s) => s.id == selectedServerId, orElse: () => servers.first)
                            : servers.first;

                        final urlStr = srv.url.trim();
                        final parsed = Uri.tryParse(urlStr);
                        if (parsed == null || parsed.scheme.isEmpty || !(parsed.scheme == 'http' || parsed.scheme == 'https') || parsed.host.isEmpty) {
                          messenger.showSnackBar(const SnackBar(
                            content: Text('Invalid server URL (missing http/https)'),
                          ));
                          return;
                        }

                        // Launch base server url in external browser
                        final trimmed = urlStr.endsWith('/') ? urlStr.substring(0, urlStr.length - 1) : urlStr;
                        final uri = Uri.parse(trimmed);
                        await launchExternal(uri, messenger);
                      }
                    : null,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  foregroundColor: hasServers ? null : Colors.grey,
                ),
                child: const Text('2fauth web'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reachability indicator: icon + tooltip + semantics for accessibility
                  Tooltip(
                    message: serverReachable ? 'Online' : 'Offline',
                    child: Semantics(
                      label: serverReachable ? 'Server reachable' : 'Server unreachable',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                      child: Builder(builder: (ctx) {
                        // Compute display text from the selected server/account safely
                        String displayText;
                        if (servers.isEmpty) {
                          displayText = 'no-server';
                        } else {
                          final srv = selectedServerId != null
                              ? servers.firstWhere((s) => s.id == selectedServerId, orElse: () => servers.first)
                              : servers.first;
                          // Show only the server/user email. Do not display the selected
                          // account name in this top/bottom summary to avoid confusion.
                          final acct = (srv.userEmail.isNotEmpty) ? srv.userEmail : 'no email';
                          displayText = '$acct - ${Uri.parse(srv.url).host}';
                        }
                        return Text(displayText, style: const TextStyle(color: Colors.grey));
                      }),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final s = settings;
                      final nav = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
                          ),
                          builder: (ctx) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    title: const Text('settings', textAlign: TextAlign.center),
                                    onTap: () => Navigator.of(ctx).pop('settings'),
                                  ),
                                  ListTile(
                                    title: const Text('accounts', textAlign: TextAlign.center),
                                    onTap: () => Navigator.of(ctx).pop('accounts'),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.grey),
                                          onPressed: () => Navigator.of(ctx).pop(), // close without selecting
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ).then((value) {
                          if (value != null) {
                            if (value == 'settings') {
                              // open full settings screen using captured Navigator
                              nav.push(MaterialPageRoute(builder: (c) => SettingsScreen(settings: s)));
                            } else if (value == 'accounts') {
                              // delegate to the owner (HomePage) to open accounts so it can reload afterwards
                              if (onOpenAccounts != null) {
                                onOpenAccounts!();
                              } else {
                                // fallback behaviour: try to open directly if storage is available
                                if (s.storage != null) {
                                  nav.push(MaterialPageRoute(builder: (c) => AccountsScreen(storage: s.storage!)));
                                } else {
                                  messenger.showSnackBar(const SnackBar(content: Text('Storage not available')));
                                }
                              }
                            }
                          }
                        });
                      },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.menu, size: 18, color: Colors.grey),
                      ],
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
