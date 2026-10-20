import 'dart:async';

import 'package:flutter/material.dart';
import '../services/log_service.dart';
import '../services/sync_service.dart';
import '../models/server_connection.dart';
import 'home_server_manager.dart';

class HomeSyncManager extends ChangeNotifier {
  final HomeServerManager serverManager;

  bool _isSyncing = false;
  bool _suppressNextSyncSnack = false;
  bool _suppressFullScreenSyncIndicator = false;
  bool _skipSyncOnLoad = false;

  static const List<Duration> _pendingRetryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  Timer? _pendingRetryTimer;
  int _pendingRetryAttempt = 0;
  bool _retryPaused = false;
  bool _isUploadingPending = false;
  bool _syncInProgress = false;
  bool _disposed = false;

  HomeSyncManager(this.serverManager);

  // Getters
  bool get isSyncing => _isSyncing;
  bool get suppressFullScreenSyncIndicator => _suppressFullScreenSyncIndicator;

  /// Whether the selected server has accounts that have not reached the server.
  bool get hasPendingUploads {
    final server = _currentServer();
    if (server == null) return false;
    return server.accounts.any((a) =>
        a.id <= 0 && !a.synchronized && !a.deleted && !a.isBorrowed);
  }

  ServerConnection? _currentServer() {
    final servers = serverManager.servers;
    if (servers.isEmpty) return null;
    final selectedId = serverManager.selectedServerId;
    return servers.firstWhere((s) => s.id == selectedId,
        orElse: () => servers.first);
  }

  void setSyncing(bool syncing) {
    if (_isSyncing != syncing) {
      _isSyncing = syncing;
      notifyListeners();
    }
  }

  void setSuppressFullScreenSyncIndicator(bool suppress) {
    _suppressFullScreenSyncIndicator = suppress;
  }

  /// Pause automatic pending-upload retries while manage mode is active, so a
  /// retry cannot replace an entry the user is selecting or deleting.
  void setRetryPaused(bool paused) {
    if (_retryPaused == paused) return;
    _retryPaused = paused;
    if (paused) {
      _cancelPendingRetry();
    } else if (hasPendingUploads) {
      _pendingRetryAttempt = 0;
      _schedulePendingRetry();
    }
  }

  /// Attempt to upload pending accounts now (if any), then keep retrying with
  /// bounded backoff until none remain. This does not fetch the account list.
  Future<void> ensurePendingUploads({bool immediate = true}) async {
    if (_disposed || _retryPaused) return;
    if (!hasPendingUploads) {
      _stopPendingRetries();
      return;
    }
    if (immediate) {
      await _attemptPendingUploads();
    } else {
      _schedulePendingRetry();
    }
  }

  Future<void> _attemptPendingUploads() async {
    if (_disposed || _retryPaused || _isUploadingPending) return;
    if (!hasPendingUploads) {
      _stopPendingRetries();
      return;
    }
    if (_syncInProgress || _isSyncing) {
      _schedulePendingRetry();
      return;
    }

    final storage = serverManager.settings.storage;
    final server = _currentServer();
    if (storage == null || server == null) {
      _stopPendingRetries();
      return;
    }

    _isUploadingPending = true;
    try {
      final uploaded = await SyncService.instance
          .uploadPendingAccounts(server, storage);
      if (_disposed) return;
      if (uploaded > 0) {
        serverManager.updateServerReachability(true);
        await serverManager.loadServers();
        if (_disposed) return;
      }
      if (!hasPendingUploads) {
        _stopPendingRetries();
      } else {
        _schedulePendingRetry();
      }
    } catch (e) {
      if (_disposed) return;
      serverManager.updateServerReachability(false);
      LogService.instance.log(
          'HomeSyncManager: pending upload retry failed: $e',
          name: 'HomeSyncManager');
      _schedulePendingRetry();
    } finally {
      _isUploadingPending = false;
    }
  }

  void _schedulePendingRetry() {
    if (_disposed) return;
    if (_retryPaused || !hasPendingUploads) {
      _stopPendingRetries();
      return;
    }
    _pendingRetryTimer?.cancel();
    final index = _pendingRetryAttempt < _pendingRetryDelays.length
        ? _pendingRetryAttempt
        : _pendingRetryDelays.length - 1;
    final delay = _pendingRetryDelays[index];
    _pendingRetryAttempt++;
    LogService.instance.log(
        'HomeSyncManager: retrying pending uploads in ${delay.inSeconds}s '
        '(attempt=$_pendingRetryAttempt)',
        name: 'HomeSyncManager');
    _pendingRetryTimer = Timer(delay, () {
      _pendingRetryTimer = null;
      _attemptPendingUploads();
    });
  }

  void _cancelPendingRetry() {
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = null;
  }

  void _stopPendingRetries() {
    _cancelPendingRetry();
    _pendingRetryAttempt = 0;
  }

  void _rescheduleAfterSync() {
    if (hasPendingUploads && !_retryPaused) {
      _pendingRetryAttempt = 0;
      _schedulePendingRetry();
    } else {
      _stopPendingRetries();
    }
  }

  Future<void> onRefreshFromPull() async {
    // Called by RefreshIndicator's onRefresh. Suppress the fullscreen overlay
    // because RefreshIndicator already shows a spinner.
    _suppressFullScreenSyncIndicator = true;
    try {
      await forceSyncCurrentServer();
    } finally {
      _suppressFullScreenSyncIndicator = false;
    }
  }

