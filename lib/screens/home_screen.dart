import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/settings_service.dart';
import 'accounts_screen.dart';
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import 'search_bar.dart';
import 'account_list.dart';
import 'bottom_bar.dart';

class HomePage extends StatefulWidget {
  final SettingsService settings;
  const HomePage({required this.settings, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String _selectedGroup = 'All (0)';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;
  late final ScrollController _listScrollController;
  late final AnimationController _headerController;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _headerSizeFactor;
  double _lastScrollOffset = 0.0;
  List<ServerConnection> _servers = [];
  String? _selectedServerId;
  int? _selectedAccountIndex;
  List<AccountEntry> _currentItems = [];
  bool _isSyncing = false;
  bool _suppressNextSyncSnack = false;
  bool _serverReachable = false;
  int _loadServerAttempts = 0;
  static const int _maxLoadServerAttempts = 6;
  bool _suppressFullScreenSyncIndicator = false;
  bool _skipSyncOnLoad = false;
  bool _isManageMode = false;
  final Set<int> _selectedAccountIds = <int>{};

  void _toggleManageMode() {
    setState(() {
      _isManageMode = !_isManageMode;
      if (!_isManageMode) {
        // Salir del modo manage: limpiar selecciones
        _selectedAccountIds.clear();
      }
    });
  }

  void _toggleAccountSelection(int accountId) {
    setState(() {
      if (_selectedAccountIds.contains(accountId)) {
        _selectedAccountIds.remove(accountId);
      } else {
        _selectedAccountIds.add(accountId);
      }
    });
  }

  Future<void> _deleteSelectedAccounts() async {
    if (_selectedAccountIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Accounts'),
        content: Text('Are you sure you want to delete ${_selectedAccountIds.length} selected account(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      // Find selected server index
      final serverIdx = _servers.indexWhere((s) => s.id == _selectedServerId);
      if (serverIdx == -1) {
        if (mounted) {
          setState(() {
            _serverReachable = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No server selected')));
        }
        return;
      }
      final server = _servers[serverIdx];
      
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
      final updatedServers = List<ServerConnection>.from(_servers);
      updatedServers[serverIdx] = updatedServer;
      setState(() {
        _servers = updatedServers;
        _currentItems = updatedServer.accounts.where((a) => !a.deleted).toList();
        _selectedAccountIds.clear();
        _selectedGroup = 'All (${_currentItems.length})';
      });
      
      // Persist updated servers to storage
      final storage = widget.settings.storage;
      if (storage != null) {
        try {
          if (storage.isUnlocked) {
            final box = storage.box;
            final raw = box.get('servers');
            if (raw != null) {
              final list = (raw as List<dynamic>).map((e) => Map<dynamic, dynamic>.from(e)).toList();
              final sIdx = list.indexWhere((e) => e['id'] == server.id);
              if (sIdx != -1) {
                list[sIdx] = updatedServer.toMap();
                await box.put('servers', list);
              }
            }
          }
        } on StateError catch (_) {
          // ignore when locked
        } catch (e) {
          developer.log('HomePage: failed to persist after marking deleted: $e', name: 'HomePage');
        }
      }
      
      // Attempt API delete once (silently)
      if (toDeleteIds.isNotEmpty) {
        if (!ApiService.instance.isReady) {
          // Not ready: indicate no connectivity
          if (mounted) {
            setState(() {
              _serverReachable = false;
            });
          }
        } else {
          try {
            await ApiService.instance.deleteAccounts(toDeleteIds.toList());
            // Success: restore connectivity indicator and remove from local storage
            if (mounted) {
              setState(() {
                _serverReachable = true;
              });
            }
            // Success: remove from local storage and memory
            final finalAccounts = updatedServer.accounts.where((a) => !a.deleted).toList();
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
            final finalServers = List<ServerConnection>.from(_servers);
            finalServers[serverIdx] = finalServer;
            setState(() {
              _servers = finalServers;
              _currentItems = finalAccounts;
              _selectedGroup = 'All (${_currentItems.length})';
            });
            // Persist final removal
            if (storage != null) {
              try {
                if (storage.isUnlocked) {
                  final box = storage.box;
                  final raw = box.get('servers');
                  if (raw != null) {
                    final list = (raw as List<dynamic>).map((e) => Map<dynamic, dynamic>.from(e)).toList();
                    final sIdx = list.indexWhere((e) => e['id'] == server.id);
                    if (sIdx != -1) {
                      list[sIdx] = finalServer.toMap();
                      await box.put('servers', list);
                    }
                  }
                }
              } on StateError catch (_) {} catch (e) {
                developer.log('HomePage: failed to persist after API delete: $e', name: 'HomePage');
              }
            }
          } catch (e) {
            // Silent fail: log only, keep marked deleted for sync retry
            developer.log('HomePage: API delete failed (will retry in sync): $e', name: 'HomePage');
            // Set reachability to false to indicate connectivity issue
            if (mounted) {
              setState(() {
                _serverReachable = false;
              });
            }
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accounts deleted')));
      }
    }
  }

  Future<void> _onRefreshFromPull() async {
    // Called by RefreshIndicator's onRefresh. Suppress the fullscreen overlay
    // because RefreshIndicator already shows a spinner.
    _suppressFullScreenSyncIndicator = true; // Suppress fullscreen sync overlay
    try {
      await _forceSyncCurrentServer();
    } finally {
      _suppressFullScreenSyncIndicator = false;
    }
  }

  Future<void> _forceSyncCurrentServer() async {
    final storage = widget.settings.storage;
    // If storage is not yet available (race during startup), retry a few times
    // before giving up. Do not clear currently displayed servers while retrying.
    if (storage == null) {
      _loadServerAttempts += 1;
      if (_loadServerAttempts <= _maxLoadServerAttempts) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) _loadServers();
        });
        return;
      }
      // fall through: proceed with storage == null (no persistent data)
    }
    if (_selectedServerId == null || storage == null) return;
    final srv = _servers.firstWhere((s) => s.id == _selectedServerId, orElse: () => _servers.first);
    try {
      if (mounted) setState(() { if (!_suppressFullScreenSyncIndicator) _isSyncing = true; });
      final result = await SyncService.instance.forceSync(srv, storage, markAsForced: true);
      // Force sync attempted network operations; success means server reachable
      if (mounted) setState(() { _serverReachable = true; });
      // After forcing sync, reload servers but suppress the automatic sync snackbar
      _suppressNextSyncSnack = true;
      // Prevent the subsequent _loadServers() call from triggering a second network
      // syncIfNeeded immediately after a forced sync. This avoids double network
      // requests when the UI reloads servers right after forcing a sync.
      _skipSyncOnLoad = true;
      await _loadServers();
      if (mounted) {
        if (result['network_failed'] == true) {
          setState(() { _serverReachable = false; });
          developer.log('HomePage: cannot sync (network failure) for server ${srv.id}', name: 'HomePage');
          _suppressNextSyncSnack = false;
        } else {
          if (!_suppressNextSyncSnack) {
            // Only log when an actual network sync ran (not when skipped)
            if (result['skipped'] != true) {
              developer.log('HomePage: sync finished for server ${srv.id}', name: 'HomePage');
            }
          } else {
            _suppressNextSyncSnack = false;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _serverReachable = false; });
        developer.log('HomePage: forceSync failed: $e', name: 'HomePage');
      }
    } finally {
      if (mounted) setState(() { _isSyncing = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();
    _listScrollController = ScrollController();

    // Slower animation so it's clear the header hides upwards and unfolds downwards
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.28), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeInOut));
    _headerSizeFactor = CurvedAnimation(parent: _headerController, curve: Curves.easeInOut);

    // Start visible
    _headerController.value = 1.0;

    // Register named listener so we can remove it on dispose
    _listScrollController.addListener(_handleScroll);
    // Load servers and then perform an initial connectivity check for the selected server.
    _loadServers().then((_) async {
      try {
        final storage = widget.settings.storage;
        if (storage != null && _selectedServerId != null && _servers.isNotEmpty) {
          final srv = _servers.firstWhere((s) => s.id == _selectedServerId, orElse: () => _servers.first);
          // Use ApiService.validateServer which performs GET /user on a short timeout
          try {
            await ApiService.instance.validateServer(srv);
            // If response ok, mark reachable and refresh local data
            if (mounted) {
              setState(() { _serverReachable = true; });
              await _loadServers();
              developer.log('HomePage: initial connectivity check passed for ${srv.id}', name: 'HomePage');
            }
          } catch (e) {
            if (mounted) setState(() { _serverReachable = false; });
            developer.log('HomePage: initial connectivity check failed for ${srv.id}: $e', name: 'HomePage');
          }
        }
      } catch (_) {}
    });
  }

  void _handleScroll() {
    if (!_listScrollController.hasClients) return;
    final offset = _listScrollController.offset;
    final delta = offset - _lastScrollOffset;
    const threshold = 6.0;

    // Only allow hiding when the viewport height is smaller than 4 tiles.
    // AccountTile height is 70 (as defined in account_tile_totp.dart)
    const tileHeight = 70.0;
    final viewport = _listScrollController.position.viewportDimension;
    final allowHide = viewport < (tileHeight * 4);

    if (!allowHide) {
      // If there's enough vertical space, always show the header
      if (_headerController.status != AnimationStatus.forward && _headerController.value < 1.0) {
        _headerController.forward();
      }
    } else {
      if (offset <= 0) {
        // show at top
        if (_headerController.status != AnimationStatus.forward && _headerController.value < 1.0) {
          _headerController.forward();
        }
      } else if (delta > threshold) {
        // scrolling up -> hide (animate upwards)
        if (_headerController.status != AnimationStatus.reverse && _headerController.value > 0.0) {
          _headerController.reverse();
        }
      } else if (delta < -threshold) {
        // scrolling down -> show (unfold downward)
        if (_headerController.status != AnimationStatus.forward && _headerController.value < 1.0) {
          _headerController.forward();
        }
      }
    }

    _lastScrollOffset = offset.clamp(0.0, double.infinity);
  }

  Future<void> _loadServers() async {
    final storage = widget.settings.storage;
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
                .map((e) => ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
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
              restoredAccountIndex = m['accountIndex'] is int ? m['accountIndex'] as int : (m['accountIndex'] == null ? null : int.tryParse(m['accountIndex'].toString()));
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

    setState(() {
      _servers = servers;
      if (_servers.isNotEmpty) {
        if (restoredServerId != null) {
          final idx = _servers.indexWhere((s) => s.id == restoredServerId);
          if (idx != -1) {
            final srv = _servers[idx];
            _selectedServerId = srv.id;
            _selectedAccountIndex = (restoredAccountIndex != null && srv.accounts.length > restoredAccountIndex) ? restoredAccountIndex : (srv.accounts.isNotEmpty ? 0 : null);
            _currentItems = srv.accounts.where((a) => !a.deleted).toList();
            _selectedGroup = 'All (${_currentItems.length})';
          } else {
            final first = _servers[0];
            _selectedServerId = first.id;
            _selectedAccountIndex = first.accounts.isNotEmpty ? 0 : null;
            _currentItems = first.accounts;
            _selectedGroup = 'All (${_currentItems.length})';
          }
        } else {
          final first = _servers[0];
          _selectedServerId = first.id;
          _selectedAccountIndex = first.accounts.isNotEmpty ? 0 : null;
          _currentItems = first.accounts.where((a) => !a.deleted).toList();
          _selectedGroup = 'All (${_currentItems.length})';
        }
      } else {
        _selectedServerId = null;
        _selectedAccountIndex = null;
        _currentItems = [];
        _selectedGroup = 'All (0)';
      }
    });

    // Configure ApiService for the selected server (if any). Ignore errors here.
    if (_selectedServerId != null) {
      try {
        final srv = _servers.firstWhere((s) => s.id == _selectedServerId);
        ApiService.instance.setServer(srv);
        // Attempt a throttled sync to refresh accounts/icons (if we have persistent storage)
        if (storage != null) {
          try {
            // Do not show the fullscreen sync overlay when a pull-to-refresh
            // is active; the RefreshIndicator already shows a spinner.
            if (mounted && !_suppressFullScreenSyncIndicator) setState(() { _isSyncing = true; });
            Map<String, dynamic> result;
            if (_skipSyncOnLoad) {
              // consume the flag and skip the automatic throttled sync because
              // a forceSync just ran and already refreshed server state.
              _skipSyncOnLoad = false;
              developer.log('HomePage: skipping syncIfNeeded because a recent forced sync ran', name: 'HomePage');
              result = {'skipped': true, 'success': true, 'downloaded': 0, 'failed': 0};
            } else {
              final tmp = await SyncService.instance.syncIfNeeded(srv, storage);
              result = tmp;
            }
            // If syncIfNeeded actually performed a network sync, it will not set
            // 'skipped' to true. Only update reachability state when a network
            // attempt occurred and succeeded.
            if (result['skipped'] != true) {
              if (mounted) setState(() { _serverReachable = true; });
            }
            // Reload servers from storage to pick up any updates (icons/local paths)
            try {
              if (storage.isUnlocked) {
                final raw2 = storage.box.get('servers');
                if (raw2 != null) {
                  final servers2 = (raw2 as List<dynamic>)
                      .map((e) => ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
                      .toList();
                  if (mounted) {
                    setState(() {
                      _servers = servers2;
                      final idx = _servers.indexWhere((s) => s.id == srv.id);
                      if (idx != -1) {
                        final updatedSrv = _servers[idx];
                        _currentItems = updatedSrv.accounts.where((a) => !a.deleted).toList();
                        _selectedGroup = 'All (${_currentItems.length})';
                      }
                    });
                  }
                }
              }
            } on StateError catch (_) {
              // storage locked while refreshing; ignore and keep current display
            }
            if (mounted) {
              if (result['network_failed'] == true) {
                setState(() { _serverReachable = false; });
                developer.log('HomePage: cannot sync (network failure) for server ${srv.id}', name: 'HomePage');
                _suppressNextSyncSnack = false;
              } else {
                if (!_suppressNextSyncSnack) {
                  // Only log when an actual network sync ran
                  if (result['skipped'] != true) developer.log('HomePage: sync finished for server ${srv.id}', name: 'HomePage');
                } else {
                  // consume the suppression flag once
                  _suppressNextSyncSnack = false;
                }
              }
            }
          } catch (_) {
            // If a sync error occurred (for example offline or server unreachable),
            // inform the user but keep showing cached data. Also mark unreachable.
            if (mounted) {
              setState(() { _serverReachable = false; });
              if (!_suppressNextSyncSnack) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot sync: offline or server unreachable')));
              } else {
                _suppressNextSyncSnack = false;
              }
            }
          } finally {
            // Only clear the fullscreen overlay if we actually showed it here.
            if (mounted && !_suppressFullScreenSyncIndicator) setState(() { _isSyncing = false; });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _openServerAccountSelector() async {
    if (_servers.isEmpty) return;
    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (c) {
        // Size the sheet based on number of servers (tile height + header), capped to 80% of screen
        final mq = MediaQuery.of(c).size;
        const double tileH = 72.0;
        const double headerH = 56.0;
        final desired = headerH + (_servers.length * tileH);
        final maxH = mq.height * 0.8;
        final height = desired.clamp(120.0, maxH);

        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Align(alignment: Alignment.centerLeft, child: Text('Servers', style: Theme.of(context).textTheme.titleMedium)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _servers.length,
                    itemBuilder: (ctx, idx) {
                      final srv = _servers[idx];
                      final isActive = srv.id == _selectedServerId;
                      return ListTile(
                        title: Text('${srv.name} (${Uri.parse(srv.url).host})'),
                        subtitle: Text(srv.url),
                        trailing: isActive ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () {
                          Navigator.of(ctx).pop({'serverId': srv.id, 'accountIndex': null});
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null) {
      if (!mounted) return;

      final serverId = choice['serverId'] as String;
      final accountIndex = choice['accountIndex'] as int?;
      final server = _servers.firstWhere((s) => s.id == serverId);
      // Prefer sample data for display when available
      setState(() {
        _selectedServerId = serverId;
        _selectedAccountIndex = accountIndex;
        _currentItems = server.accounts.where((a) => !a.deleted).toList();
        _selectedGroup = 'All (${_currentItems.length})';
      });

      // Persist selection
      final storage = widget.settings.storage;
      if (storage != null) {
        try {
          if (storage.isUnlocked) {
            await storage.box.put('selected', {'serverId': serverId, 'accountIndex': accountIndex});
          }
        } on StateError catch (_) {
          // ignore persistence when locked
        }
      }

      // Configure ApiService for the newly selected server. Show error if it fails.
      try {
        ApiService.instance.setServer(server);
        // Trigger a throttled sync and reload servers so cached icons/local paths are available
        final storage = widget.settings.storage;
        if (storage != null) {
          try {
            final result = await SyncService.instance.syncIfNeeded(server, storage);
            // If network sync occurred and returned (not skipped), mark reachable
            if (result['skipped'] != true) {
              if (mounted) setState(() { _serverReachable = true; });
            }
            // Suppress the automatic notification from _loadServers() and show only this one
            _suppressNextSyncSnack = true;
            await _loadServers();
            if (mounted) {
              if (result['skipped'] != true) developer.log('HomePage: sync finished for server ${server.id}', name: 'HomePage');
            }
          } catch (_) {
            if (mounted) setState(() { _serverReachable = false; });
          }
        }
      } catch (e) {
        if (mounted) {
          developer.log('HomePage: Error configuring API: $e', name: 'HomePage');
        }
      }
    }
  }

  /// Called when the user presses the manual sync button in the UI. Ensure
  /// the fullscreen syncing indicator is shown immediately while the
  /// refresh/sync runs, even if the underlying sync logic decides not to show
  /// it for its own reasons.
  Future<void> _manualSyncPressed() async {
    // Suppress the fullscreen overlay for manual sync; show only the
    // small spinner in the sync button.
    if (mounted) {
      setState(() {
        _suppressFullScreenSyncIndicator = true;
        _isSyncing = true;
      });
    }
    try {
      await _onRefreshFromPull();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _suppressFullScreenSyncIndicator = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _listScrollController.removeListener(_handleScroll);
    _listScrollController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  List<String> _groups() {
    final Map<String, int> counts = {};
    for (final item in _currentItems) {
      final g = item.group.trim();
      if (g.isEmpty) continue; // do not include ungrouped entries in selector
      counts[g] = (counts[g] ?? 0) + 1;
    }
    developer.log('HomePage: computed group counts=${counts.toString()} from ${_currentItems.length} items', name: 'HomePage');
    final groups = ['All (${_currentItems.length})'];
    groups.addAll(counts.keys.map((k) => '$k (${counts[k]})'));
    return groups;
  }

  String _groupKey(String display) {
    // Convert 'Work (4)' -> 'Work', 'All (71)' -> 'All'
    final idx = display.indexOf(' (');
    if (idx == -1) return display;
    return display.substring(0, idx);
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    // If storage exists but is locked (biometric required and not yet satisfied),
    // show a minimal screen with a single centered 'Retry' button so the user
    // can re-attempt authentication. This prevents the home UI from being
    // visible while the local store is locked.
    final storage = widget.settings.storage;
    if (storage != null && !storage.isUnlocked) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Biometric authentication failed or was cancelled. Please retry to unlock your local data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await storage.attemptUnlock();
                    if (ok) {
                      // Reload servers from unlocked storage and rebuild UI
                      await _loadServers();
                      if (!mounted) return;
                      setState(() {});
                    } else {
                      messenger.showSnackBar(const SnackBar(content: Text('Authentication failed')));
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Animated header: slide up when hiding, slide down when showing.
                SizeTransition(
                  sizeFactor: _headerSizeFactor,
                  axisAlignment: -1.0,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            children: [
                              if (_servers.isNotEmpty)
                                Expanded(
                                  child: HomeSearchBar(
                                    controller: _searchController,
                                    focusNode: _searchFocus,
                                    onChanged: (v) => setState(() => _searchQuery = v),
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox()),
                              const SizedBox(width: 8),
                              // Manual sync button that performs the same action as pull-to-refresh
                              _isSyncing
                                  ? SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: const CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : _servers.isEmpty
                                      ? const SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: Icon(Icons.sync, color: Colors.grey),
                                        )
                                      : Semantics(
                                          label: 'Synchronize',
                                          button: true,
                                          child: IconButton(
                                            tooltip: 'Synchronize',
                                            icon: const Icon(Icons.sync),
                                            onPressed: _manualSyncPressed,
                                          ),
                                        ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Group selector
                        Center(
                          child: _isManageMode && _selectedAccountIds.isNotEmpty
                              ? Text(
                                  '${_selectedAccountIds.length} selected',
                                  style: TextStyle(color: Colors.grey.shade700),
                                )
                              : PopupMenuButton<String>(
                                  initialValue: _selectedGroup,
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedGroup = value;
                                    });
                                  },
                                  itemBuilder: (context) => groups
                                      .map((g) => PopupMenuItem(value: g, child: Text(g)))
                                      .toList(),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_selectedGroup, style: TextStyle(color: Colors.grey.shade700)),
                                      const SizedBox(width: 6),
                                      Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey.shade600),
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                // Forzar Expanded y asegurar que la lista ocupa todo el espacio disponible
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenW = MediaQuery.of(context).size.width;
                      if (screenW > 1400) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: SizedBox.expand(
                              child: AccountList(
                                selectedGroup: _groupKey(_selectedGroup),
                                searchQuery: _searchQuery,
                                settings: widget.settings,
                                items: _currentItems,
                                onRefresh: _onRefreshFromPull,
                                scrollController: _listScrollController,
                                isManageMode: _isManageMode,
                                selectedAccountIds: _selectedAccountIds,
                                onToggleAccountSelection: _toggleAccountSelection,
                              ),
                            ),
                          ),
                        );
                      }
                      return SizedBox.expand(
                        child: AccountList(
                          selectedGroup: _groupKey(_selectedGroup),
                          searchQuery: _searchQuery,
                          settings: widget.settings,
                          items: _currentItems,
                          onRefresh: _onRefreshFromPull,
                          scrollController: _listScrollController,
                          isManageMode: _isManageMode,
                          selectedAccountIds: _selectedAccountIds,
                          onToggleAccountSelection: _toggleAccountSelection,
                        ),
                      );
                    },
                  ),
                ),
                BottomBar(
                  settings: widget.settings,
                  servers: _servers,
                  selectedServerId: _selectedServerId,
                  selectedAccountIndex: _selectedAccountIndex,
                  onOpenSelector: _openServerAccountSelector,
                  serverReachable: _serverReachable,
                  isManageMode: _isManageMode,
                  selectedAccountIds: _selectedAccountIds,
                  onToggleManageMode: _toggleManageMode,
                  onDeleteSelected: _deleteSelectedAccounts,
                  onOpenAccounts: () async {
                    if (widget.settings.storage != null) {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (c) => AccountsScreen(storage: widget.settings.storage!)));
                      // After returning from AccountsScreen, reload servers from storage
                      await _loadServers();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage not available')));
                    }
                  },
                  onNewAccount: (acct) {
                    // Add new unsynced account to the currently selected server in memory
                    if (_selectedServerId != null) {
                      final idx = _servers.indexWhere((s) => s.id == _selectedServerId);
                      if (idx != -1) {
                        final srv = _servers[idx];
                        srv.accounts.add(acct);
                        // also update _currentItems and UI
                        setState(() {
                          _currentItems = srv.accounts.where((a) => !a.deleted).toList();
                          _selectedGroup = 'All (${_currentItems.length})';
                        });

                        // Best-effort persist to storage in background.
                        final storage = widget.settings.storage;
                        if (storage != null) {
                          Future.microtask(() async {
                            try {
                              if (storage.isUnlocked) {
                                await storage.box.put('servers', _servers.map((s) => s.toMap()).toList());
                              }
                            } on StateError catch (_) {
                              // ignore when storage is locked
                            } catch (e) {
                              developer.log('HomePage: failed to persist servers after new account: $e', name: 'HomePage');
                            }
                          });
                        }
                      }
                    } else {
                      // If no server selected, append to in-memory list only
                      setState(() {
                        _currentItems.add(acct);
                        _selectedGroup = 'All (${_currentItems.length})';
                      });

                      // Attempt to persist as well (will write current _servers list)
                      final storage = widget.settings.storage;
                      if (storage != null) {
                        Future.microtask(() async {
                          try {
                            if (storage.isUnlocked) {
                              await storage.box.put('servers', _servers.map((s) => s.toMap()).toList());
                            }
                          } on StateError catch (_) {
                            // ignore when storage is locked
                          } catch (e) {
                            developer.log('HomePage: failed to persist servers after new account (no selected server): $e', name: 'HomePage');
                          }
                        });
                      }
                    }
                  },
                ),
              ],
            ),
            if (_isSyncing && !_suppressFullScreenSyncIndicator)
              Positioned.fill(
                child: Container(
                  color: const Color.fromRGBO(0, 0, 0, 0.35),
                  child: Center(
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Syncing...', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
