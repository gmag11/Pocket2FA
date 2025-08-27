import 'dart:developer' as developer;
import 'package:dio/dio.dart';
// sync_service handles fetching remote groups/accounts and caching icons.
import '../models/server_connection.dart';
import '../models/account_entry.dart';
import '../models/group_entry.dart';
import 'api_service.dart';
import 'icon_cache_service.dart';
import 'settings_storage.dart';

class SyncService {
  SyncService._internal();
  static final SyncService instance = SyncService._internal();

  static const Duration _throttle = Duration(minutes: 15);
  static const _lastSyncKeyPrefix = 'last_sync_';

  /// Returns a summary map:
  /// {
  ///   'skipped': bool,
  ///   'success': bool,
  ///   'downloaded': int,
  ///   'failed': int,
  ///   'message': String?
  /// }
  Future<Map<String, dynamic>> syncIfNeeded(ServerConnection server, SettingsStorage storage, {CancelToken? cancelToken, int concurrency = 4}) async {
    final key = '$_lastSyncKeyPrefix${server.id}';
    final box = storage.box;
    final lastRaw = box.get(key);
    DateTime? last;
    if (lastRaw != null) {
      try {
        last = DateTime.parse(lastRaw as String);
      } catch (_) {}
    }

    if (last != null && DateTime.now().difference(last) < _throttle) {
      developer.log('SyncService: skipping sync for ${server.id}, last=${last.toIso8601String()}', name: 'SyncService');
      return {'skipped': true, 'success': true, 'downloaded': 0, 'failed': 0, 'message': 'Skipped (throttled)'};
    }

    final res = await forceSync(server, storage, cancelToken: cancelToken, concurrency: concurrency);
    return res;
  }

  Future<Map<String, dynamic>> forceSync(ServerConnection server, SettingsStorage storage, {CancelToken? cancelToken, int concurrency = 4}) async {
    developer.log('SyncService: starting sync for ${server.id}', name: 'SyncService');

    // Ensure ApiService is configured for this server so Authorization headers and base are correct
    ApiService.instance.setServer(server);

    // 1) GET /groups
    List<GroupEntry> groups = [];
    try {
      final resp = await ApiService.instance.dio.get('groups', cancelToken: cancelToken);
      if (resp.statusCode == 200 && resp.data is List) {
        final list = resp.data as List;
        developer.log('SyncService: groups response status=${resp.statusCode}, count=${list.length}', name: 'SyncService');
        groups = list.map((e) => GroupEntry.fromMap(Map<dynamic, dynamic>.from(e))).toList();
      } else {
        developer.log('SyncService: groups response status=${resp.statusCode}, type=${resp.data.runtimeType}', name: 'SyncService');
      }
    } catch (e) {
      developer.log('SyncService: error fetching groups: $e', name: 'SyncService');
    }

    // 2) GET /twofaccounts
    List<AccountEntry> accounts = [];
    try {
      final resp = await ApiService.instance.dio.get('twofaccounts', cancelToken: cancelToken);
      if (resp.statusCode == 200 && resp.data is List) {
        final list = resp.data as List;
        developer.log('SyncService: twofaccounts response status=${resp.statusCode}, count=${list.length}', name: 'SyncService');
        accounts = list.map((e) => AccountEntry.fromMap(Map<dynamic, dynamic>.from(e))).toList();
      } else {
        developer.log('SyncService: twofaccounts response status=${resp.statusCode}, type=${resp.data.runtimeType}', name: 'SyncService');
      }
    } catch (e) {
      developer.log('SyncService: error fetching accounts: $e', name: 'SyncService');
    }

    // 3) download icons for each account that has icon field, in parallel batches
    int downloaded = 0;
    int failed = 0;
    final iconEntries = <int>[];
    for (var i = 0; i < accounts.length; i++) {
      final acc = accounts[i];
      if (acc.icon != null && acc.icon!.isNotEmpty) iconEntries.add(i);
    }

    // process in batches of `concurrency`
    for (var start = 0; start < iconEntries.length; start += concurrency) {
      if (cancelToken != null && cancelToken.isCancelled) {
        developer.log('SyncService: cancelled during icon download', name: 'SyncService');
        break;
      }
      final end = (start + concurrency).clamp(0, iconEntries.length);
      final batch = iconEntries.sublist(start, end);
      final futures = batch.map((idx) async {
        final acc = accounts[idx];
          try {
          await IconCacheService.instance.getIconBytes(server, acc.icon!, cancelToken: cancelToken);
          final f = await IconCacheService.instance.getIconFile(server, acc.icon!);
          accounts[idx] = acc.copyWith(localIcon: f.path);
          downloaded++;
        } catch (e) {
          failed++;
          developer.log('SyncService: failed to cache icon for ${acc.id}: $e', name: 'SyncService');
        }
      }).toList();

      try {
        await Future.wait(futures);
      } catch (e) {
        // Individual failures are already counted; a cancellation may throw here
        developer.log('SyncService: batch error: $e', name: 'SyncService');
        if (cancelToken != null && cancelToken.isCancelled) break;
      }
    }

    // Update server object with groups and accounts and persist to storage
    final updated = ServerConnection(
      id: server.id,
      name: server.name,
      url: server.url,
      apiKey: server.apiKey,
      accounts: accounts,
      groups: groups,
      userId: server.userId,
      userName: server.userName,
      userEmail: server.userEmail,
      oauthProvider: server.oauthProvider,
      authenticatedByProxy: server.authenticatedByProxy,
      preferences: server.preferences,
      isAdmin: server.isAdmin,
    );

  try {
      // Replace the server entry in persisted storage
      final box = storage.box;
      final raw = box.get('servers');
      if (raw != null) {
        final list = (raw as List<dynamic>).map((e) => Map<dynamic, dynamic>.from(e)).toList();
        final idx = list.indexWhere((e) => e['id'] == server.id);
        if (idx != -1) {
          list[idx] = updated.toMap();
        } else {
          list.add(updated.toMap());
        }
        await box.put('servers', list);
      } else {
        await box.put('servers', [updated.toMap()]);
      }
      // record last sync time
      await box.put('$_lastSyncKeyPrefix${server.id}', DateTime.now().toIso8601String());
    } catch (e) {
      developer.log('SyncService: failed to persist servers: $e', name: 'SyncService');
    }

    developer.log('SyncService: sync completed for ${server.id} (downloaded=$downloaded failed=$failed)', name: 'SyncService');
    return {'skipped': false, 'success': failed == 0, 'downloaded': downloaded, 'failed': failed, 'message': (failed == 0 ? 'Sync completed' : 'Sync completed with failures')};
  }
}
