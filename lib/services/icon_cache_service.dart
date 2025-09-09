import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/server_connection.dart';

class IconCacheService {
  IconCacheService._internal();
  static final IconCacheService instance = IconCacheService._internal();

  // Timeouts for icon downloads
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  String _trimTrailingSlash(String url) {
    if (url.isEmpty) return url;
    var out = url;
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// Returns the persistent bytes for [fileName] belonging to [server]. If
  /// the file is not present locally it will be downloaded and stored.
  Future<Uint8List> getIconBytes(ServerConnection server, String fileName,
      {CancelToken? cancelToken}) async {
    final dir = await getApplicationSupportDirectory();
    final safeServer = server.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = '${dir.path}/icons';
    final file = File('$filePath/${safeServer}__$safeName');

    try {
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      developer.log('IconCache: read error $e', name: 'IconCacheService');
    }

    try {
      await Directory(filePath).create(recursive: true);
    } catch (_) {}

    final bytes =
        await _downloadIcon(server, fileName, cancelToken: cancelToken);

    try {
      await file.writeAsBytes(bytes, flush: true);
    } catch (e) {
      developer.log('IconCache: write error $e', name: 'IconCacheService');
    }

    return bytes;
  }

  /// Returns the expected local file path for a cached icon (does not guarantee it exists).
  Future<File> getIconFile(ServerConnection server, String fileName) async {
    final dir = await getApplicationSupportDirectory();
    final safeServer = server.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final filePath = '${dir.path}/icons';
    return File('$filePath/${safeServer}__$safeName');
  }

  Future<void> evict(ServerConnection server, String fileName) async {
    final dir = await getApplicationSupportDirectory();
    final safeServer = server.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${dir.path}/icons/${safeServer}__$safeName');
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    final dir = await getApplicationSupportDirectory();
    final base = Directory('${dir.path}/icons');
    try {
      if (await base.exists()) await base.delete(recursive: true);
    } catch (_) {}
  }

  Future<Uint8List> _downloadIcon(ServerConnection server, String fileName,
      {CancelToken? cancelToken}) async {
    final trimmed = _trimTrailingSlash(server.url);
    final encoded = Uri.encodeComponent(fileName);
    final url = '$trimmed/storage/icons/$encoded';

    final opts = BaseOptions(
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      responseType: ResponseType.bytes,
      headers: {
        'Accept': 'application/octet-stream',
        if (server.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${server.apiKey}',
      },
    );

    final dio = Dio(opts);
    final resp = await dio.get<List<int>>(url, cancelToken: cancelToken);
    if (resp.statusCode == 200 && resp.data != null) {
      return Uint8List.fromList(List<int>.from(resp.data!));
    }

    throw StateError(
        'Unexpected response downloading icon: ${resp.statusCode}');
  }
}
