import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:typed_data';
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
/// ```dart
/// final api = ApiService.instance;
/// api.setServer(serverConnection);
/// final resp = await api.get('accounts');
/// ```
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
      } catch (_) {
        // ignore errors while closing
      }
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
      // Also attach a lightweight response-summary interceptor so callers
      // can see response status and path in the same ApiService log channel.
      _dio!.interceptors.add(InterceptorsWrapper(
        onResponse: (response, handler) {
          try {
            final path = response.requestOptions.path;
            developer.log('ApiService: response path=$path status=${response.statusCode}', name: 'ApiService.Log');
          } catch (_) {}
          handler.next(response);
        },
      ));
      developer.log('ApiService: logging interceptor attached', name: 'ApiService');
    }

    developer.log('ApiService: server configured', name: 'ApiService',
        error:
            'id=${server.id} name=${server.name} base=$base authorization=${server.apiKey.isNotEmpty ? 'present' : 'absent'}');
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

  /// Valida un servidor (GET /api/v1/user) usando los datos del [server] pasado.
  ///
  /// Este método no requiere que `setServer` haya sido llamado; crea una
  /// instancia temporal de Dio con timeouts cortos para validar la conexión y
  /// devolverá el body decodificado como Map&lt;String, dynamic&gt; cuando el
  /// endpoint responda con 200.
  ///
  /// Lanza [DioException] para errores de conexión/respuesta y [StateError]
  /// para respuestas inesperadas.
  Future<Map<String, dynamic>> validateServer(ServerConnection server,
      {Duration connectTimeout = const Duration(seconds: 6),
      Duration receiveTimeout = const Duration(seconds: 6)}) async {
    final trimmedUrl = _trimTrailingSlash(server.url);
    final base = '$trimmedUrl/api/v1/';

    final opts = BaseOptions(
      baseUrl: base,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      headers: {
        'Accept': 'application/json',
        if (server.apiKey.isNotEmpty) 'Authorization': 'Bearer ${server.apiKey}',
      },
    );

    final dio = Dio(opts);
    // lightweight logging for validation (do not log sensitive values)
    dio.interceptors.add(LogInterceptor(request: true, requestBody: false, responseBody: false, error: true, logPrint: (o) => developer.log(o.toString(), name: 'ApiService.validate')));

    final resp = await dio.get('user');
    if (resp.statusCode == 200 && resp.data is Map) {
      return Map<String, dynamic>.from(resp.data as Map);
    }

    throw StateError('Unexpected response validating server: ${resp.statusCode}');
  }

  /// Produce a user-friendly, localized-ish message from a [DioException].
  ///
  /// Intentionally conservative: avoid leaking sensitive data (API keys).
  String friendlyErrorMessageFromDio(DioException e) {
    final status = e.response?.statusCode;
    // If the server returned a code, map common ones to helpful text.
    if (status != null) {
      final data = e.response?.data;
      String detail = '';
      try {
        if (data is Map && data['message'] != null) {
          detail = ': ${data['message']}';
        } else if (data is String && data.isNotEmpty) {
          detail = ': $data';
        }
      } catch (_) {
        // ignore parse errors from response body
      }

      switch (status) {
        case 400:
          return 'Bad request (400)$detail';
        case 401:
          return 'Unauthorized (401). Check the API key.';
        case 403:
          return 'Forbidden (403). You don\'t have permission.';
        case 404:
          return 'Not found (404). Verify the server URL.';
        default:
          if (status >= 500) return 'Server error ($status). Try again later$detail';
          return 'Server error ($status)$detail';
      }
    }

    // No status code: inspect the DioException type or inner error.
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your network and server URL.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.unknown:
        // Fallthrough to inspect inner error
        break;
      case DioExceptionType.badResponse:
        return 'Bad response from server.';
      default:
        break;
    }

    final inner = e.error;
    if (inner is SocketException) {
      final os = inner.osError;
      final msg = os?.message ?? inner.message;
      if (msg.contains('Failed host lookup') || msg.contains('No address associated')) {
        return 'Unable to resolve host. Check the server address and your internet connection.';
      }
      return 'Connection error: ${msg.isNotEmpty ? msg : inner.toString()}';
    }

  final m = e.message;
  return 'Connection error: ${m != null && m.isNotEmpty ? m : e.toString()}';
  }

  /// Generic helper to convert any thrown object into a user-friendly message.
  String friendlyErrorMessage(Object e) {
    if (e is DioException) return friendlyErrorMessageFromDio(e);
    if (e is StateError) return e.message;
    return e.toString();
  }

  /// Download an icon file from the server's storage endpoint.
  ///
  /// The file is retrieved from: `<server.url>/storage/icons/{fileName}`
  /// Returns the raw bytes as [Uint8List]. Requires `setServer(...)` to have
  /// been called previously; otherwise a [StateError] will be thrown.
  Future<Uint8List> downloadIcon(String fileName, {CancelToken? cancelToken}) async {
    _ensureReady();
    final srv = _server!;
    final trimmed = _trimTrailingSlash(srv.url);
    final encoded = Uri.encodeComponent(fileName);
    final url = '$trimmed/storage/icons/$encoded';

    // Use bytes response type to get the raw content
    final resp = await _dio!.get<List<int>>(url, options: Options(responseType: ResponseType.bytes), cancelToken: cancelToken);
    if (resp.statusCode == 200 && resp.data != null) {
      return Uint8List.fromList(List<int>.from(resp.data!));
    }

    throw StateError('Unexpected response downloading icon: ${resp.statusCode}');
  }

  /// Get a persistently cached icon file. If the file does not exist locally
  /// it will be downloaded via `downloadIcon` and saved to the application
  /// support directory. Returns the bytes read from disk.
  // Persistent icon caching moved to `IconCacheService` to keep network and
  // storage responsibilities separated.
}
