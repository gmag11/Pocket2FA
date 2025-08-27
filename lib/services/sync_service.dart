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
  static const _lastSyncForcedKeyPrefix = 'last_sync_forced_';

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

  // Check whether the last sync was marked as forced. If it was forced we
  // ignore the throttle window for skipping (i.e. allow an automatic sync to
  // proceed even if the last recorded sync was a forced one).
  final forcedKey = '$_lastSyncForcedKeyPrefix${server.id}';
  final forcedRaw = box.get(forcedKey);
  final bool wasLastForced = forcedRaw == true;

    if (last != null && DateTime.now().difference(last) < _throttle) {
      if (wasLastForced) {
        developer.log('SyncService: last sync for ${server.id} was forced; ignoring throttle and proceeding', name: 'SyncService');
      } else {
        developer.log('SyncService: skipping sync for ${server.id}, last=${last.toIso8601String()}', name: 'SyncService');
        return {'skipped': true, 'success': true, 'downloaded': 0, 'failed': 0, 'message': 'Skipped (throttled)'};
      }
    }

    final res = await forceSync(server, storage, cancelToken: cancelToken, concurrency: concurrency);
    return res;
  }

  Future<Map<String, dynamic>> forceSync(ServerConnection server, SettingsStorage storage, {CancelToken? cancelToken, int concurrency = 4, bool markAsForced = false}) async {
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
        developer.log('SyncService: parsed groups=${groups.map((g) => g.toString()).toList()}', name: 'SyncService');
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

    // If groups were fetched, map account.groupId -> group.name so UI can filter
    if (groups.isNotEmpty && accounts.isNotEmpty) {
      final Map<int, String> gidToName = { for (var g in groups) g.id : g.name };
      developer.log('SyncService: group id->name mapping=${gidToName.toString()}', name: 'SyncService');
      for (var i = 0; i < accounts.length; i++) {
        final acc = accounts[i];
        if ((acc.group.isEmpty) && acc.groupId != null) {
          final name = gidToName[acc.groupId!] ?? '';
          if (name.isNotEmpty) {
            accounts[i] = acc.copyWith(group: name);
          }
        }
      }
      developer.log('SyncService: accounts after group mapping sample=${accounts.take(10).map((a) => {'id': a.id, 'group': a.group}).toList()}', name: 'SyncService');
    }

    // 3) download icons for each account that has icon field, in parallel batches
  int downloaded = 0;
  int failed = 0;
  int skipped = 0;
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
          developer.log('SyncService: checking icon for account=${acc.id} file=${acc.icon}', name: 'SyncService');
          final f = await IconCacheService.instance.getIconFile(server, acc.icon!);
          final exists = await f.exists();
          if (exists) {
            developer.log('SyncService: icon already cached for account=${acc.id} path=${f.path}', name: 'SyncService');
            // Already cached, just set the local path
            accounts[idx] = acc.copyWith(localIcon: f.path);
            skipped++;
            return;
          }

          // Not present yet: download and persist
          developer.log('SyncService: downloading icon for account=${acc.id} file=${acc.icon}', name: 'SyncService');
          await IconCacheService.instance.getIconBytes(server, acc.icon!, cancelToken: cancelToken);
          final f2 = await IconCacheService.instance.getIconFile(server, acc.icon!);
          accounts[idx] = acc.copyWith(localIcon: f2.path);
          developer.log('SyncService: icon downloaded for account=${acc.id} saved=${f2.path}', name: 'SyncService');
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
  // record last sync time and whether it was forced
  await box.put('$_lastSyncKeyPrefix${server.id}', DateTime.now().toIso8601String());
  await box.put('$_lastSyncForcedKeyPrefix${server.id}', markAsForced == true);
    } catch (e) {
      developer.log('SyncService: failed to persist servers: $e', name: 'SyncService');
    }

    developer.log('SyncService: sync completed for ${server.id} (downloaded=$downloaded failed=$failed skipped=$skipped)', name: 'SyncService');
    return {
      'skipped': false,
      'success': failed == 0,
      'downloaded': downloaded,
      'failed': failed,
      'skipped_count': skipped,
      'message': (failed == 0 ? 'Sync completed' : 'Sync completed with failures')
    };
  }
}
