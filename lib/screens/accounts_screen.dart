import 'package:flutter/material.dart';
import '../models/server_connection.dart';
import '../models/two_factor_item.dart';
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
    }
  }

  Future<void> _editServer(ServerConnection server, int index) async {
    final result = await _showServerDialog(title: 'Edit server', initial: server);
    if (result != null) {
      setState(() => _servers[index] = result);
      await _saveServers();
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

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
              apiField(),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(null), child: const Text('Cancel')),
            ElevatedButton(onPressed: () {
              final id = initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
              final accounts = initial?.accounts ?? [];
              Navigator.of(c).pop(ServerConnection(id: id, name: nameCtrl.text, url: urlCtrl.text, apiKey: apiCtrl.text, accounts: accounts));
            }, child: Text(isEdit ? 'Save' : 'Add')),
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
      final item = TwoFactorItem(service: svc.text, account: acct.text, twoFa: '000000', nextTwoFa: '000000', group: '');
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
