import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/settings_service.dart';
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import '../services/api_service.dart';

class HomeServerManager extends ChangeNotifier {
  final SettingsService settings;

  List<ServerConnection> _servers = [];
  String? _selectedServerId;
  int? _selectedAccountIndex;
  List<AccountEntry> _currentItems = [];
  bool _serverReachable = false;
  int _loadServerAttempts = 0;
  static const int _maxLoadServerAttempts = 6;

  HomeServerManager(this.settings);

  // Getters
  List<ServerConnection> get servers => _servers;
  String? get selectedServerId => _selectedServerId;
  int? get selectedAccountIndex => _selectedAccountIndex;
  List<AccountEntry> get currentItems => _currentItems;
  bool get serverReachable => _serverReachable;

  void updateServerReachability(bool reachable) {
    if (_serverReachable != reachable) {
      _serverReachable = reachable;
      notifyListeners();
    }
  }

  Future<void> loadServers() async {
    final storage = settings.storage;
    List<ServerConnection> servers = [];
    // Keep a copy of the currently displayed servers so we can fall back to them
    // if storage returns empty due to a failed/partial sync while offline.
    final previousServers = List<ServerConnection>.from(_servers);
    String? restoredServerId;
    int? restoredAccountIndex;
    // Track whether storage actually provided a value. We only want to
    // fallback to the in-memory cached servers when storage did not provide
    // a value (for example the key is missing or the store is locked). If
    // storage returned an empty list that means the user intentionally
    // removed all servers and we should respect that.
    bool storageProvided = false;

    if (storage != null) {
      try {
        if (storage.isUnlocked) {
          final box = storage.box;
          final raw = box.get('servers');
          if (raw != null) {
            storageProvided = true;
            servers = (raw as List<dynamic>)
                .map((e) =>
                    ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
                .toList();
          } else {
            // raw == null -> storage had no key for 'servers'
            storageProvided = false;
          }
          // Try to restore previously selected server/account
          final selRaw = box.get('selected');
          if (selRaw != null) {
            try {
              final m = Map<dynamic, dynamic>.from(selRaw);
              restoredServerId = m['serverId'] as String?;
              restoredAccountIndex = m['accountIndex'] is int
                  ? m['accountIndex'] as int
                  : (m['accountIndex'] == null
                      ? null
                      : int.tryParse(m['accountIndex'].toString()));
            } catch (_) {
              restoredServerId = null;
              restoredAccountIndex = null;
            }
          }
        }
      } on StateError catch (_) {
        // Storage locked — behave as if no persistent servers available.
        storageProvided = false;
      }
    }

    // Only fallback to the previously cached in-memory servers when storage
    // did not provide any value (null or locked). If storage returned an
    // empty list that's an intentional state (e.g. user deleted all servers)
    // and we should not restore the old entries.
    final usedCachedFallback = !storageProvided && previousServers.isNotEmpty;
    if (usedCachedFallback) {
      servers = previousServers;
    }

    _servers = servers;
    if (_servers.isNotEmpty) {
      if (restoredServerId != null) {
        final idx = _servers.indexWhere((s) => s.id == restoredServerId);
        if (idx != -1) {
          final srv = _servers[idx];
          _selectedServerId = srv.id;
          _selectedAccountIndex = (restoredAccountIndex != null &&
                  srv.accounts.length > restoredAccountIndex)
              ? restoredAccountIndex
              : (srv.accounts.isNotEmpty ? 0 : null);
          _currentItems = srv.accounts.where((a) => !a.deleted).toList();
        } else {
          final first = _servers[0];
          _selectedServerId = first.id;
          _selectedAccountIndex = first.accounts.isNotEmpty ? 0 : null;
          _currentItems = first.accounts;
        }
      } else {
        final first = _servers[0];
        _selectedServerId = first.id;
        _selectedAccountIndex = first.accounts.isNotEmpty ? 0 : null;
        _currentItems = first.accounts.where((a) => !a.deleted).toList();
      }
    } else {
      _selectedServerId = null;
      _selectedAccountIndex = null;
      _currentItems = [];
    }

    // Configure ApiService for the selected server (if any). Ignore errors here.
    if (_selectedServerId != null) {
      try {
        final srv = _servers.firstWhere((s) => s.id == _selectedServerId);
        ApiService.instance.setServer(srv);
      } catch (_) {}
    }

    notifyListeners();
  }

  Future<bool> selectServer(String serverId, {int? accountIndex}) async {
    if (!_servers.any((s) => s.id == serverId)) {
      return false;
    }

    final server = _servers.firstWhere((s) => s.id == serverId);

    _selectedServerId = serverId;
    _selectedAccountIndex = accountIndex;
    _currentItems = server.accounts.where((a) => !a.deleted).toList();

    // Persist selection
    final storage = settings.storage;
    if (storage != null) {
      try {
        if (storage.isUnlocked) {
          await storage.box.put(
              'selected', {'serverId': serverId, 'accountIndex': accountIndex});
        }
      } on StateError catch (_) {
        // ignore persistence when locked
      }
    }

    // Configure ApiService for the newly selected server
    try {
      ApiService.instance.setServer(server);
    } catch (e) {
      developer.log('HomeServerManager: Error configuring API: $e',
          name: 'HomeServerManager');
    }

    notifyListeners();
    return true;
  }

  Future<void> initialConnectivityCheck() async {
    if (_selectedServerId == null || _servers.isEmpty) return;

    final storage = settings.storage;
    // If storage is not yet available (race during startup), retry a few times
    if (storage == null) {
      _loadServerAttempts += 1;
      if (_loadServerAttempts <= _maxLoadServerAttempts) {
        Future.delayed(const Duration(milliseconds: 400), () {
          initialConnectivityCheck();
        });
        return;
      }
      return;
    }

    try {
      final srv = _servers.firstWhere((s) => s.id == _selectedServerId,
          orElse: () => _servers.first);
      // Use ApiService.validateServer which performs GET /user on a short timeout
      await ApiService.instance.validateServer(srv);
      // If response ok, mark reachable
      _serverReachable = true;
      notifyListeners();
      developer.log(
          'HomeServerManager: initial connectivity check passed for ${srv.id}',
          name: 'HomeServerManager');
    } catch (e) {
      _serverReachable = false;
      notifyListeners();
      developer.log('HomeServerManager: initial connectivity check failed: $e',
          name: 'HomeServerManager');
    }
  }

  void updateServersInMemory(List<ServerConnection> updatedServers) {
    _servers = updatedServers;
    if (_selectedServerId != null) {
      final idx = _servers.indexWhere((s) => s.id == _selectedServerId);
      if (idx != -1) {
        final updatedServer = _servers[idx];
        _currentItems =
            updatedServer.accounts.where((a) => !a.deleted).toList();
      }
    }
    notifyListeners();
  }

  Future<void> persistServersToStorage() async {
    final storage = settings.storage;
    if (storage != null) {
      try {
        if (storage.isUnlocked) {
          await storage.box
              .put('servers', _servers.map((s) => s.toMap()).toList());
        }
      } on StateError catch (_) {
        // ignore when storage is locked
      } catch (e) {
        developer.log('HomeServerManager: failed to persist servers: $e',
            name: 'HomeServerManager');
      }
    }
  }

  void addNewAccount(AccountEntry account) {
    if (_selectedServerId != null) {
      final idx = _servers.indexWhere((s) => s.id == _selectedServerId);
      if (idx != -1) {
        final srv = _servers[idx];
        srv.accounts.add(account);
        _currentItems = srv.accounts.where((a) => !a.deleted).toList();
        notifyListeners();

        // Best-effort persist to storage in background
        persistServersToStorage();
      }
    } else {
      // If no server selected, append to in-memory list only
      _currentItems.add(account);
      notifyListeners();
      persistServersToStorage();
    }
  }

  /// Obtiene el servidor actualmente seleccionado
  ServerConnection? getSelectedServer() {
    if (_selectedServerId != null) {
      final idx = _servers.indexWhere((s) => s.id == _selectedServerId);
      if (idx != -1) {
        return _servers[idx];
      }
    }
    return null;
  }

  /// Actualiza una cuenta existente
  Future<void> updateAccount(AccountEntry updatedAccount) async {
    if (_selectedServerId != null) {
      final idx = _servers.indexWhere((s) => s.id == _selectedServerId);
      if (idx != -1) {
        final srv = _servers[idx];
        final accountIdx =
            srv.accounts.indexWhere((a) => a.id == updatedAccount.id);
        if (accountIdx != -1) {
          // Preserve the synchronized flag provided by caller (AdvancedForm may already have attempted server update)
          srv.accounts[accountIdx] = updatedAccount;
          _currentItems = srv.accounts.where((a) => !a.deleted).toList();
          notifyListeners();

          // Persistir cambios
          await persistServersToStorage();

          developer.log(
              'HomeServerManager: updated account id=${updatedAccount.id} service=${updatedAccount.service} (marked unsynchronized)',
              name: 'HomeServerManager');
        }
      }
    }
  }

  List<String> getGroups() {
    final Map<String, int> counts = {};
    for (final item in _currentItems) {
      final g = item.group.trim();
      if (g.isEmpty) continue; // do not include ungrouped entries in selector
      counts[g] = (counts[g] ?? 0) + 1;
    }
    developer.log(
        'HomeServerManager: computed group counts=${counts.toString()} from ${_currentItems.length} items',
        name: 'HomeServerManager');
    // Return group keys (unlocalized). The UI will localize formatting.
    final groups = ['All'];
    groups.addAll(counts.keys);
    return groups;
  }

  String getGroupKey(String display) {
    // Convert 'Work (4)' -> 'Work', 'All (71)' -> 'All'
    final idx = display.indexOf(' (');
    if (idx == -1) return display;
    return display.substring(0, idx);
  }
}