  Future<void> forceSyncCurrentServer() async {
    final storage = serverManager.settings.storage;
    final servers = serverManager.servers;
    final selectedServerId = serverManager.selectedServerId;

    if (selectedServerId == null || storage == null || servers.isEmpty) return;

    final srv = servers.firstWhere((s) => s.id == selectedServerId,
        orElse: () => servers.first);

    _syncInProgress = true;
    _cancelPendingRetry();
    try {
      if (!_suppressFullScreenSyncIndicator) {
        setSyncing(true);
      }

      final result = await SyncService.instance
          .forceSync(srv, storage, markAsForced: true);

      // Force sync attempted network operations; success means server reachable
      serverManager.updateServerReachability(true);

      // After forcing sync, reload servers but suppress the automatic sync snackbar
      _suppressNextSyncSnack = true;

      // Prevent the subsequent loadServers() call from triggering a second network
      // syncIfNeeded immediately after a forced sync. This avoids double network
      // requests when the UI reloads servers right after forcing a sync.
      _skipSyncOnLoad = true;

      await serverManager.loadServers();

      if (result['network_failed'] == true) {
        serverManager.updateServerReachability(false);
        LogService.instance.log(
            'HomeSyncManager: cannot sync (network failure) for server ${srv.id}',
            name: 'HomeSyncManager');
        _suppressNextSyncSnack = false;
      } else {
        if (!_suppressNextSyncSnack) {
          // Only log when an actual network sync ran (not when skipped)
          if (result['skipped'] != true) {
            LogService.instance.log('HomeSyncManager: sync finished for server ${srv.id}',
                name: 'HomeSyncManager');
          }
        } else {
          _suppressNextSyncSnack = false;
        }
      }
      _rescheduleAfterSync();
    } catch (e) {
      serverManager.updateServerReachability(false);
      LogService.instance.log('HomeSyncManager: forceSync failed: $e',
          name: 'HomeSyncManager');
      _rescheduleAfterSync();
    } finally {
      _syncInProgress = false;
      setSyncing(false);
    }
  }

  Future<void> performThrottledSync() async {
    final storage = serverManager.settings.storage;
    final servers = serverManager.servers;
    final selectedServerId = serverManager.selectedServerId;

    if (selectedServerId == null || storage == null || servers.isEmpty) return;

    final srv = servers.firstWhere((s) => s.id == selectedServerId,
        orElse: () => servers.first);

    _syncInProgress = true;
    _cancelPendingRetry();
    try {
      // Do not show the fullscreen sync overlay when a pull-to-refresh
      // is active; the RefreshIndicator already shows a spinner.
      if (!_suppressFullScreenSyncIndicator) {
        setSyncing(true);
      }

      Map<String, dynamic> result;
      if (_skipSyncOnLoad) {
        // consume the flag and skip the automatic throttled sync because
        // a forceSync just ran and already refreshed server state.
        _skipSyncOnLoad = false;
        LogService.instance.log(
            'HomeSyncManager: skipping syncIfNeeded because a recent forced sync ran',
            name: 'HomeSyncManager');
        result = {
          'skipped': true,
          'success': true,
          'downloaded': 0,
          'failed': 0
        };
      } else {
        result = await SyncService.instance.syncIfNeeded(srv, storage);
      }

      // If syncIfNeeded actually performed a network sync, it will not set
      // 'skipped' to true. Only update reachability state when a network
      // attempt occurred and succeeded.
      if (result['skipped'] != true) {
        serverManager.updateServerReachability(true);
      }

      // Reload servers from storage to pick up any updates (icons/local paths)
      try {
        if (storage.isUnlocked) {
          final raw2 = storage.box.get('servers');
          if (raw2 != null) {
            final servers2 = (raw2 as List<dynamic>)
                .map((e) =>
                    ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
                .toList();
            serverManager.updateServersInMemory(servers2);
          }
        }
      } on StateError catch (_) {
        // storage locked while refreshing; ignore and keep current display
      }

      if (result['network_failed'] == true) {
        serverManager.updateServerReachability(false);
        LogService.instance.log(
            'HomeSyncManager: cannot sync (network failure) for server ${srv.id}',
            name: 'HomeSyncManager');
        _suppressNextSyncSnack = false;
      } else {
        if (!_suppressNextSyncSnack) {
          // Only log when an actual network sync ran
          if (result['skipped'] != true) {
            LogService.instance.log('HomeSyncManager: sync finished for server ${srv.id}',
                name: 'HomeSyncManager');
          }
        } else {
          // consume the suppression flag once
          _suppressNextSyncSnack = false;
        }
      }
      _rescheduleAfterSync();
    } catch (e) {
      // If a sync error occurred (for example offline or server unreachable),
      // inform the user but keep showing cached data. Also mark unreachable.
      serverManager.updateServerReachability(false);
      _rescheduleAfterSync();
      if (!_suppressNextSyncSnack) {
        rethrow; // Re-throw to let the caller handle the snackbar
      } else {
        _suppressNextSyncSnack = false;
      }
    } finally {
      _syncInProgress = false;
      // Only clear the fullscreen overlay if we actually showed it here.
      if (!_suppressFullScreenSyncIndicator) {
        setSyncing(false);
      }
    }
  }

  Future<void> manualSyncPressed() async {
    // Suppress the fullscreen overlay for manual sync; show only the
    // small spinner in the sync button.
    setSuppressFullScreenSyncIndicator(true);
    setSyncing(true);

    try {
      await onRefreshFromPull();
    } finally {
      setSyncing(false);
      setSuppressFullScreenSyncIndicator(false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopPendingRetries();
    super.dispose();
  }
}
