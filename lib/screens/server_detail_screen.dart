import 'package:flutter/material.dart';
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import 'dart:developer' as developer;

class ServerDetailScreen extends StatefulWidget {
  final ServerConnection server;
  final ValueChanged<ServerConnection> onChanged;
  const ServerDetailScreen({required this.server, required this.onChanged, super.key});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
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
      final item = AccountEntry(
        id: DateTime.now().millisecondsSinceEpoch,
        service: svc.text,
        account: acct.text,
        seed: seed.text,
        group: '',
        synchronized: false
      );
      try {
        developer.log('AccountsScreen: local manual add service=${item.service} account=${item.account} id=${item.id}', name: 'AccountsScreen');
      } catch (_) {}
      setState(() {
        _server = ServerConnection(
          id: _server.id,
          name: _server.name,
          url: _server.url,
          apiKey: _server.apiKey,
          accounts: [..._server.accounts, item],
          userEmail: _server.userEmail
        );
      });
      widget.onChanged(_server);
    }
  }

  void _removeAccount(int idx) {
    final l = List.of(_server.accounts);
    l.removeAt(idx);
    setState(() => _server = ServerConnection(
      id: _server.id,
      name: _server.name,
      url: _server.url,
      apiKey: _server.apiKey,
      accounts: l,
      userEmail: _server.userEmail
    ));
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
