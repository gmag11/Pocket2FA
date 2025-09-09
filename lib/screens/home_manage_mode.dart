import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'dart:developer' as developer;
import '../services/api_service.dart';
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import 'home_server_manager.dart';

class HomeManageMode extends ChangeNotifier {
  final HomeServerManager serverManager;

  bool _isManageMode = false;
  final Set<int> _selectedAccountIds = <int>{};

  HomeManageMode(this.serverManager);

  // Getters
  bool get isManageMode => _isManageMode;
  Set<int> get selectedAccountIds => _selectedAccountIds;

  void toggleManageMode() {
    _isManageMode = !_isManageMode;
    if (!_isManageMode) {
      // Exit manage mode: clear selections
      _selectedAccountIds.clear();
    }
    notifyListeners();
  }

  void toggleAccountSelection(int accountId) {
    if (_selectedAccountIds.contains(accountId)) {
      _selectedAccountIds.remove(accountId);
    } else {
      _selectedAccountIds.add(accountId);
    }
    notifyListeners();
  }

  Future<bool> deleteSelectedAccounts(BuildContext context) async {
    if (_selectedAccountIds.isEmpty) return false;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteAccountsTitle),
        content: Text(l10n.deleteAccountsConfirm(_selectedAccountIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final servers = serverManager.servers;
    final selectedServerId = serverManager.selectedServerId;

    // Find selected server index
    final serverIdx = servers.indexWhere((s) => s.id == selectedServerId);
    if (serverIdx == -1) {
      serverManager.updateServerReachability(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.noServerSelected)));
      }
      return false;
    }

    final server = servers[serverIdx];

    // Mark selected as deleted=true, synchronized=false; create updated accounts list
    final updatedAccounts = <AccountEntry>[];
    final toDeleteIds = <int>{};
    for (final acc in server.accounts) {
      if (_selectedAccountIds.contains(acc.id)) {
        toDeleteIds.add(acc.id);
        // Mark as deleted but keep in storage for now
        updatedAccounts.add(acc.copyWith(deleted: true, synchronized: false));
      } else {
        updatedAccounts.add(acc);
      }
    }

    // Create new ServerConnection with updated accounts (immutable)
    final updatedServer = ServerConnection(
      id: server.id,
      name: server.name,
      url: server.url,
      apiKey: server.apiKey,
      accounts: updatedAccounts,
      groups: server.groups,
      userId: server.userId,
      userName: server.userName,
      userEmail: server.userEmail,
      oauthProvider: server.oauthProvider,
      authenticatedByProxy: server.authenticatedByProxy,
      preferences: server.preferences,
      isAdmin: server.isAdmin,
    );

    // Update in-memory servers list
    final updatedServers = List<ServerConnection>.from(servers);
    updatedServers[serverIdx] = updatedServer;
    serverManager.updateServersInMemory(updatedServers);

    _selectedAccountIds.clear();
    notifyListeners();

    // Persist updated servers to storage
    await serverManager.persistServersToStorage();

    // Attempt API delete once (silently)
    if (toDeleteIds.isNotEmpty) {
      await _attemptApiDelete(toDeleteIds, serverIdx, updatedServer);
    }

    // Check context is still mounted before showing snackbar
    if (!context.mounted) return true;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.accountsDeleted)));

    return true;
  }

  Future<void> _attemptApiDelete(
    Set<int> toDeleteIds,
    int serverIdx,
    ServerConnection updatedServer,
  ) async {
    if (!ApiService.instance.isReady) {
      // Not ready: indicate no connectivity
      serverManager.updateServerReachability(false);
      return;
    }

    try {
      await ApiService.instance.deleteAccounts(toDeleteIds.toList());
      // Success: restore connectivity indicator and remove from local storage
      serverManager.updateServerReachability(true);

      // Success: remove only the accounts we requested to delete from local storage and memory
      final finalAccounts = updatedServer.accounts
          .where((a) => !toDeleteIds.contains(a.id))
          .toList();

      final finalServer = ServerConnection(
        id: updatedServer.id,
        name: updatedServer.name,
        url: updatedServer.url,
        apiKey: updatedServer.apiKey,
        accounts: finalAccounts,
        groups: updatedServer.groups,
        userId: updatedServer.userId,
        userName: updatedServer.userName,
        userEmail: updatedServer.userEmail,
        oauthProvider: updatedServer.oauthProvider,
        authenticatedByProxy: updatedServer.authenticatedByProxy,
        preferences: updatedServer.preferences,
        isAdmin: updatedServer.isAdmin,
      );

      final servers = serverManager.servers;
      final finalServers = List<ServerConnection>.from(servers);
      finalServers[serverIdx] = finalServer;
      serverManager.updateServersInMemory(finalServers);

      // Persist final removal
      await serverManager.persistServersToStorage();
    } catch (e) {
      // Silent fail: log only, keep marked deleted for sync retry
      developer.log(
          'HomeManageMode: API delete failed (will retry in sync): $e',
          name: 'HomeManageMode');
      // Set reachability to false to indicate connectivity issue
      serverManager.updateServerReachability(false);
    }
  }
}
