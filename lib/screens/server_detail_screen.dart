import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/server_connection.dart';

class ServerDetailScreen extends StatefulWidget {
  final ServerConnection server;
  final ValueChanged<ServerConnection> onChanged;
  const ServerDetailScreen(
      {required this.server, required this.onChanged, super.key});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen> {
  late ServerConnection _server;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _server = widget.server;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.serverLabel}: ${_server.name}')),
      body: ListView.builder(
        itemCount: _server.accounts.length,
        itemBuilder: (context, index) {
          final a = _server.accounts[index];
          return ListTile(
            title: Text(a.service),
            subtitle: Text(a.account),
          );
        },
      ),
    );
  }
}
