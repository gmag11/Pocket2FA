import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../models/account_entry.dart';
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String _selectedGroup = 'All';
  String _searchQuery = '';
  late final TextEditingController _searchController;
  late final FocusNode _searchFocus;

  // Managers
  late final HomeServerManager _serverManager;
  late final HomeSyncManager _syncManager;
  late final HomeManageMode _manageMode;
  late final HomeHeaderAnimation _headerAnimation;

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

    // Load servers and perform initial connectivity check
    _loadServersAndInitialize();
  }

  void _onServerManagerChanged() {
    if (mounted) {
      setState(() {
        // Keep the logical group key; UI will localize the display.
        _selectedGroup = 'All';
      });
    }
  }

  void _onSyncManagerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onManageModeChanged() {
    if (mounted) {
      setState(() {});
    }
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
            existingEntry: account, // Pasar la entrada existente para edición
          );
        },
      ),
    );

    if (result != null) {
      // La entrada fue editada, actualizarla en el servidor manager
      await _serverManager.updateAccount(result);

      // Mostrar mensaje de confirmación
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

    // Attempt throttled sync if we have servers
    if (_serverManager.servers.isNotEmpty) {
      try {
        await _syncManager.performThrottledSync();
      } catch (e) {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.cannotSync)),
            );
        }
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
                        title: Text(l10n
                            .serverWithHost(srv.name, Uri.parse(srv.url).host)),
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
    super.dispose();
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
                    final authFailedMsg =
                        l10n.authenticationFailed;
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
            // Full screen sync indicator
            if (_syncManager.isSyncing &&
                !_syncManager.suppressFullScreenSyncIndicator)
              _buildSyncOverlay(),
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
            : Semantics(
                label: l10n.synchronize,
                button: true,
                child: IconButton(
                  tooltip: l10n.synchronize,
                  icon: const Icon(Icons.sync),
                  onPressed: _syncManager.manualSyncPressed,
                ),
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
              SnackBar(
                  content: Text(l10n.storageNotAvailable)),
            );
        }
      },
      onNewAccount: _serverManager.addNewAccount,
    );
  }

  Widget _buildSyncOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color.fromRGBO(0, 0, 0, 0.35),
        child: Center(
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                    Text(l10n.syncing,
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
