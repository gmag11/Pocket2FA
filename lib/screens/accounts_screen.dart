import 'package:flutter/material.dart';
import '../models/server_connection.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import '../models/account_entry.dart';
import '../services/settings_storage.dart';

class AccountsScreen extends StatefulWidget {
  final SettingsStorage storage;
  const AccountsScreen({required this.storage, super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<ServerConnection> _servers = [];

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  void _loadServers() {
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
  }

  Future<void> _saveServers() async {
    final box = widget.storage.box;
    await box.put('servers', _servers.map((s) => s.toMap()).toList());
  }

  Future<void> _addServer() async {
    final result = await _showServerDialog(title: 'Add server');
    if (result != null) {
  setState(() => _servers.add(result));
  await _saveServers();
  _showGreenToast('Server connection saved and validated');
    }
  }

  Future<void> _editServer(ServerConnection server, int index) async {
    final result = await _showServerDialog(title: 'Edit server', initial: server);
    if (result != null) {
  setState(() => _servers[index] = result);
  await _saveServers();
  _showGreenToast('Server updated and validated');
    }
  }

  Future<ServerConnection?> _showServerDialog({required String title, ServerConnection? initial}) async {
    final nameCtrl = TextEditingController(text: initial?.name ?? '');
    final urlCtrl = TextEditingController(text: initial?.url ?? '');
    final apiCtrl = TextEditingController(text: initial?.apiKey ?? '');
    final isEdit = initial != null;

    bool obscure = true;
    // In Add mode reveal is enabled immediately; in Edit it's disabled until user interacts
    bool revealEnabled = !isEdit;
    // For Add we don't want the first-tap clear behavior, so mark cleared=true for Add
    bool cleared = !isEdit;
    final apiFocus = FocusNode();

    bool loading = false;
    String? errorText;

    final res = await showDialog<ServerConnection?>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c2, setStateSB) {
        Widget apiField() {
          return TextField(
            controller: apiCtrl,
            focusNode: apiFocus,
            decoration: InputDecoration(
              labelText: 'API key',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: revealEnabled ? () => setStateSB(() => obscure = !obscure) : null,
              ),
            ),
            obscureText: obscure,
            onTap: () {
              // On first tap in Edit mode, clear the field to avoid accidental exposure and enable reveal
              if (isEdit && !cleared) {
                apiCtrl.clear();
                cleared = true;
                setStateSB(() => revealEnabled = true);
                // move focus to the field so user can start typing
                apiFocus.requestFocus();
              }
            },
            onChanged: (v) {
              if (!revealEnabled) setStateSB(() => revealEnabled = true);
            },
          );
        }

  Future<void> validateAndClose() async {
          setStateSB(() { errorText = null; loading = true; });
          final urlText = urlCtrl.text.trim();
          final apiKeyText = apiCtrl.text.trim();
          if (urlText.isEmpty) {
            setStateSB(() { errorText = 'URL required'; loading = false; });
            return;
          }

          final temp = ServerConnection(
            id: initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameCtrl.text,
            url: urlCtrl.text,
            apiKey: apiKeyText,
            accounts: initial?.accounts ?? [],
          );

          try {
            final m = await ApiService.instance.validateServer(temp);
            try {
              developer.log('AccountsScreen: /api/v1/user response -> $m', name: 'AccountsScreen');
            } catch (_) {}

            final sc = ServerConnection(
              id: temp.id,
              name: temp.name,
              url: temp.url,
              apiKey: temp.apiKey,
              accounts: temp.accounts,
              userId: m['id'] is int ? m['id'] as int : int.tryParse(m['id'].toString()),
              userName: m['name'] as String?,
              userEmail: m['email'] as String?,
              oauthProvider: m['oauth_provider']?.toString(),
              authenticatedByProxy: m['authenticated_by_proxy'] as bool?,
              preferences: m['preferences'] != null ? Map<String, dynamic>.from(m['preferences'] as Map) : null,
              isAdmin: m['is_admin'] as bool?,
            );

            // Ensure the owning State is still mounted before using its context.
            if (!mounted) return;
            setStateSB(() { loading = false; });
            Navigator.of(context).pop(sc);
            return;
          } catch (e) {
            // Convert any error into a user-friendly message via ApiService helper.
            final msg = ApiService.instance.friendlyErrorMessage(e);
            setStateSB(() { errorText = msg; loading = false; });
            return;
          }
        }

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
              apiField(),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading ? null : () async { await validateAndClose(); },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        );
      }),
    );

    return res;
  }

  Future<void> _deleteServer(ServerConnection s) async {
    setState(() => _servers.removeWhere((x) => x.id == s.id));
    await _saveServers();
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
            decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(8)),
            child: Text(text, style: const TextStyle(color: Colors.white)),
          ),
        ),
      );
    });

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () { entry.remove(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts / Servers')),
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
                IconButton(icon: const Icon(Icons.edit), onPressed: () => _editServer(s, index)),
                IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteServer(s)),
              ],
            ),
            onTap: () {
              // Open detail view to manage accounts for this server (not implemented in depth yet)
              Navigator.of(context).push(MaterialPageRoute(builder: (c) => _ServerDetailScreen(server: s, onChanged: (updated) async {
                setState(() {
                  _servers[index] = updated;
                });
                await _saveServers();
              })));
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addServer,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ServerDetailScreen extends StatefulWidget {
  final ServerConnection server;
  final ValueChanged<ServerConnection> onChanged;
  const _ServerDetailScreen({required this.server, required this.onChanged});

  @override
  State<_ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<_ServerDetailScreen> {
  late ServerConnection _server;

  @override
  void initState() {
    super.initState();
    _server = widget.server;
  }

  Future<void> _addAccount() async {
    final svc = TextEditingController();
    final acct = TextEditingController();
    final seed = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: svc, decoration: const InputDecoration(labelText: 'Service')),
            TextField(controller: acct, decoration: const InputDecoration(labelText: 'Account')),
            TextField(controller: seed, decoration: const InputDecoration(labelText: 'Seed')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Add')),
        ],
      ),
    );

    if (res == true) {
      final item = AccountEntry(id: DateTime.now().millisecondsSinceEpoch.toString(), service: svc.text, account: acct.text, seed: seed.text, group: '');
      setState(() {
        _server = ServerConnection(id: _server.id, name: _server.name, url: _server.url, apiKey: _server.apiKey, accounts: [..._server.accounts, item]);
      });
      widget.onChanged(_server);
    }
  }

  void _removeAccount(int idx) {
    final l = List.of(_server.accounts);
    l.removeAt(idx);
    setState(() => _server = ServerConnection(id: _server.id, name: _server.name, url: _server.url, apiKey: _server.apiKey, accounts: l));
    widget.onChanged(_server);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Server: ${_server.name}')),
      body: ListView.builder(
        itemCount: _server.accounts.length,
        itemBuilder: (context, index) {
          final a = _server.accounts[index];
          return ListTile(
            title: Text(a.service),
            subtitle: Text(a.account),
            trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeAccount(index)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _addAccount, child: const Icon(Icons.add)),
    );
  }
}
