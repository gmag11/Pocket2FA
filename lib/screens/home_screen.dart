import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/account_tile.dart';
import '../services/settings_service.dart';
import 'settings_screen.dart';
import 'accounts_screen.dart';
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

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
    if (storage != null) {
      try {
        if (storage.isUnlocked) {
          final box = storage.box;
          final raw = box.get('servers');
          if (raw != null) {
            servers = (raw as List<dynamic>)
                .map((e) => ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
                .toList();
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
      }
    }

    // If storage returned no servers but we had servers previously, keep
    // showing the cached servers instead of clearing the UI.
    final usedCachedFallback = servers.isEmpty && previousServers.isNotEmpty;
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
            _currentItems = srv.accounts;
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
          _currentItems = first.accounts;
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
            final result = await SyncService.instance.syncIfNeeded(srv, storage);
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
                        _currentItems = updatedSrv.accounts;
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
      final serverId = choice['serverId'] as String;
      final accountIndex = choice['accountIndex'] as int?;
      final server = _servers.firstWhere((s) => s.id == serverId);
      // Prefer sample data for display when available
      setState(() {
        _selectedServerId = serverId;
        _selectedAccountIndex = accountIndex;
  _currentItems = server.accounts;
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
                              Expanded(
                                child: _SearchBar(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  onChanged: (v) => setState(() => _searchQuery = v),
                                ),
                              ),
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
                                  : IconButton(
                                      tooltip: 'Sync',
                                      icon: const Icon(Icons.sync),
                                      onPressed: () async {
                                        await _manualSyncPressed();
                                      },
                                    ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Group selector
                        Center(
                          child: PopupMenuButton<String>(
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
                              child: _AccountList(
                                selectedGroup: _groupKey(_selectedGroup),
                                searchQuery: _searchQuery,
                                settings: widget.settings,
                                items: _currentItems,
                                onRefresh: _onRefreshFromPull,
                                scrollController: _listScrollController,
                              ),
                            ),
                          ),
                        );
                      }
                      return SizedBox.expand(
                        child: _AccountList(
                          selectedGroup: _groupKey(_selectedGroup),
                          searchQuery: _searchQuery,
                          settings: widget.settings,
                          items: _currentItems,
                          onRefresh: _onRefreshFromPull,
                          scrollController: _listScrollController,
                        ),
                      );
                    },
                  ),
                ),
                _BottomBar(
                  settings: widget.settings,
                  servers: _servers,
                  selectedServerId: _selectedServerId,
                  selectedAccountIndex: _selectedAccountIndex,
                  onOpenSelector: _openServerAccountSelector,
                  serverReachable: _serverReachable,
                  onOpenAccounts: () async {
                    if (widget.settings.storage != null) {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (c) => AccountsScreen(storage: widget.settings.storage!)));
                      // After returning from AccountsScreen, reload servers from storage
                      await _loadServers();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage not available')));
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

class _SearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  const _SearchBar({this.controller, this.focusNode, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller ?? TextEditingController(),
              builder: (context, value, _) {
                final hasText = value.text.isNotEmpty;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    border: InputBorder.none,
                    isDense: true,
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller?.clear();
                              onChanged?.call('');
                              // keep focus after clearing
                              focusNode?.requestFocus();
                            },
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountList extends StatelessWidget {
  final String selectedGroup;
  final String searchQuery;
  final SettingsService settings;
  final List<AccountEntry> items;
  final Future<void> Function()? onRefresh;
  final ScrollController? scrollController;

  const _AccountList({required this.selectedGroup, required this.searchQuery, required this.settings, required this.items, this.onRefresh, this.scrollController});

  @override
  Widget build(BuildContext context) {
    // Helper refresh wrapper that uses provided onRefresh when available.
    Future<void> handleRefresh() async {
      if (onRefresh != null) {
        await onRefresh!();
      }
    }

    // If no accounts/items available, return informative message but keep pull-to-refresh
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No accounts registered', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    final base = selectedGroup == 'All' || selectedGroup.isEmpty
      ? items
      : items.where((i) => i.group == selectedGroup).toList();

    final query = searchQuery.toLowerCase();
    final filtered = query.isEmpty
      ? base
      : base.where((i) {
        final s = i.service.toLowerCase();
        final a = i.account.toLowerCase();
        return s.contains(query) || a.contains(query);
      }).toList();

    // No results after filtering — still allow pull-to-refresh
    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No results', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    int columns;
    if (width > 1200) {
      columns = 3;
    } else if (width > 800) {
      columns = 2;
    } else {
      columns = 1;
    }

    if (columns == 1) {
      return RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView.separated(
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: filtered.length,
          separatorBuilder: (context, index) => Divider(indent: 20, endIndent: 20,),
          itemBuilder: (context, index) {
            try {
              final item = filtered[index];
              return AccountTile(item: item, settings: settings);
            } catch (e) {
              return ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Error al mostrar cuenta'),
                subtitle: Text(e.toString()),
                isThreeLine: true,
                dense: true,
              );
            }
          },
        ),
      );
    }

    // Multi-column grid for wide screens (up to 3 columns) — wrap with RefreshIndicator
    return RefreshIndicator(
      onRefresh: handleRefresh,
      child: GridView.builder(
  controller: scrollController,
  physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisExtent: 92, // enough to contain the 72px tile plus spacing
        ),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          try {
            final item = filtered[index];
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: AccountTile(item: item, settings: settings),
            );
          } catch (e) {
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Error al mostrar cuenta'),
                subtitle: Text(e.toString()),
                isThreeLine: true,
                dense: true,
              ),
            );
          }
        },
      ),
    );
  }
}

