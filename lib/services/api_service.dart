import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../models/server_connection.dart';

/// Servicio centralizado para llamadas a la API de 2fauth.
///
  /// - Mantiene una única instancia activa de `Dio`.
  /// - Use `setServer` para configurar el servidor (base URL y Authorization).
  /// - Provee métodos HTTP privados convenientes: `_get`/`_post`/`_put`/`_delete`.
///
/// Ejemplo de uso:
///
/// final api = ApiService.instance;
/// api.setServer(serverConnection);
/// final resp = await api.get('accounts');
///
class ApiService {
  ApiService._internal();

  static final ApiService instance = ApiService._internal();

  Dio? _dio;
  ServerConnection? _server;

  /// Tiempo por defecto para conexiones y recepción.
  /// Se usan Durations porque Dio 5.x los acepta.
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _receiveTimeout = Duration(seconds: 20);

  /// Indica si hay una conexión activa configurada.
  bool get isReady => _dio != null && _server != null;

  /// Configura el servidor y (re)crea la instancia de Dio.
  ///
  /// Cierra/limpia la instancia anterior si existía.
  /// La [server.url] se limpia sólo de barras finales, no se toca scheme ni path.
  void setServer(ServerConnection server, {bool enableLogging = true}) {
    // Compare with previous server (do not log the API key value)
    final prev = _server;
    final bool isDifferent = prev == null || prev.id != server.id || prev.url != server.url || prev.apiKey != server.apiKey;

    developer.log('ApiService: setServer() called - prev=${prev?.id ?? 'none'} new=${server.id} isDifferent=$isDifferent',
        name: 'ApiService');

    if (!isDifferent) {
      developer.log('ApiService: same server selected, skipping reconfiguration', name: 'ApiService');
      // If the same server was selected, do not recreate the Dio instance.
      // This avoids losing existing interceptors or inflight requests.
      return;
    }

    // Close previous instance (we are switching to a different server)
    if (_dio != null) {
      try {
        developer.log('ApiService: closing previous Dio instance', name: 'ApiService');
        _dio!.close(force: true);
      } catch (_) {}
      _dio = null;
    }

    _server = server;

    final trimmedUrl = _trimTrailingSlash(server.url);
    final base = '$trimmedUrl/api/v1/';

    final baseOptions = BaseOptions(
      baseUrl: base,
      connectTimeout: _connectTimeout,
      receiveTimeout: _receiveTimeout,
      headers: {
        'Accept': 'application/json',
        if (server.apiKey.isNotEmpty) 'Authorization': 'Bearer ${server.apiKey}',
      },
    );

    _dio = Dio(baseOptions);
    // Attach a default logging interceptor (configurable).
    if (enableLogging) {
      _dio!.interceptors.add(LogInterceptor(
        request: true,
        requestBody: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => developer.log(obj.toString(), name: 'ApiService.Log'),
      ));
      developer.log('ApiService: logging interceptor attached', name: 'ApiService');
    }

    developer.log('ApiService: server configured', name: 'ApiService',
        error:
            'id=${server.id} name=${server.name} base=${base} authorization=${server.apiKey.isNotEmpty ? 'present' : 'absent'}');
  }

  /// Cierra la conexión activa y limpia el estado.
  void close() {
  developer.log('ApiService: close() called', name: 'ApiService');
    if (_dio != null) {
      try {
        _dio!.close(force: true);
      } catch (_) {}
    }
    _dio = null;
    _server = null;
  }

  /// Añade un interceptor a la instancia activa.
  /// Lanza [StateError] si no hay servidor configurado.
  void addInterceptor(Interceptor interceptor) {
    _ensureReady();
    _dio!.interceptors.add(interceptor);
  }

  /// Permite acceso a la lista de interceptores para mayor control.
  List<Interceptor> get interceptors {
    _ensureReady();
    return _dio!.interceptors;
  }

  /// GET request (método privado).
  /// El caller externo debe implementar wrappers públicos si lo desea.
  // ignore: unused_element
  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureReady();
    final rel = _normalizeRelativePath(path);
    return _dio!.get<T>(rel, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  /// POST request (método privado).
  // ignore: unused_element
  Future<Response<T>> _post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureReady();
    final rel = _normalizeRelativePath(path);
    return _dio!.post<T>(rel, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  /// PUT request (método privado).
  // ignore: unused_element
  Future<Response<T>> _put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureReady();
    final rel = _normalizeRelativePath(path);
    return _dio!.put<T>(rel, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  /// DELETE request (método privado).
  // ignore: unused_element
  Future<Response<T>> _delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureReady();
    final rel = _normalizeRelativePath(path);
    return _dio!.delete<T>(rel, data: data, queryParameters: queryParameters, options: options, cancelToken: cancelToken);
  }

  /// Devuelve la instancia Dio (para usos avanzados). Lanza si no está lista.
  Dio get dio {
    _ensureReady();
    return _dio!;
  }

  // ----------------- Helpers -----------------

  void _ensureReady() {
    if (_dio == null || _server == null) {
      throw StateError('ApiService: servidor no configurado. Llama a setServer(...) antes de hacer peticiones.');
    }
  }

  String _trimTrailingSlash(String url) {
    if (url.isEmpty) return url;
    var out = url;
    while (out.endsWith('/')) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  String _normalizeRelativePath(String path) {
    var p = path.trim();
    // If the user passed an absolute URL, we should not allow it — always expect relative path.
    // But to be flexible, if they pass a URL that starts with http(s)://, remove the scheme and host
    // and keep the path part relative to base. Simpler: disallow absolute full URLs to avoid surprises.
    if (p.startsWith('http://') || p.startsWith('https://')) {
      throw ArgumentError('Las rutas deben ser relativas al base (/api/v1/). Pasa solo el path relativo, p.ej. "accounts" o "accounts/1".');
    }
    // remove leading slashes so baseUrl + path concatenation works as intended
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }
}
