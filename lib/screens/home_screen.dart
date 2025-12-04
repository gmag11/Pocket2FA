import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/settings_service.dart';
import '../models/account_entry.dart';
import '../widgets/about_dialog.dart';
import 'accounts_screen.dart';
import 'search_bar.dart';
import 'account_list.dart';
import 'bottom_bar.dart';
import 'advanced_form_screen.dart';
import 'home_server_manager.dart';
import 'home_sync_manager.dart';
import 'home_manage_mode.dart';
import 'home_header_animation.dart';

class HomePage extends StatefulWidget {
  final SettingsService settings;
  const HomePage({required this.settings, super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
  with TickerProviderStateMixin, WidgetsBindingObserver {
  String _selectedGroup = 'All';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;

  // Managers
  late final HomeServerManager _serverManager;
  late final HomeSyncManager _syncManager;
  late final HomeManageMode _manageMode;
  late final HomeHeaderAnimation _headerAnimation;
  Timer? _autoSyncTimer;
  bool _initialSyncDone = false;
  bool _wasInManageMode = false;

  // Convenience getter for localized strings
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();

    // Initialize managers
    _serverManager = HomeServerManager(widget.settings);
    _syncManager = HomeSyncManager(_serverManager);
    _manageMode = HomeManageMode(_serverManager);
    _headerAnimation = HomeHeaderAnimation();

    // Initialize header animation
    _headerAnimation.initialize(this);

    // Add listeners
    _serverManager.addListener(_onServerManagerChanged);
    _syncManager.addListener(_onSyncManagerChanged);
    _manageMode.addListener(_onManageModeChanged);
  widget.settings.addListener(_onSettingsChanged);
  WidgetsBinding.instance.addObserver(this);

    developer.log('HomePage: initState - starting loadServersAndInitialize', name: 'HomePage');
    // Load servers and perform initial connectivity check
  _loadServersAndInitialize();
  }

  void _onServerManagerChanged() {
    if (mounted) {
      setState(() {
        // Keep the logical group key; UI will localize the display.
        _selectedGroup = 'All';
      });
  // If servers became available after load, attempt initial sync if needed
  developer.log('HomePage: server manager changed; servers=${_serverManager.servers.length}', name: 'HomePage');
  _maybePerformInitialSync();
    }
  }

  void _onSyncManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onManageModeChanged() {
    if (mounted) {
      final was = _wasInManageMode;
      setState(() {});
      // When entering/exiting manage mode, (re)configure auto-sync
      _setupAutoSync();
      // If we just exited manage mode (was true, now false), trigger a forced sync
      if (was && !_manageMode.isManageMode) {
        developer.log('HomePage: exited manage mode - performing forced sync', name: 'HomePage');
        if (_serverManager.servers.isNotEmpty) {
          _syncManager.forceSyncCurrentServer().catchError((e) {
            developer.log('HomePage: forced sync after manage exit failed: $e', name: 'HomePage');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.cannotSync)),
              );
            }
          });
        }
      }
      _wasInManageMode = _manageMode.isManageMode;
    }
  }

  void _onSettingsChanged() {
    // Settings changed (auto-sync toggle/interval or sync-on-open). Reconfigure auto-sync.
    if (mounted) {
      setState(() {});
    developer.log('HomePage: settings changed; syncOnOpen=${widget.settings.syncOnOpen} autoSyncEnabled=${widget.settings.autoSyncEnabled} interval=${widget.settings.autoSyncIntervalMinutes}',
      name: 'HomePage');
    _setupAutoSync();
  // If the user enabled syncOnOpen after settings loaded, attempt initial sync
  _maybePerformInitialSync();
    }
  }

  void _setupAutoSync() {
    // Cancel any existing timer
    if (_autoSyncTimer != null) {
      developer.log('HomePage: cancelling existing autoSync timer', name: 'HomePage');
      _autoSyncTimer?.cancel();
    }

    // Do not start auto-sync if disabled, if there are no servers, or when in manage mode
    if (!widget.settings.autoSyncEnabled || _serverManager.servers.isEmpty || _manageMode.isManageMode) {
      _autoSyncTimer = null;
      return;
    }

    final mins = widget.settings.autoSyncIntervalMinutes;
    // Guard against invalid values
    final interval = Duration(minutes: mins > 0 ? mins : 30);

    developer.log('HomePage: starting autoSync timer interval=${interval.inMinutes}min', name: 'HomePage');
    // Start periodic timer
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      // Respect manage mode at execution time as well
      if (_manageMode.isManageMode) return;
      if (_serverManager.servers.isEmpty) return;
      developer.log('HomePage: autoSync timer fired - attempting forced sync', name: 'HomePage');
      try {
        await _syncManager.forceSyncCurrentServer();
        developer.log('HomePage: autoSync forced sync completed', name: 'HomePage');
      } catch (e) {
        developer.log('HomePage: autoSync forced sync error: $e', name: 'HomePage');
        _serverManager.updateServerReachability(false);
      }
    });
  }

  Future<void> _editAccount(AccountEntry account) async {
    final result = await Navigator.of(context).push<AccountEntry>(
      MaterialPageRoute(
        builder: (context) {
          final selectedServer = _serverManager.getSelectedServer();
          return AdvancedFormScreen(
            userEmail: selectedServer?.userEmail ?? l10n.unknown,
            serverHost: selectedServer?.url ?? l10n.unknown,
            groups: selectedServer?.groups,
            existingEntry: account, // Pass the existing entry for editing
          );
        },
      ),
    );

    if (result != null) {
  // The entry was edited, update it in the server manager
      await _serverManager.updateAccount(result);

  // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.accountUpdated)),
        );
      }
    }
  }

  Future<void> _loadServersAndInitialize() async {
    await _serverManager.loadServers();
    await _serverManager.initialConnectivityCheck();

  // Attempt initial throttled sync according to settings; may run later if
  // settings or servers become available after startup.
  _maybePerformInitialSync();

    // Configure auto-sync timer if enabled
    _setupAutoSync();
  }

  void _maybePerformInitialSync() async {
    // Only attempt once per HomePage lifecycle
    if (_initialSyncDone) {
      developer.log('HomePage: skipping initial sync - already done', name: 'HomePage');
      return;
    }
    // Do not attempt while in manage mode
    if (_manageMode.isManageMode) return;
    // Ensure settings wants sync on open and servers exist
    if (!widget.settings.syncOnOpen) {
      developer.log('HomePage: syncOnOpen disabled - not performing initial sync', name: 'HomePage');
      return;
    }
    if (_serverManager.servers.isEmpty) {
      developer.log('HomePage: no servers available - not performing initial sync', name: 'HomePage');
      return;
    }

    developer.log('HomePage: conditions met - performing initial forced sync', name: 'HomePage');
    _initialSyncDone = true;
    try {
      await _syncManager.forceSyncCurrentServer();
      developer.log('HomePage: initial forced sync completed', name: 'HomePage');
    } catch (e) {
      developer.log('HomePage: initial forced sync failed: $e', name: 'HomePage');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.cannotSync)),
        );
      }
    }
  }

  Future<void> _openServerAccountSelector() async {
    if (_serverManager.servers.isEmpty) return;

    final choice = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (c) {
        // Size the sheet based on number of servers
        final mq = MediaQuery.of(c).size;
        const double tileH = 72.0;
        const double headerH = 56.0;
        final desired = headerH + (_serverManager.servers.length * tileH);
        final maxH = mq.height * 0.8;
        final height = desired.clamp(120.0, maxH);

        return SafeArea(
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.serversTitle,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _serverManager.servers.length,
                    itemBuilder: (ctx, idx) {
                      final srv = _serverManager.servers[idx];
                      final isActive =
                          srv.id == _serverManager.selectedServerId;
                      return ListTile(
                        title: Text(l10n.serverWithHost(
                            srv.name, Uri.parse(srv.url).host)),
                        subtitle: Text(srv.url),
                        trailing: isActive
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () {
                          Navigator.of(ctx)
                              .pop({'serverId': srv.id, 'accountIndex': null});
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

    if (choice != null && mounted) {
      final serverId = choice['serverId'] as String;
      final accountIndex = choice['accountIndex'] as int?;

      final success = await _serverManager.selectServer(serverId,
          accountIndex: accountIndex);
      if (success) {
        // Trigger sync for newly selected server
        try {
      developer.log('HomePage: server selected - performing throttled sync', name: 'HomePage');
      await _syncManager.performThrottledSync();
        } catch (_) {
          // Ignore sync errors on server selection
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _headerAnimation.dispose();
    _serverManager.removeListener(_onServerManagerChanged);
    _syncManager.removeListener(_onSyncManagerChanged);
    _manageMode.removeListener(_onManageModeChanged);
  widget.settings.removeListener(_onSettingsChanged);
  _autoSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returned to foreground. If user enabled sync-on-open, trigger a sync.
      if (mounted && widget.settings.syncOnOpen && !_manageMode.isManageMode) {
        if (_serverManager.servers.isNotEmpty) {
          // Fire-and-forget but surface errors as SnackBar like initial sync
          _syncManager.forceSyncCurrentServer().catchError((e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.cannotSync)),
              );
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = widget.settings.storage;

    // If storage exists but is locked (biometric required and not yet satisfied),
    // show a minimal screen with a single centered 'Retry' button
    if (storage != null && !storage.isUnlocked) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    l10n.biometricAuthFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    // capture localized message before await to avoid context-after-await lint
                    final authFailedMsg = l10n.authenticationFailed;
                    final ok = await storage.attemptUnlock();
                    if (ok) {
                      await _serverManager.loadServers();
                    } else {
                      messenger
                          .showSnackBar(SnackBar(content: Text(authFailedMsg)));
                    }
                  },
                  child: Text(l10n.retry),
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
                // Animated header
                SizeTransition(
                  sizeFactor: _headerAnimation.headerSizeFactor,
                  axisAlignment: -1.0,
                  child: SlideTransition(
                    position: _headerAnimation.headerSlide,
                    child: _buildHeader(),
                  ),
                ),
                // Account list
                Expanded(
                  child: _buildAccountList(),
                ),
                // Bottom bar
                _buildBottomBar(),
              ],
            ),
            // Full screen sync indicator removed: sync is signaled only via
            // the small spinner in the search bar's sync icon.
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final groups = _serverManager.getGroups();

    return Column(
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              if (_serverManager.servers.isNotEmpty)
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
              _buildSyncButton(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Group selector
        Center(
          child: _buildGroupSelector(groups),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSyncButton() {
    return _syncManager.isSyncing
        ? const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : _serverManager.servers.isEmpty
            ? const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.sync, color: Colors.grey),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
        children: [
                  Semantics(
                    label: l10n.synchronize,
                    button: true,
                    child: IconButton(
                      tooltip: l10n.synchronize,
                      icon: const Icon(Icons.sync),
            onPressed: _manageMode.isManageMode
              ? null
              : _syncManager.manualSyncPressed,
                    ),
                  ),
                  // no countdown displayed
                  // Popup menu with About entry
                  PopupMenuButton<String>(
                    tooltip: l10n.about,
                    onSelected: (v) async {
                      if (v == 'about') {
                        _showAboutDialog();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: 'about', child: Text(l10n.about)),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(Icons.more_vert),
                    ),
                  ),
                ],
              );
  }

  // Countdown helper removed

  void _showAboutDialog() {
    // NOTE: appVersion is kept in sync manually with pubspec.yaml's version: field.
    const appVersion = '0.9.3';

    showDialog<void>(
      context: context,
      builder: (c) => AboutDialogContent(appVersion: appVersion),
    );
  }

  Widget _buildGroupSelector(List<String> groups) {
    return _manageMode.isManageMode && _manageMode.selectedAccountIds.isNotEmpty
        ? Text(
            l10n.selectedCount(_manageMode.selectedAccountIds.length),
            style: TextStyle(color: Colors.grey.shade700),
          )
        : PopupMenuButton<String>(
            initialValue: _selectedGroup,
            onSelected: (value) {
              setState(() {
                // Store the logical group key; format when rendering.
                _selectedGroup = value;
              });
            },
            itemBuilder: (context) => groups
                .map((g) => PopupMenuItem(
                    value: g,
                    child: Text(g == 'All'
                        ? l10n.groupAll(_serverManager.currentItems.length)
                        : '$g (${_serverManager.currentItems.where((a) => a.group.trim() == g).length})')))
                .toList(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(builder: (ctx) {
                  final display = _selectedGroup == 'All'
                      ? l10n.groupAll(_serverManager.currentItems.length)
                      : '$_selectedGroup (${_serverManager.currentItems.where((a) => a.group.trim() == _selectedGroup).length})';
                  return Text(display,
                      style: TextStyle(color: Colors.grey.shade700));
                }),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down,
                    size: 18, color: Colors.grey.shade600),
              ],
            ),
          );
  }

  Widget _buildAccountList() {
    final screenW = MediaQuery.of(context).size.width;
    if (screenW > 1400) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SizedBox.expand(
            child: _buildAccountListContent(),
          ),
        ),
      );
    }
    return SizedBox.expand(
      child: _buildAccountListContent(),
    );
  }

  Widget _buildAccountListContent() {
    return AccountList(
      selectedGroup: _serverManager.getGroupKey(_selectedGroup),
      searchQuery: _searchQuery,
      settings: widget.settings,
      items: _serverManager.currentItems,
      onRefresh: _syncManager.onRefreshFromPull,
      scrollController: _headerAnimation.listScrollController,
      isManageMode: _manageMode.isManageMode,
      selectedAccountIds: _manageMode.selectedAccountIds,
      onToggleAccountSelection: _manageMode.toggleAccountSelection,
      onEditAccount: _editAccount,
    );
  }

  Widget _buildBottomBar() {
    return BottomBar(
      settings: widget.settings,
      servers: _serverManager.servers,
      selectedServerId: _serverManager.selectedServerId,
      selectedAccountIndex: _serverManager.selectedAccountIndex,
      onOpenSelector: _openServerAccountSelector,
      serverReachable: _serverManager.serverReachable,
      isManageMode: _manageMode.isManageMode,
      selectedAccountIds: _manageMode.selectedAccountIds,
      onToggleManageMode: _manageMode.toggleManageMode,
      onDeleteSelected: () => _manageMode.deleteSelectedAccounts(context),
      onOpenAccounts: () async {
        if (widget.settings.storage != null) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (c) =>
                  AccountsScreen(storage: widget.settings.storage!)));
          // After returning from AccountsScreen, reload servers from storage
          await _serverManager.loadServers();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.storageNotAvailable)),
          );
        }
      },
      onNewAccount: _serverManager.addNewAccount,
    );
  }

  // _buildSyncOverlay removed: full-screen sync overlay is no longer used.
}
