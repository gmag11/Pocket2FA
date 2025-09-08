import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/sync_service.dart';
import '../models/server_connection.dart';
import 'home_server_manager.dart';

class HomeSyncManager extends ChangeNotifier {
  final HomeServerManager serverManager;
  
  bool _isSyncing = false;
  bool _suppressNextSyncSnack = false;
  bool _suppressFullScreenSyncIndicator = false;
  bool _skipSyncOnLoad = false;

  HomeSyncManager(this.serverManager);

  // Getters
  bool get isSyncing => _isSyncing;
  bool get suppressFullScreenSyncIndicator => _suppressFullScreenSyncIndicator;

  void setSyncing(bool syncing) {
    if (_isSyncing != syncing) {
      _isSyncing = syncing;
      notifyListeners();
    }
  }

  void setSuppressFullScreenSyncIndicator(bool suppress) {
    _suppressFullScreenSyncIndicator = suppress;
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
    
    final srv = servers.firstWhere(
      (s) => s.id == selectedServerId, 
      orElse: () => servers.first
    );
    
    try {
      if (!_suppressFullScreenSyncIndicator) {
        setSyncing(true);
      }
      
      final result = await SyncService.instance.forceSync(srv, storage, markAsForced: true);
      
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
        developer.log('HomeSyncManager: cannot sync (network failure) for server ${srv.id}', name: 'HomeSyncManager');
        _suppressNextSyncSnack = false;
      } else {
        if (!_suppressNextSyncSnack) {
          // Only log when an actual network sync ran (not when skipped)
          if (result['skipped'] != true) {
            developer.log('HomeSyncManager: sync finished for server ${srv.id}', name: 'HomeSyncManager');
          }
        } else {
          _suppressNextSyncSnack = false;
        }
      }
    } catch (e) {
      serverManager.updateServerReachability(false);
      developer.log('HomeSyncManager: forceSync failed: $e', name: 'HomeSyncManager');
    } finally {
      setSyncing(false);
    }
  }

  Future<void> performThrottledSync() async {
    final storage = serverManager.settings.storage;
    final servers = serverManager.servers;
    final selectedServerId = serverManager.selectedServerId;
    
    if (selectedServerId == null || storage == null || servers.isEmpty) return;
    
    final srv = servers.firstWhere(
      (s) => s.id == selectedServerId, 
      orElse: () => servers.first
    );
    
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
        developer.log('HomeSyncManager: skipping syncIfNeeded because a recent forced sync ran', name: 'HomeSyncManager');
        result = {'skipped': true, 'success': true, 'downloaded': 0, 'failed': 0};
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
                .map((e) => ServerConnection.fromMap(Map<dynamic, dynamic>.from(e)))
                .toList();
            serverManager.updateServersInMemory(servers2);
          }
        }
      } on StateError catch (_) {
        // storage locked while refreshing; ignore and keep current display
      }
      
      if (result['network_failed'] == true) {
        serverManager.updateServerReachability(false);
        developer.log('HomeSyncManager: cannot sync (network failure) for server ${srv.id}', name: 'HomeSyncManager');
        _suppressNextSyncSnack = false;
      } else {
        if (!_suppressNextSyncSnack) {
          // Only log when an actual network sync ran
          if (result['skipped'] != true) {
            developer.log('HomeSyncManager: sync finished for server ${srv.id}', name: 'HomeSyncManager');
          }
        } else {
          // consume the suppression flag once
          _suppressNextSyncSnack = false;
        }
      }
    } catch (e) {
      // If a sync error occurred (for example offline or server unreachable),
      // inform the user but keep showing cached data. Also mark unreachable.
      serverManager.updateServerReachability(false);
      if (!_suppressNextSyncSnack) {
        rethrow; // Re-throw to let the caller handle the snackbar
      } else {
        _suppressNextSyncSnack = false;
      }
    } finally {
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
}
