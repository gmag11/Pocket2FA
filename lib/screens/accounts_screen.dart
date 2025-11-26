import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/server_connection.dart';
import '../services/settings_storage.dart';
import 'server_add_edit_dialog.dart';
import 'server_detail_screen.dart';

class AccountsScreen extends StatefulWidget {
  final SettingsStorage storage;
  final Future<void> Function()? onServerChanged;
  const AccountsScreen({required this.storage, this.onServerChanged, super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<ServerConnection> _servers = [];
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  static const Color _baseAccent = Color(0xFF4F63E6);

  @override
  void initState() {
    super.initState();
    // Only load servers if the storage is already unlocked. If biometric
    // protection is enabled and the store is locked, the UI will show an
    // unlock screen and the user can attemptUnlock() manually.
    if (widget.storage.isUnlocked) {
      _loadServers();
      // If no servers, automatically open add dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_servers.isEmpty) {
          _addServer();
        }
      });
    }
  }

  void _loadServers() {
    try {
      final box = widget.storage.box;
      final raw = box.get('servers');
      if (raw == null) {
        // no servers stored yet
        setState(() {
          _servers = [];
        });
        return;
      }
      final list = (raw as List<dynamic>)
          .map((e) => ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
          .toList();
      setState(() => _servers = list);
    } on StateError catch (_) {
      // Storage locked; leave servers empty until unlocked.
      setState(() => _servers = []);
      return;
    }
  }

  Future<void> _saveServers() async {
    try {
      final box = widget.storage.box;
      await box.put('servers', _servers.map((s) => s.toMap()).toList());
    } on StateError catch (_) {
      // Storage is locked; ignore save (it will be persisted when unlocked).
    }
  }

  Future<void> _addServer() async {
    final title = l10n.addServerTitle;
    // Capture messages before awaiting async operations to avoid using BuildContext across async gaps
    final serverSavedMsg = l10n.serverSaved;
    final result =
        await showServerAddEditDialog(context: context, title: title);
    if (result != null) {
      setState(() => _servers.add(result));
      await _saveServers();
      if (widget.onServerChanged != null) {
        await widget.onServerChanged!();
      }
      _showGreenToast(serverSavedMsg);
    }
  }

  Future<void> _editServer(ServerConnection server, int index) async {
    final title = l10n.editServerTitle;
    final serverUpdatedMsg = l10n.serverUpdated;
    final result = await showServerAddEditDialog(
        context: context, title: title, initial: server);
    if (result != null) {
      setState(() => _servers[index] = result);
      await _saveServers();
      if (widget.onServerChanged != null) {
        await widget.onServerChanged!();
      }
      _showGreenToast(serverUpdatedMsg);
    }
  }

  Future<void> _deleteServer(ServerConnection s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteServerTitle),
        content: Text(l10n.deleteServerConfirm(s.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _servers.removeWhere((x) => x.id == s.id));
    await _saveServers();
    if (widget.onServerChanged != null) {
      await widget.onServerChanged!();
    }
  }

  void _showGreenToast(String text) {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(builder: (ctx) {
      return Positioned(
        bottom: 60,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: _baseAccent, borderRadius: BorderRadius.circular(8)),
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
        ),
      );
    });

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    // If storage is locked, show an unlock screen instead of the list.
    if (!widget.storage.isUnlocked) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.accountsTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.localDataProtected,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(l10n.authenticateToUnlock, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final authenticationFailedMsg = l10n.authenticationFailed;
                    final ok = await widget.storage.attemptUnlock();
                    if (ok) {
                      // Reload servers and update UI
                      _loadServers();
                      if (!mounted) return;
                      setState(() {});
                    } else {
                      messenger.showSnackBar(
                          SnackBar(content: Text(authenticationFailedMsg)));
                    }
                  },
                  icon: const Icon(Icons.fingerprint),
                  label: Text(l10n.unlock),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountsTitle)),
      body: ListView.builder(
        itemCount: _servers.length,
        itemBuilder: (context, index) {
          final s = _servers[index];
          return ListTile(
            title: Text(s.name),
            subtitle: Text(s.url),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editServer(s, index)),
                IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteServer(s)),
              ],
            ),
            onTap: () {
              // Open detail view to manage accounts for this server (not implemented in depth yet)
              Navigator.of(context).push(MaterialPageRoute(
                builder: (c) => ServerDetailScreen(
                  server: s,
                  onChanged: (updated) async {
                    setState(() {
                      _servers[index] = updated;
                    });
                    await _saveServers();
                  },
                ),
              ));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addServer,
        foregroundColor: Colors.white,
        backgroundColor: Color.lerp(_baseAccent, Colors.white, 0.22)!,
        child: const Icon(Icons.add),
      ),
    );
  }
}
