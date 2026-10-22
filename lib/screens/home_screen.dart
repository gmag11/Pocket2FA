import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pocket2fa/screens/new_code_screen.dart';

import '../l10n/app_localizations.dart';
import '../models/account_entry.dart';
import '../models/server_connection.dart';
import '../services/incoming_image_processor.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../services/settings_storage.dart';
import '../widgets/about_dialog.dart';
import 'account_list.dart';
import 'accounts_screen.dart';
import 'advanced_form_screen.dart';
import 'bottom_bar.dart';
import 'home_header_animation.dart';
import 'home_manage_mode.dart';
import 'home_server_manager.dart';
import 'home_sync_manager.dart';
import 'search_bar.dart';
import 'log_screen.dart';
import 'pin_lock_screen.dart';
import 'settings_screen.dart';

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
  bool _fabVisible = true;
  double _lastFabScrollOffset = 0.0;

  // Incoming image intake (Android share intent and desktop drop).
  static const MethodChannel _incomingImageChannel =
      MethodChannel('net.gmartin.pocket2fa/incoming_image');
  static const String _maxIncomingSizeLabel = '32 MiB';
  static const String _desktopStagingDirName = 'incoming_qr_desktop';
  final Random _stagingRandom = Random();
  late final DateTime _sessionStartedAt;
  bool _serversLoaded = false;
  IncomingImageDescriptor? _pendingIncomingImage;
  bool _incomingImageProcessing = false;
  bool _isDesktopDragVisible = false;

  bool get _supportsDesktopDrop =>
      Platform.isWindows || Platform.isLinux;

  // Convenience getter for localized strings
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    _searchController = TextEditingController();
    _searchFocus = FocusNode();

    // Initialize managers
    _serverManager = HomeServerManager(widget.settings);
    _syncManager = HomeSyncManager(_serverManager);
    _manageMode = HomeManageMode(_serverManager);
    _headerAnimation = HomeHeaderAnimation();

    // Initialize header animation
    _headerAnimation.initialize(this);
    _headerAnimation.listScrollController.addListener(_onScrollForFab);

    // Add listeners
    _serverManager.addListener(_onServerManagerChanged);
    _syncManager.addListener(_onSyncManagerChanged);
    _manageMode.addListener(_onManageModeChanged);
  widget.settings.addListener(_onSettingsChanged);
  WidgetsBinding.instance.addObserver(this);

    // Desktop drops are staged once per app session.
    if (_supportsDesktopDrop) {
      unawaited(_cleanDesktopStaging());
    }

    // Android shares are delivered through a bidirectional method channel.
    // Registering the handler before clientReady lets native flush a cold-start
    // share exactly once.
    if (Platform.isAndroid) {
      unawaited(_registerIncomingImageChannel());
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeFlushPendingIncomingImage());

    LogService.instance.log('HomePage: initState - starting loadServersAndInitialize', name: 'HomePage');
    // Load servers and perform initial connectivity check
  _loadServersAndInitialize();
  }

  void _onScrollForFab() {
    if (!_headerAnimation.listScrollController.hasClients) return;
    final offset = _headerAnimation.listScrollController.offset;
    final delta = offset - _lastFabScrollOffset;
    const threshold = 6.0;
    if (offset <= 0) {
      if (!_fabVisible) setState(() => _fabVisible = true);
    } else if (delta > threshold) {
      if (_fabVisible) setState(() => _fabVisible = false);
    } else if (delta < -threshold) {
      if (!_fabVisible) setState(() => _fabVisible = true);
    }
    _lastFabScrollOffset = offset.clamp(0.0, double.infinity);
  }

  void _onServerManagerChanged() {
    if (mounted) {
      setState(() {
        // Preserve the selected group across syncs; only fall back to 'All'
        // when the group no longer exists in the current data.
        final availableGroups = _serverManager.getGroups();
        if (!availableGroups.contains(_selectedGroup)) {
          _selectedGroup = 'All';
        }
      });
  // If servers became available after load, attempt initial sync if needed
  LogService.instance.log('HomePage: server manager changed; servers=${_serverManager.servers.length}', name: 'HomePage');
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
      // Do not replace entries while the user is selecting or deleting them.
      _syncManager.setRetryPaused(_manageMode.isManageMode);
      // If we just exited manage mode (was true, now false), trigger a forced sync
      if (was && !_manageMode.isManageMode) {
        LogService.instance.log('HomePage: exited manage mode - performing forced sync', name: 'HomePage');
        if (_serverManager.servers.isNotEmpty) {
          _syncManager.forceSyncCurrentServer().catchError((e) {
            LogService.instance.log('HomePage: forced sync after manage exit failed: $e', name: 'HomePage');
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
    LogService.instance.log('HomePage: settings changed; syncOnOpen=${widget.settings.syncOnOpen} autoSyncEnabled=${widget.settings.autoSyncEnabled} interval=${widget.settings.autoSyncIntervalMinutes}',
      name: 'HomePage');
    _setupAutoSync();
  // If the user enabled syncOnOpen after settings loaded, attempt initial sync
  _maybePerformInitialSync();
    }
  }

  void _setupAutoSync() {
    // Cancel any existing timer
    if (_autoSyncTimer != null) {
      LogService.instance.log('HomePage: cancelling existing autoSync timer', name: 'HomePage');
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

    LogService.instance.log('HomePage: starting autoSync timer interval=${interval.inMinutes}min', name: 'HomePage');
    // Start periodic timer
    _autoSyncTimer = Timer.periodic(interval, (_) async {
      // Respect manage mode at execution time as well
      if (_manageMode.isManageMode) return;
      if (_serverManager.servers.isEmpty) return;
      LogService.instance.log('HomePage: autoSync timer fired - attempting forced sync', name: 'HomePage');
      try {
        await _syncManager.forceSyncCurrentServer();
        LogService.instance.log('HomePage: autoSync forced sync completed', name: 'HomePage');
      } catch (e) {
        LogService.instance.log('HomePage: autoSync forced sync error: $e', name: 'HomePage');
        _serverManager.updateServerReachability(false);
      }
    });
  }

  Future<void> _editAccount(AccountEntry account) async {
    // Borrowed accounts are read-only: never open the edit form for them.
    if (account.isBorrowed) return;
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
    _serversLoaded = true;
    await _serverManager.initialConnectivityCheck();

  // Attempt initial throttled sync according to settings; may run later if
  // settings or servers become available after startup.
  _maybePerformInitialSync();

    // Upload accounts created in a previous offline session even when
    // sync-on-open and auto-sync are disabled. If the initial sync already
    // started, this schedules a retry instead of overlapping it.
    unawaited(_syncManager.ensurePendingUploads());

    // Configure auto-sync timer if enabled
    _setupAutoSync();

    // A share or drop that arrived before servers were loaded is processed now.
    unawaited(_maybeFlushPendingIncomingImage());
  }

  // ---------------------------------------------------------------------------
  // Incoming image intake (Android share intent + desktop drop)
  // ---------------------------------------------------------------------------

  Future<void> _registerIncomingImageChannel() async {
    _incomingImageChannel.setMethodCallHandler((call) async {
      if (call.method != 'sharedImage') return;
      final args = call.arguments;
      if (args is Map) {
        _enqueueIncomingImage(
          IncomingImageDescriptor.fromMap(Map<Object?, Object?>.from(args)),
        );
      }
    });

    try {
      await _incomingImageChannel.invokeMethod<void>('clientReady');
    } catch (e) {
      LogService.instance.log('HomePage: clientReady failed: $e',
          name: 'HomePage');
    }
  }

  void _enqueueIncomingImage(IncomingImageDescriptor descriptor) {
    if (!mounted) {
      unawaited(deleteIncomingWorkingCopy(descriptor.path));
      return;
    }

    LogService.instance.log(
      descriptor.isRejected
          ? 'HomePage: incoming image rejected (${descriptor.rejectionReason})'
          : 'HomePage: incoming image accepted (${descriptor.mimeType ?? 'unknown type'})',
      name: 'HomePage',
    );

    if (descriptor.isRejected) {
      _showIncomingMessage(
        incomingRejectionMessage(
            l10n, descriptor.rejectionReason, _maxIncomingSizeLabel),
        backgroundColor: Colors.red,
      );
      return;
    }

    if (_incomingImageProcessing || _pendingIncomingImage != null) {
      // Keep at most one accepted image queued. The newer working copy is
      // discarded so the cache cannot accumulate abandoned files.
      unawaited(deleteIncomingWorkingCopy(descriptor.path));
      _showIncomingMessage(l10n.incomingImageBusy,
          backgroundColor: Colors.orange);
      return;
    }

    _pendingIncomingImage = descriptor;
    unawaited(_maybeFlushPendingIncomingImage());
  }

  Future<void> _maybeFlushPendingIncomingImage() async {
    final descriptor = _pendingIncomingImage;
    if (descriptor == null || _incomingImageProcessing || !mounted) return;

    // Never process while encrypted storage is still locked.
    final storage = widget.settings.storage;
    if (storage != null && !storage.isUnlocked) {
      LogService.instance.log(
          'HomePage: holding incoming image until storage is unlocked',
          name: 'HomePage');
      return;
    }

    // Wait until the server list has been loaded once.
    if (!_serversLoaded) return;

    final server = _serverManager.getSelectedServer();
    if (server == null) {
      _pendingIncomingImage = null;
      await deleteIncomingWorkingCopy(descriptor.path);
      if (mounted) {
        _showIncomingMessage(l10n.serverRequiredForImage,
            backgroundColor: Colors.orange);
      }
      return;
    }

    _pendingIncomingImage = null;
    await _processIncomingImage(descriptor, server);
  }

  Future<void> _processIncomingImage(
      IncomingImageDescriptor descriptor, ServerConnection server) async {
    final path = descriptor.path;
    if (path == null || path.isEmpty) {
      _showIncomingMessage(l10n.unreadableImage, backgroundColor: Colors.red);
      return;
    }

    _incomingImageProcessing = true;

    // The result must be visible on the accounts screen: leave manage mode and,
    // on Android, return to the root route before showing the dialog.
    if (_manageMode.isManageMode) {
      _manageMode.toggleManageMode();
    }
    if (Platform.isAndroid && mounted) {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    }

    var dialogVisible = false;
    if (mounted) {
      dialogVisible = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.processingIncomingImage)),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final outcome = await const IncomingImageProcessor().process(
        path: path,
        serverHost: Uri.parse(server.url).host,
        groups: server.groups,
        context: context,
      );
      if (!mounted) return;

      switch (outcome) {
        case IncomingImageSuccess(:final entry):
          await _serverManager.insertCreatedAccount(entry);
          if (mounted) {
            _showIncomingMessage(l10n.accountUpdated);
          }
          // A local pending entry is uploaded by the offline-first retry loop;
          // an already synchronized entry is a no-op.
          unawaited(_syncManager.ensurePendingUploads());
        case IncomingImageFailure(:final kind):
          final message = incomingFailureMessage(
            l10n,
            kind,
            maxFileSize: _maxIncomingSizeLabel,
          );
          // invalidQr was already reported by EntryCreationService.
          if (message != null) {
            _showIncomingMessage(message, backgroundColor: Colors.red);
          }
      }
    } catch (e) {
      LogService.instance.log('HomePage: incoming image failed: $e',
          name: 'HomePage');
      if (mounted) {
        _showIncomingMessage(l10n.unreadableImage, backgroundColor: Colors.red);
      }
    } finally {
      if (dialogVisible && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await deleteIncomingWorkingCopy(path);
      _incomingImageProcessing = false;
      if (mounted) setState(() {});
      unawaited(_maybeFlushPendingIncomingImage());
    }
  }

  void _showIncomingMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      // The first frame may not be built yet (cold-start share). Retry once
      // after the frame so the message is not lost.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message), backgroundColor: backgroundColor),
        );
      });
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop drag-and-drop
  // ---------------------------------------------------------------------------

  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
    'heic',
    'heif',
    'avif',
  };

  void _onDesktopDragEntered(DropEventDetails details) {
    if (!mounted || _isDesktopDragVisible) return;
    setState(() => _isDesktopDragVisible = true);
  }

  void _onDesktopDragExited(DropEventDetails details) {
    if (!mounted || !_isDesktopDragVisible) return;
    setState(() => _isDesktopDragVisible = false);
  }

  void _onDesktopDragDone(DropDoneDetails details) {
    if (mounted && _isDesktopDragVisible) {
      setState(() => _isDesktopDragVisible = false);
    }
    unawaited(_handleDesktopDrop(details));
  }

  Future<void> _handleDesktopDrop(DropDoneDetails details) async {
    if (details.files.isEmpty) {
      _showIncomingMessage(l10n.unsupportedFile, backgroundColor: Colors.red);
      return;
    }
    if (details.files.length > 1) {
      _showIncomingMessage(l10n.oneImageAtATime, backgroundColor: Colors.red);
      return;
    }

    final item = details.files.first;
    if (item is! DropItemFile) {
      _showIncomingMessage(l10n.unsupportedFile, backgroundColor: Colors.red);
      return;
    }
    if (!_looksLikeImage(item.mimeType, item.name)) {
      _showIncomingMessage(l10n.unsupportedFile, backgroundColor: Colors.red);
      return;
    }

    final descriptor = await _stageDroppedFile(item);
    if (descriptor != null) {
      _enqueueIncomingImage(descriptor);
    }
  }

  bool _looksLikeImage(String? mimeType, String name) {
    if (mimeType != null && mimeType.startsWith('image/')) return true;
    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot == -1) return false;
    return _imageExtensions.contains(lower.substring(dot + 1));
  }

  String _imageExtension(String? mimeType, String name) {
    switch (mimeType?.toLowerCase()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
      case 'image/x-ms-bmp':
        return 'bmp';
      case 'image/heic':
        return 'heic';
      case 'image/heif':
        return 'heif';
      case 'image/avif':
        return 'avif';
    }

    final lower = name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    if (dot != -1) {
      final extension = lower.substring(dot + 1);
      if (_imageExtensions.contains(extension)) {
        return extension == 'jpeg' ? 'jpg' : extension;
      }
    }
    return 'img';
  }

  Future<IncomingImageDescriptor?> _stageDroppedFile(DropItemFile item) async {
    File? target;
    IOSink? sink;

    try {
      final cacheDir = await getApplicationCacheDirectory();
      final directory =
          Directory('${cacheDir.path}/$_desktopStagingDirName');
      await directory.create(recursive: true);

      final extension = _imageExtension(item.mimeType, item.name);
      final unique =
          '${DateTime.now().microsecondsSinceEpoch}_${_stagingRandom.nextInt(1 << 32)}';
      final stagedFile = File('${directory.path}/$unique.$extension');
      target = stagedFile;
      final output = stagedFile.openWrite();
      sink = output;

      var total = 0;
      await for (final chunk in item.openRead()) {
        total += chunk.length;
        if (total > IncomingImageProcessor.maxFileBytes) {
          await output.close();
          sink = null;
          await stagedFile.delete();
          target = null;
          if (mounted) {
            _showIncomingMessage(
              l10n.imageTooLarge(_maxIncomingSizeLabel),
              backgroundColor: Colors.red,
            );
          }
          return null;
        }
        output.add(chunk);
      }

      await output.flush();
      await output.close();
      sink = null;

      return IncomingImageDescriptor.image(
        path: stagedFile.path,
        mimeType: item.mimeType,
        name: item.name,
      );
    } catch (e) {
      LogService.instance.log('HomePage: desktop drop copy failed: $e',
          name: 'HomePage');
      try {
        await sink?.close();
      } catch (_) {}
      if (target != null) {
        await deleteIncomingWorkingCopy(target.path);
      }
      if (mounted) {
        _showIncomingMessage(l10n.unreadableImage, backgroundColor: Colors.red);
      }
      return null;
    }
  }

  Future<void> _cleanDesktopStaging() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      final directory =
          Directory('${cacheDir.path}/$_desktopStagingDirName');
      if (!await directory.exists()) return;

      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        try {
          // Only remove files that predate this app session, so a file staged
          // by a drop while cleanup is running is never deleted.
          final modified = (await entity.stat()).modified;
          if (modified.isBefore(_sessionStartedAt)) {
            await entity.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      LogService.instance.log('HomePage: desktop staging cleanup failed: $e',
          name: 'HomePage');
    }
  }

  Widget _buildDesktopDropOverlay() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 18, spreadRadius: 2),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_for_offline_outlined,
                size: 64, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              l10n.dropQrImageHere,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
    );
  }

  void _maybePerformInitialSync() async {
    // Only attempt once per HomePage lifecycle
    if (_initialSyncDone) {
      LogService.instance.log('HomePage: skipping initial sync - already done', name: 'HomePage');
      return;
    }
    // Do not attempt while in manage mode
    if (_manageMode.isManageMode) return;
    // Ensure settings wants sync on open and servers exist
    if (!widget.settings.syncOnOpen) {
      LogService.instance.log('HomePage: syncOnOpen disabled - not performing initial sync', name: 'HomePage');
      return;
    }
    if (_serverManager.servers.isEmpty) {
      LogService.instance.log('HomePage: no servers available - not performing initial sync', name: 'HomePage');
      return;
    }

    LogService.instance.log('HomePage: conditions met - performing initial forced sync', name: 'HomePage');
    _initialSyncDone = true;
    try {
      await _syncManager.forceSyncCurrentServer();
      LogService.instance.log('HomePage: initial forced sync completed', name: 'HomePage');
    } catch (e) {
      LogService.instance.log('HomePage: initial forced sync failed: $e', name: 'HomePage');
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
        // Size the sheet based on number of servers, header, and manage button
        final mq = MediaQuery.of(c).size;
        const double headerH = 40.0;
        const double manageButtonH = 56.0;
        const double tileH = 72.0;
        final desired = headerH + manageButtonH + ((_serverManager.servers.length) * tileH);
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
                    itemCount: _serverManager.servers.length + 1,
                    itemBuilder: (ctx, idx) {
                      // First item is "Manage Servers"
                      if (idx == 0) {
                        return ListTile(
                          leading: const Icon(Icons.settings, color: Colors.blue),
                          title: Text(l10n.manageServers),
                          onTap: () {
                            Navigator.of(ctx).pop({'action': 'manage_servers'});
                          },
                        );
                      }
                      
                      // Server items (shifted by 1)
                      final srv = _serverManager.servers[idx - 1];
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
      // Handle "Manage Servers" action
      if (choice['action'] == 'manage_servers') {
        if (widget.settings.storage != null) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (c) => AccountsScreen(
                    storage: widget.settings.storage!,
                    settings: widget.settings,
                    onServerChanged: _serverManager.loadServers,
                  )));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.storageNotAvailable)),
          );
        }
        return;
      }
      
      // Handle server selection
      final serverId = choice['serverId'] as String?;
      final accountIndex = choice['accountIndex'] as int?;

      if (serverId != null) {
        final success = await _serverManager.selectServer(serverId,
            accountIndex: accountIndex);
        if (success) {
          // Trigger sync for newly selected server
          try {
        LogService.instance.log('HomePage: server selected - performing throttled sync', name: 'HomePage');
        await _syncManager.performThrottledSync();
          } catch (_) {
            // Ignore sync errors on server selection
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _incomingImageChannel.setMethodCallHandler(null);
    _headerAnimation.listScrollController.removeListener(_onScrollForFab);
    _searchController.dispose();
    _searchFocus.dispose();
    _headerAnimation.dispose();
    _serverManager.removeListener(_onServerManagerChanged);
    _syncManager.removeListener(_onSyncManagerChanged);
    _syncManager.dispose();
    _manageMode.removeListener(_onManageModeChanged);
  widget.settings.removeListener(_onSettingsChanged);
  _autoSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted && !_manageMode.isManageMode) {
        if (_syncManager.hasPendingUploads) {
          // Pending local accounts must be retried even when sync-on-open is
          // disabled. The retry manager handles backoff and errors.
          unawaited(_syncManager.ensurePendingUploads());
        } else if (widget.settings.syncOnOpen &&
            _serverManager.servers.isNotEmpty) {
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

      // A share/drop held while locked is processed after the app becomes
      // active again (some unlock paths do not route through PinLockScreen).
      unawaited(_maybeFlushPendingIncomingImage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildHomeContent(context);
    if (!_supportsDesktopDrop) return content;

    return DropTarget(
      enable: true,
      onDragEntered: _onDesktopDragEntered,
      onDragExited: _onDesktopDragExited,
      onDragDone: _onDesktopDragDone,
      child: Stack(
        children: [
          content,
          if (_isDesktopDragVisible)
            Positioned.fill(
              child: IgnorePointer(child: _buildDesktopDropOverlay()),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    final storage = widget.settings.storage;

    // If storage exists but is locked, show a screen that reflects the real
    // cause: a pending biometric prompt, unavailable biometrics, or a failure
    // to read the platform secure storage (e.g. a broken keyring). Retry
    // re-runs the storage read, so a recoverable failure is not a dead end.
    // The AppBar is kept so the user can still navigate to Settings or to the
    // Debug Log.
    if (storage != null && !storage.isUnlocked) {
      // With the PIN lock enabled the dedicated lock screen owns unlocking
      // (PIN or biometric). A secure-storage failure is still reported by the
      // generic screen below, since the PIN could not be verified either.
      if ((storage.isPinLocked || widget.settings.pinEnabled) &&
          !storage.hasStorageError) {
        return PinLockScreen(
          settings: widget.settings,
          title: l10n.appTitle,
          onUnlocked: () async {
            await _serverManager.loadServers();
            _serversLoaded = true;
            if (mounted) setState(() {});
            unawaited(_maybeFlushPendingIncomingImage());
          },
        );
      }

      final reason = classifyStorageLock(
        hasStorageError: storage.hasStorageError,
        isBiometricLocked: storage.isBiometricLocked,
        biometricsSupported: widget.settings.biometricsSupported,
      );
      final String message;
      final String? detail;
      switch (reason) {
        case StorageLockReason.storageFailure:
          message = l10n.storageUnlockFailed;
          detail = storage.storageError;
        case StorageLockReason.biometricUnavailable:
          message = l10n.biometricsNotAvailable;
          detail = null;
        case StorageLockReason.biometricPrompt:
          message = l10n.biometricAuthFailed;
          detail = null;
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.appTitle),
          actions: [
            IconButton(
              tooltip: l10n.settingsLabel,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (c) => SettingsScreen(settings: widget.settings),
                ),
              ),
            ),
            IconButton(
              tooltip: l10n.debugLogging,
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogScreen()),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: SelectableText(
                      detail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    // capture localized messages before await to avoid context-after-async lint
                    final failedMsg = l10n.authenticationFailed;
                    final storageFailedMsg = l10n.storageUnlockFailed;
                    final ok = await storage.attemptUnlock();
                    if (ok) {
                      await widget.settings.reloadFromStorage();
                      await _serverManager.loadServers();
                      _serversLoaded = true;
                      if (mounted) setState(() {});
                      unawaited(_maybeFlushPendingIncomingImage());
                    } else {
                      // Rebuild so the message reflects the updated state (e.g.
                      // a newly recorded storage error).
                      if (mounted) setState(() {});
                      messenger.showSnackBar(SnackBar(
                        content: Text(storage.hasStorageError
                            ? storageFailedMsg
                            : failedMsg),
                      ));
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
                  alignment: Alignment.topCenter,
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
      floatingActionButton: !_manageMode.isManageMode && _serverManager.servers.isNotEmpty
          ? AnimatedSlide(
              offset: (_fabVisible || _serverManager.currentItems.isEmpty) ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: (_fabVisible || _serverManager.currentItems.isEmpty) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 56.0),
                  child: FloatingActionButton(
                onPressed: () async {
                  final srv = _serverManager.selectedServerId != null
                      ? _serverManager.servers.firstWhere(
                          (s) => s.id == _serverManager.selectedServerId,
                          orElse: () => _serverManager.servers.first)
                      : _serverManager.servers.first;
                  final acct = (srv.userEmail.isNotEmpty) ? srv.userEmail : 'no email';
                  final host = Uri.parse(srv.url).host;
                  final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (c) => NewCodeScreen(
                              userEmail: acct,
                              serverHost: host,
                              groups: srv.groups)));
                  if (result is AccountEntry) {
                    await _serverManager.insertCreatedAccount(result);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.accountUpdated)),
                      );
                    }
                    // Show the entry immediately (it is already persisted),
                    // then upload it in the background. The retry manager keeps
                    // trying if the server is unreachable right now.
                    unawaited(_syncManager.ensurePendingUploads());
                  }
                },
                backgroundColor: const Color(0xFF4F63E6),
                child: const Icon(Icons.qr_code, color: Colors.white),
              ),
                ),
              ),
            )
          : null,
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
              Expanded(
                child: HomeSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              _buildSyncButton(),
              // Manage button
              IconButton(
                tooltip: l10n.manage,
                icon: const Icon(Icons.edit_outlined),
                onPressed: _serverManager.servers.isNotEmpty ? _manageMode.toggleManageMode : null,
              ),
              // Popup menu with About entry
              PopupMenuButton<String>(
                tooltip: l10n.about,
                onSelected: (v) async {
                  if (v == 'about') {
                    _showAboutDialog();
                  } else if (v == 'settings') {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (c) => SettingsScreen(settings: widget.settings),
                      ),
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.settingsLabel),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'about',
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.about),
                      ],
                    ),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: Icon(Icons.more_vert),
                ),
              ),
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
        : Semantics(
          label: l10n.synchronize,
          button: true,
          child: IconButton(
            tooltip: l10n.synchronize,
            icon: const Icon(Icons.sync),
            onPressed: _serverManager.servers.isEmpty || _manageMode.isManageMode ? null : _syncManager.manualSyncPressed,
          )
        );
  }

  // Countdown helper removed

  void _showAboutDialog() {
    // NOTE: appVersion is kept in sync manually with pubspec.yaml's version: field.
    const appVersion = '0.11.0';

    showDialog<void>(
      context: context,
      builder: (c) => AboutDialogContent(appVersion: appVersion),
    );
  }

  Widget _buildGroupSelector(List<String> groups) {
    return _manageMode.isManageMode && _manageMode.selectedAccountIds.isNotEmpty
        ? Text(
            l10n.selectedCount(_manageMode.selectedAccountIds.length),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)));
                }),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down,
                    size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
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
      onReloadServers: _serverManager.loadServers,
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
      onNewAccount: _serverManager.addNewAccount,
    );
  }

  // _buildSyncOverlay removed: full-screen sync overlay is no longer used.
}