// _IconCircle removed (now unused after refactor)

class _BottomBar extends StatelessWidget {
  final SettingsService settings;
  final List<ServerConnection> servers;
  final String? selectedServerId;
  final int? selectedAccountIndex;
  final bool serverReachable;
  final VoidCallback onOpenSelector;
  final VoidCallback? onOpenAccounts;

  const _BottomBar({required this.settings, required this.servers, required this.selectedServerId, required this.selectedAccountIndex, required this.onOpenSelector, this.onOpenAccounts, required this.serverReachable});

  @override
  Widget build(BuildContext context) {
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
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  // Validate servers exist
                  if (servers.isEmpty) {
                    messenger.showSnackBar(const SnackBar(
                      content: Text('No hay servidores configurados'),
                    ));
                    return;
                  }

                  // Select active server
                  final srv = selectedServerId != null
                      ? servers.firstWhere((s) => s.id == selectedServerId, orElse: () => servers.first)
                      : servers.first;

                  final urlStr = srv.url.trim();
                  final parsed = Uri.tryParse(urlStr);

                  // Validate that the URL has an http/https scheme and a host
                  if (parsed == null || parsed.scheme.isEmpty || !(parsed.scheme == 'http' || parsed.scheme == 'https') || parsed.host.isEmpty) {
                    messenger.showSnackBar(const SnackBar(
                      content: Text('URL del servidor inválida (falta http/https)'),
                    ));
                    return;
                  }

                  // Build /start URI and launch externally
                  final trimmed = urlStr.endsWith('/') ? urlStr.substring(0, urlStr.length - 1) : urlStr;
                  final uri = Uri.parse('$trimmed/start');
                  try {
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(uri);
                    }
                  } catch (e) {
                    developer.log('HomePage: cannot launch $uri: $e', name: 'HomePage');
                    messenger.showSnackBar(SnackBar(
                      content: Text('No se pudo abrir la URL: $e'),
                    ));
                  }
                },
                icon: const Icon(Icons.qr_code, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: const Color(0xFF4F63E6), // custom blue to match design
                ),
                label: const Text('New', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {}, // active but no-op for now
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Manage'),
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
                                      children: [
                                        Expanded(
                                          child: Center(
                                            child: Text('user@domain.com', style: TextStyle(color: Colors.grey)),
                                          ),
                                        ),
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
                    Icon(Icons.more_vert, size: 18, color: Colors.grey),
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
