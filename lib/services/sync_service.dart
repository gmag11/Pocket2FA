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
    // Guard against storage being locked (e.g. biometric auth cancelled).
    DateTime? last;
    try {
      if (storage.isUnlocked) {
        final box = storage.box;
        final lastRaw = box.get(key);
        if (lastRaw != null) {
          try {
            last = DateTime.parse(lastRaw as String);
          } catch (_) {}
        }
      }
    } on StateError catch (_) {
      // storage locked; act as if never synced
      last = null;
    }
  // Check whether the last sync was marked as forced. If it was forced we
  // ignore the throttle window for skipping (i.e. allow an automatic sync to
  // proceed even if the last recorded sync was a forced one).
  final forcedKey = '$_lastSyncForcedKeyPrefix${server.id}';
  bool wasLastForced = false;
  try {
    if (storage.isUnlocked) {
      final box = storage.box;
      final forcedRaw = box.get(forcedKey);
      wasLastForced = forcedRaw == true;
    }
  } on StateError catch (_) {
    wasLastForced = false;
  }

  // inlined function removed; implemented as a separate method below

    if (last != null && DateTime.now().difference(last) < _throttle) {
      if (wasLastForced) {
        // proceed despite throttle when last sync was forced
      } else {
        return {'skipped': true, 'success': true, 'downloaded': 0, 'failed': 0, 'message': 'Skipped (throttled)'};
      }
    }

    final res = await forceSync(server, storage, cancelToken: cancelToken, concurrency: concurrency);
    return res;
  }

  Future<Map<String, dynamic>> forceSync(ServerConnection server, SettingsStorage storage, {CancelToken? cancelToken, int concurrency = 4, bool markAsForced = false}) async {
  // Starting sync (kept minimal)

    developer.log('SyncService: forceSync START server=${server.id}', name: 'SyncService');

    // First, attempt to delete any pending deleted accounts (synchronized=false && deleted=true)
    try {
      developer.log('SyncService: calling _deletePendingAccounts for server=${server.id}', name: 'SyncService');
      await _deletePendingAccounts(server, storage, cancelToken: cancelToken);
      developer.log('SyncService: _deletePendingAccounts completed for server=${server.id}', name: 'SyncService');
    } catch (e) {
      developer.log('SyncService: _deletePendingAccounts failed: $e', name: 'SyncService');
    }

    // Then, upload pending new accounts
    try {
      developer.log('SyncService: calling _uploadPendingAccounts for server=${server.id}', name: 'SyncService');
      await _uploadPendingAccounts(server, storage, cancelToken: cancelToken);
      developer.log('SyncService: _uploadPendingAccounts completed for server=${server.id}', name: 'SyncService');
    } catch (e) {
      developer.log('SyncService: uploadPendingAccounts failed: $e', name: 'SyncService');
    }

    // Ensure ApiService is configured for this server so Authorization headers and base are correct
    ApiService.instance.setServer(server);

    // 1) GET /groups
    List<GroupEntry> groups = [];
    var groupsFetched = false;
    try {
      final resp = await ApiService.instance.dio.get('groups', cancelToken: cancelToken);
      if (resp.statusCode == 200 && resp.data is List) {
        final list = resp.data as List;
        groups = list.map((e) => GroupEntry.fromMap(Map<dynamic, dynamic>.from(e))).toList();
        groupsFetched = true;
      }
    } catch (e) {
      developer.log('SyncService: error fetching groups: $e', name: 'SyncService');
    }

    // 2) GET /twofaccounts
    List<AccountEntry> accounts = [];
    var accountsFetched = false;
    try {
      // Request accounts including secrets so we can generate OTPs locally
      final resp = await ApiService.instance.dio.get('twofaccounts', queryParameters: {'withSecret': 'true'}, cancelToken: cancelToken);
      if (resp.statusCode == 200 && resp.data is List) {
        final list = resp.data as List;
        accounts = list.map((e) => AccountEntry.fromMap(Map<dynamic, dynamic>.from(e))).toList();
        accountsFetched = true;
  // secrets are stored in AccountEntry.seed via AccountEntry.fromMap
      }
    } catch (e) {
      developer.log('SyncService: error fetching accounts: $e', name: 'SyncService');
    }

    // If there are locally marked deleted but unsynchronized entries, ensure
    // they are not re-introduced by the freshly fetched server list. We
    // remove any fetched account that matches a locally pending delete id so
    // the entry remains deleted locally until the server-side delete succeeds.
    if (accountsFetched) {
      try {
        if (storage.isUnlocked) {
          final rawStored = storage.box.get('servers');
          if (rawStored != null) {
            final storedList = (rawStored as List<dynamic>).map((e) => Map<dynamic, dynamic>.from(e)).toList();
            final storedIdx = storedList.indexWhere((e) => e['id'] == server.id);
            if (storedIdx != -1) {
              final localServer = ServerConnection.fromMap(storedList[storedIdx]);
              final pendingDeleteIds = localServer.accounts
                  .where((a) => a.deleted == true && a.synchronized == false && a.id > 0)
                  .map((a) => a.id)
                  .toSet();
              if (pendingDeleteIds.isNotEmpty) {
                final before = accounts.length;
                accounts.removeWhere((a) => pendingDeleteIds.contains(a.id));
                final removed = before - accounts.length;
                developer.log('SyncService: filtered out $removed fetched accounts that are pending local delete (ids=${pendingDeleteIds.toList()})', name: 'SyncService');
              }
            }
          }
        }
      } catch (e) {
        developer.log('SyncService: could not apply pending-delete filter: $e', name: 'SyncService');
      }
    }

    // If groups were fetched, map account.groupId -> group.name so UI can filter
    if (groups.isNotEmpty && accounts.isNotEmpty) {
      final Map<int, String> gidToName = { for (var g in groups) g.id : g.name };
      for (var i = 0; i < accounts.length; i++) {
        final acc = accounts[i];
        if ((acc.group.isEmpty) && acc.groupId != null) {
          final name = gidToName[acc.groupId!] ?? '';
          if (name.isNotEmpty) {
            accounts[i] = acc.copyWith(group: name);
          }
        }
      }
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
          final f = await IconCacheService.instance.getIconFile(server, acc.icon!);
          final exists = await f.exists();
          if (exists) {
            // Already cached, just set the local path
            accounts[idx] = acc.copyWith(localIcon: f.path);
            skipped++;
            return;
          }

          // Not present yet: download and persist
          await IconCacheService.instance.getIconBytes(server, acc.icon!, cancelToken: cancelToken);
          final f2 = await IconCacheService.instance.getIconFile(server, acc.icon!);
          accounts[idx] = acc.copyWith(localIcon: f2.path);
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
        if (cancelToken != null && cancelToken.isCancelled) break;
      }
    }

    // If we couldn't fetch either groups or accounts, treat this as a network failure
    // and avoid overwriting persisted cached data.
    final anyFetched = groupsFetched || accountsFetched;
    if (!anyFetched) {
      developer.log('SyncService: network failure - no groups or accounts fetched for ${server.id}', name: 'SyncService');
      return {
        'skipped': false,
        'success': false,
        'downloaded': downloaded,
        'failed': failed,
        'skipped_count': skipped,
        'network_failed': true,
        'message': 'Network failure - no data fetched'
      };
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

  Future<void> _uploadPendingAccounts(ServerConnection server, SettingsStorage storage, {CancelToken? cancelToken}) async {
    // Ensure storage is available and unlocked
    try {
      if (!storage.isUnlocked) return;
    } on StateError catch (_) {
      return;
    }

    final box = storage.box;
    final raw = box.get('servers');
    if (raw == null) return;
    final list = (raw as List<dynamic>).map((e) => Map<dynamic, dynamic>.from(e)).toList();
    final idx = list.indexWhere((e) => e['id'] == server.id);
    if (idx == -1) return;

    // Deserialize server so we can inspect accounts
    final localServer = ServerConnection.fromMap(list[idx]);
    final pending = <int>[];
    for (var i = 0; i < localServer.accounts.length; i++) {
      final a = localServer.accounts[i];
      if (a.id == -1 && a.synchronized == false) pending.add(i);
    }
    developer.log('SyncService._uploadPendingAccounts: found ${pending.length} pending accounts for server=${server.id}', name: 'SyncService');
    if (pending.isEmpty) {
      developer.log('SyncService._uploadPendingAccounts: no pending accounts to upload for server=${server.id}', name: 'SyncService');
      return;
    }

    // Configure ApiService for this server
    ApiService.instance.setServer(server);

      for (final accIdx in pending) {
        final acc = localServer.accounts[accIdx];
        developer.log('SyncService._uploadPendingAccounts: attempting upload for local acc index=$accIdx service=${acc.service} account=${acc.account} groupId=${acc.groupId}', name: 'SyncService');
        try {
          final resp = await ApiService.instance.createAccountFromEntry(acc, groupId: acc.groupId, cancelToken: cancelToken);
        // resp is expected to be a Map representing the created resource
        if (resp.containsKey('id')) {
      developer.log('SyncService._uploadPendingAccounts: server created account id=${resp['id']} for local index=$accIdx', name: 'SyncService');
          // Build a new AccountEntry from response and mark synchronized
          var created = AccountEntry.fromMap(Map<dynamic, dynamic>.from(resp)).copyWith(synchronized: true);
          // If server returned only group_id and not the group name, try to
          // populate the group name from the local server.groups so UI updates
          // immediately without requiring a subsequent full sync.
          try {
            final groups = localServer.groups;
            if ((created.group.isEmpty || created.group.trim().isEmpty) && created.groupId != null && groups != null && groups.isNotEmpty) {
              GroupEntry? match;
              try {
                match = groups.firstWhere((g) => g.id == created.groupId);
              } catch (_) {
                match = null;
              }
              if (match != null) created = created.copyWith(group: match.name);
            }
          } catch (_) {}
          // replace in localServer.accounts
          final updatedAccounts = List<AccountEntry>.from(localServer.accounts);
          updatedAccounts[accIdx] = created;
          final updatedServer = ServerConnection(
            id: localServer.id,
            name: localServer.name,
            url: localServer.url,
            apiKey: localServer.apiKey,
            accounts: updatedAccounts,
            groups: localServer.groups,
            userId: localServer.userId,
            userName: localServer.userName,
            userEmail: localServer.userEmail,
            oauthProvider: localServer.oauthProvider,
            authenticatedByProxy: localServer.authenticatedByProxy,
            preferences: localServer.preferences,
            isAdmin: localServer.isAdmin,
          );
          // Persist updated server in list
          list[idx] = updatedServer.toMap();
          await box.put('servers', list);
          developer.log('SyncService._uploadPendingAccounts: persisted updated servers after uploading account index=$accIdx', name: 'SyncService');
          // Update localServer reference for subsequent iterations
          // (ServerConnection.accounts is final so replace localServer entirely)
          // Recreate localServer from the updated map for safety
          // local persisted data updated; continue to next pending account
        } else {
          developer.log('SyncService._uploadPendingAccounts: server response missing id: $resp', name: 'SyncService');
        }
      } catch (e) {
        // If the exception is a DioException, try to log response data
        try {
          if (e is DioException) {
            developer.log('SyncService._uploadPendingAccounts: DioException status=${e.response?.statusCode} data=${e.response?.data}', name: 'SyncService');
          }
        } catch (_) {}
        developer.log('SyncService._uploadPendingAccounts: failed to create account ${acc.service}/${acc.account}: $e', name: 'SyncService');
        // continue with next pending account
      }
    }
  }

  Future<void> _deletePendingAccounts(ServerConnection server, SettingsStorage storage, {CancelToken? cancelToken}) async {
    // Ensure storage is available and unlocked
    try {
      if (!storage.isUnlocked) return;
    } on StateError catch (_) {
      return;
    }

    final box = storage.box;
    final raw = box.get('servers');
    if (raw == null) return;
    final list = (raw as List<dynamic>).map((e) => Map<dynamic, dynamic>.from(e)).toList();
    final idx = list.indexWhere((e) => e['id'] == server.id);
    if (idx == -1) return;

    // Deserialize server
    final localServer = ServerConnection.fromMap(list[idx]);
    final pendingDelete = <AccountEntry>[];
    for (final acc in localServer.accounts) {
      if (!acc.synchronized && acc.deleted) {
        pendingDelete.add(acc);
      }
    }
    developer.log('SyncService._deletePendingAccounts: found ${pendingDelete.length} pending deletes for server=${server.id}', name: 'SyncService');
    if (pendingDelete.isEmpty) return;

    // Configure ApiService
    ApiService.instance.setServer(server);

    // Collect IDs for mass delete
    final deleteIds = pendingDelete.map((a) => a.id).where((id) => id > 0).toList(); // Only if has server ID
    if (deleteIds.isNotEmpty) {
      try {
        await ApiService.instance.deleteAccounts(deleteIds);
        // Success: remove from local accounts
        final keptAccounts = localServer.accounts.where((a) => !pendingDelete.contains(a)).toList();
        final updatedServer = ServerConnection(
          id: localServer.id,
          name: localServer.name,
          url: localServer.url,
          apiKey: localServer.apiKey,
          accounts: keptAccounts,
          groups: localServer.groups,
          userId: localServer.userId,
          userName: localServer.userName,
          userEmail: localServer.userEmail,
          oauthProvider: localServer.oauthProvider,
          authenticatedByProxy: localServer.authenticatedByProxy,
          preferences: localServer.preferences,
          isAdmin: localServer.isAdmin,
        );
        list[idx] = updatedServer.toMap();
        await box.put('servers', list);
        developer.log('SyncService._deletePendingAccounts: removed ${deleteIds.length} pending deletes', name: 'SyncService');
      } catch (e) {
        // Silent fail: log, leave marked for next sync
        developer.log('SyncService._deletePendingAccounts: API delete failed (retry next sync): $e', name: 'SyncService');
      }
    }
  }
}
