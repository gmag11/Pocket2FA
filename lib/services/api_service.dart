import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:developer' as developer;
import '../models/server_connection.dart';
import '../models/account_entry.dart';

/// Centralized service for 2fauth API calls.
///
/// - Keeps a single active `Dio` instance.
/// - Call `setServer` to configure the server (base URL and Authorization).
/// - Provides convenient private HTTP helpers: `_get`/`_post`/`_put`/`_delete`.
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

  /// Default timeouts for connect and receive.
  /// Durations are used because Dio 5.x accepts them.
  static const Duration _connectTimeout = Duration(seconds: 10);
  static const Duration _receiveTimeout = Duration(seconds: 20);

  /// Indicates whether a server connection is configured.
  bool get isReady => _dio != null && _server != null;

  /// Configure the server and (re)create the Dio instance.
  ///
  /// Closes/cleans the previous instance if present.
  /// The [server.url] is trimmed of trailing slashes only; scheme and path are preserved.
  void setServer(ServerConnection server, {bool enableLogging = true}) {
    // Compare with previous server (do not log the API key value)
    final prev = _server;
    final bool isDifferent = prev == null ||
        prev.id != server.id ||
        prev.url != server.url ||
        prev.apiKey != server.apiKey;

    developer.log(
        'ApiService: setServer() called - prev=${prev?.id ?? 'none'} new=${server.id} isDifferent=$isDifferent',
        name: 'ApiService');

    if (!isDifferent) {
      developer.log(
          'ApiService: same server selected, skipping reconfiguration',
          name: 'ApiService');
      // If the same server was selected, do not recreate the Dio instance.
      // This avoids losing existing interceptors or inflight requests.
      return;
    }

    // Close previous instance (we are switching to a different server)
    if (_dio != null) {
      try {
        developer.log('ApiService: closing previous Dio instance',
            name: 'ApiService');
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
        if (server.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${server.apiKey}',
      },
    );

  _dio = Dio(baseOptions);
    // Attach a default logging interceptor (configurable).
    if (enableLogging) {
      // Use LogInterceptor but do NOT log request/response headers or bodies
      // here — we log masked bodies separately in our helpers. This prevents
      // accidental exposure of the Authorization header.
      _dio!.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => developer.log(obj.toString(), name: 'ApiService.Log'),
      ));
      // Also attach an interceptor that logs masked request/response bodies
      // and error bodies. We avoid logging headers here to prevent token
      // leakage; the bodies are masked via `_maskSecretsIn` before printing.
      _dio!.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          try {
            final path = options.path;
            developer.log(
                'ApiService: request path=$path method=${options.method} body=${_maskSecretsIn(options.data)}',
                name: 'ApiService.Log');
          } catch (_) {}
          handler.next(options);
        },
        onResponse: (response, handler) {
          try {
            final path = response.requestOptions.path;
            developer.log(
                'ApiService: response path=$path status=${response.statusCode} body=${_maskSecretsIn(response.data)}',
                name: 'ApiService.Log');
          } catch (_) {}
          handler.next(response);
        },
        onError: (err, handler) {
          try {
            final path = err.requestOptions.path;
            developer.log(
                'ApiService: error path=$path status=${err.response?.statusCode} data=${_maskSecretsIn(err.response?.data)}',
                name: 'ApiService.Log');
          } catch (_) {}
          handler.next(err);
        },
      ));
      developer.log('ApiService: logging interceptor attached',
          name: 'ApiService');
    }

  developer.log('ApiService: server configured', name: 'ApiService', error: 'id=${server.id} name=${server.name} base=$base authorization=${server.apiKey.isNotEmpty ? 'present' : 'absent'}');
  }

  /// Closes the active connection and clears state.
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

  /// Adds an interceptor to the active instance.
  /// Throws [StateError] if no server is configured.
  void addInterceptor(Interceptor interceptor) {
    _ensureReady();
    _dio!.interceptors.add(interceptor);
  }

  /// Permite acceso a la lista de interceptores para mayor control.
  List<Interceptor> get interceptors {
    _ensureReady();
    return _dio!.interceptors;
  }

  /// GET request (private method).
  /// External callers should implement public wrappers if desired.
  // ignore: unused_element
  Future<Response<T>> _get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    _ensureReady();
    final rel = _normalizeRelativePath(path);
    try {
      try {
        developer.log('ApiService: GET $rel query=${_maskSecretsIn(queryParameters)}', name: 'ApiService');
      } catch (_) {}
      final resp = await _dio!.get<T>(rel,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
      try {
        developer.log('ApiService: GET response path=$rel status=${resp.statusCode} body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      } catch (_) {}
      return resp;
    } on DioException catch (e) {
      try {
        developer.log('ApiService: GET DioException path=$rel status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// POST request (private method).
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
    try {
      try {
        developer.log('ApiService: POST $rel query=${_maskSecretsIn(queryParameters)} body=${_maskSecretsIn(data)}', name: 'ApiService');
      } catch (_) {}
      final resp = await _dio!.post<T>(rel,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
      try {
        developer.log('ApiService: POST response path=$rel status=${resp.statusCode} body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      } catch (_) {}
      return resp;
    } on DioException catch (e) {
      try {
        developer.log('ApiService: POST DioException path=$rel status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// PUT request (private method).
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
    try {
      try {
        developer.log('ApiService: PUT $rel query=${_maskSecretsIn(queryParameters)} body=${_maskSecretsIn(data)}', name: 'ApiService');
      } catch (_) {}
      final resp = await _dio!.put<T>(rel,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
      try {
        developer.log('ApiService: PUT response path=$rel status=${resp.statusCode} body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      } catch (_) {}
      return resp;
    } on DioException catch (e) {
      try {
        developer.log('ApiService: PUT DioException path=$rel status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// DELETE request (private method).
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
    try {
      try {
        developer.log('ApiService: DELETE $rel query=${_maskSecretsIn(queryParameters)} body=${_maskSecretsIn(data)}', name: 'ApiService');
      } catch (_) {}
      final resp = await _dio!.delete<T>(rel,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken);
      try {
        developer.log('ApiService: DELETE response path=$rel status=${resp.statusCode} body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      } catch (_) {}
      return resp;
    } on DioException catch (e) {
      try {
        developer.log('ApiService: DELETE DioException path=$rel status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// Returns the Dio instance (for advanced uses). Throws if not ready.
  Dio get dio {
    _ensureReady();
    return _dio!;
  }

  // ----------------- Helpers -----------------

  void _ensureReady() {
    if (_dio == null || _server == null) {
      throw StateError(
          'ApiService: server not configured. Call setServer(...) before making requests.');
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
      throw ArgumentError(
          'Paths must be relative to the base (/api/v1/). Pass only the relative path, e.g. "accounts" or "accounts/1".');
    }
    // remove leading slashes so baseUrl + path concatenation works as intended
    while (p.startsWith('/')) {
      p = p.substring(1);
    }
    return p;
  }

  // Deep-clone the object and mask sensitive fields before logging.
  dynamic _maskSecretsIn(dynamic obj) {
    if (obj == null) return null;
    try {
      if (obj is Map) {
        final out = <dynamic, dynamic>{};
        obj.forEach((k, v) {
          try {
            final key = k?.toString();
            if (key == 'secret' || key == 'seed' || key == 'apiKey' || key == 'Authorization') {
              out[k] = v == null ? null : '***REDACTED***';
            } else {
              out[k] = _maskSecretsIn(v);
            }
          } catch (_) {
            out[k] = '***UNPRINTABLE***';
          }
        });
        return out;
      }
      if (obj is List) return obj.map((e) => _maskSecretsIn(e)).toList();
      return obj;
    } catch (_) {
      return '***UNPRINTABLE***';
    }
  }

  /// Validate a server (GET /api/v1/user) using the provided [server] data.
  ///
  /// This method does not require `setServer` to have been called; it creates a
  /// temporary Dio instance with short timeouts to validate connectivity and
  /// returns the decoded body as `Map<String, dynamic>` when the endpoint responds with 200.
  ///
  /// Throws [DioException] for connection/response errors and [StateError]
  /// for unexpected responses.
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
        if (server.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${server.apiKey}',
      },
    );

    final dio = Dio(opts);
    // lightweight logging for validation (do not log sensitive values)
  // Validation uses a lightweight logger that must also avoid printing headers
  dio.interceptors.add(LogInterceptor(
    request: true,
    requestHeader: false,
    requestBody: false,
    responseHeader: false,
    responseBody: false,
    error: true,
    logPrint: (o) => developer.log(o.toString(), name: 'ApiService.validate')));

    final resp = await dio.get('user');
    if (resp.statusCode == 200 && resp.data is Map) {
      return Map<String, dynamic>.from(resp.data as Map);
    }

    throw StateError(
        'Unexpected response validating server: ${resp.statusCode}');
  }

  /// Request a one-time OTP (HOTP) for a specific account from the server.
  ///
  /// Calls GET /twofaccounts/{id}/otp and returns a Map with keys:
  ///  - 'password': the current OTP (always present)
  ///  - 'nextPassword': the next OTP when provided by the API (may be null)
  ///  - 'counter': integer counter value when the API provides it (may be null)
  Future<Map<String, dynamic>> fetchAccountOtp(int accountId,
      {CancelToken? cancelToken}) async {
    _ensureReady();
  if (accountId <= 0) throw ArgumentError('accountId must be greater than 0');
    final path = 'twofaccounts/$accountId/otp';
    final resp = await _dio!.get(path, cancelToken: cancelToken);
    if (resp.statusCode == 200 && resp.data != null) {
      final data = resp.data;
      if (data is Map) {
        final pwd = data['password'];
        if (pwd == null) {
          throw StateError('Invalid OTP response shape: missing "password"');
        }
        // Support both snake_case and camelCase from server responses
        final nextPwd = data.containsKey('next_password')
            ? (data['nextPassword']?.toString())
            : (data.containsKey('next_password')
                ? (data['next_password']?.toString())
                : null);
        int? counter;
        try {
          if (data.containsKey('counter') && data['counter'] != null) {
            final v = data['counter'];
            if (v is int) {
              counter = v;
            } else if (v is String) {
              counter = int.tryParse(v);
            } else {
              counter = int.tryParse(v.toString());
            }
          }
        } catch (_) {
          counter = null;
        }
        return {
          'password': pwd.toString(),
          'next_password': nextPwd,
          'counter': counter,
        };
      }
      throw StateError('Invalid OTP response shape');
    }
    throw StateError('Unexpected OTP response: ${resp.statusCode}');
  }

  /// Create a 2FA account on the server (POST /twofaccounts).
  ///
  /// The [body] must follow the 2FAccountStore shape (see API spec). Returns
  /// the decoded server response as a Map when the server responds with 201.
  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> body,
      {CancelToken? cancelToken}) async {
    _ensureReady();
    try {
      developer.log('ApiService: createAccount payload keys=${body.keys.toList()}', name: 'ApiService');
      developer.log('ApiService: createAccount payload=${_maskSecretsIn(body)}', name: 'ApiService');
    } catch (_) {}
    try {
      final resp = await _dio!.post('twofaccounts', data: body, cancelToken: cancelToken);
      try {
        developer.log('ApiService: createAccount response status=${resp.statusCode}', name: 'ApiService');
        developer.log('ApiService: createAccount response body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      } catch (_) {}
      if (resp.statusCode == 201 && resp.data != null && resp.data is Map) {
        try {
          developer.log('ApiService: createAccount returned body keys=${(resp.data as Map).keys.toList()}', name: 'ApiService');
        } catch (_) {}
        return Map<String, dynamic>.from(resp.data as Map);
      }
      try {
        developer.log('ApiService: createAccount unexpected response body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      } catch (_) {}
      throw StateError('Unexpected create account response: ${resp.statusCode}');
    } on DioException catch (e) {
      // Log response body if present to aid debugging (may contain validation errors)
      try {
        developer.log('ApiService: createAccount DioException status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// Convenience wrapper to create an account from an [AccountEntry]. If you
  /// have a server-side group id, pass it as [groupId]; otherwise the wrapper
  /// will omit group_id and the server will treat it as ungrouped.
  Future<Map<String, dynamic>> createAccountFromEntry(AccountEntry entry, {int? groupId, CancelToken? cancelToken}) async {
    final Map<String, dynamic> payload = {
      if (entry.service.isNotEmpty) 'service': entry.service,
      'account': entry.account,
      'secret': entry.seed,
      'otp_type': entry.otpType ?? 'totp',
      if (entry.digits != null) 'digits': entry.digits,
      if (entry.algorithm != null) 'algorithm': entry.algorithm,
      // Para HOTP, enviar counter (que almacenamos en period) y para TOTP enviar period
      if (entry.otpType?.toLowerCase() == 'hotp' && entry.period != null) 
        'counter': entry.period
      else if (entry.period != null) 
        'period': entry.period,
      if (groupId != null) 'group_id': groupId,
    };
    // Remove nulls/empty
    payload.removeWhere((k, v) => v == null);
    try {
      developer.log('ApiService: createAccountFromEntry service=${entry.service} account=${entry.account} groupId=$groupId', name: 'ApiService');
      developer.log('ApiService: createAccountFromEntry payload=${_maskSecretsIn(payload)}', name: 'ApiService');
    } catch (_) {}
    try {
      final resp = await createAccount(payload, cancelToken: cancelToken);
      try {
        developer.log('ApiService: createAccountFromEntry response keys=${resp.keys.toList()}', name: 'ApiService');
      } catch (_) {}
      return resp;
    } on DioException catch (e) {
      try {
        developer.log('ApiService: createAccountFromEntry DioException status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// Delete one or more 2FA accounts on the server (DELETE /twofaccounts?ids=1,2)
  ///
  /// If the server responds with 204 the operation is considered successful.
  Future<void> deleteAccounts(List<int> ids, {CancelToken? cancelToken}) async {
    _ensureReady();
    if (ids.isEmpty) return;
    final idsParam = ids.join(',');
    try {
      final resp = await _dio!.delete('twofaccounts',
          queryParameters: {'ids': idsParam}, cancelToken: cancelToken);
      if (resp.statusCode == 204) {
        developer.log('ApiService: deleteAccounts success ids=$idsParam', name: 'ApiService');
        return;
      }
      developer.log('ApiService: deleteAccounts unexpected status=${resp.statusCode} body=${_maskSecretsIn(resp.data)}', name: 'ApiService');
      throw StateError('Unexpected delete response: ${resp.statusCode}');
    } on DioException catch (e) {
      try {
        developer.log('ApiService: deleteAccounts DioException status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
  }

  /// Update a 2FA account on the server (PUT /twofaccounts/{id})
  ///
  /// Returns a Map representing the updated account data from the server response.
  Future<Map<dynamic, dynamic>> updateAccountFromEntry(AccountEntry entry, {CancelToken? cancelToken}) async {
    _ensureReady();
    if (entry.id <= 0) {
      throw Exception('Cannot update account without valid server ID');
    }
    
    final body = <String, dynamic>{
      'service': entry.service.isEmpty ? null : entry.service,
      'account': entry.account,
      'secret': entry.seed,
      // API expects otp_type in lowercase (e.g. 'totp')
      'otp_type': (entry.otpType ?? 'totp').toLowerCase(),
      'digits': entry.digits ?? 6,
      'algorithm': entry.algorithm ?? 'sha1',
    };
    
    // Add period or counter based on OTP type
    if (entry.otpType == 'hotp') {
      body['counter'] = entry.counter ?? 0;
    } else {
      body['period'] = entry.period ?? 30;
    }
    
    // Add group_id if present
    if (entry.groupId != null) {
      body['group_id'] = entry.groupId;
    }
    
  // Ensure the icon field is present in the request body. Some servers
  // validate its presence even if null, so include it explicitly.
  body['icon'] = (entry.icon == null || entry.icon!.isEmpty) ? null : entry.icon;
    
    try {
      final resp = await _put('twofaccounts/${entry.id}', data: body, cancelToken: cancelToken);
      if (resp.statusCode == 200 && resp.data is Map) {
        developer.log('ApiService: updateAccountFromEntry success id=${entry.id}', name: 'ApiService');
        return Map<dynamic, dynamic>.from(resp.data as Map);
      }
      
      developer.log('ApiService: updateAccountFromEntry unexpected status=${resp.statusCode} id=${entry.id}', name: 'ApiService');
      throw Exception('Unexpected response: ${resp.statusCode}');
    } on DioException catch (e) {
      try {
        developer.log('ApiService: updateAccountFromEntry DioException status=${e.response?.statusCode} data=${_maskSecretsIn(e.response?.data)}', name: 'ApiService');
      } catch (_) {}
      rethrow;
    }
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
        case 405:
          return 'Method not allowed (405). Check the API documentation.';
        default:
          if (status >= 500) {
            return 'Server error ($status). Try again later$detail';
          }
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
      if (msg.contains('Failed host lookup') ||
          msg.contains('No address associated')) {
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
  Future<Uint8List> downloadIcon(String fileName,
      {CancelToken? cancelToken}) async {
    _ensureReady();
    final srv = _server!;
    final trimmed = _trimTrailingSlash(srv.url);
    final encoded = Uri.encodeComponent(fileName);
    final url = '$trimmed/storage/icons/$encoded';

    // Use bytes response type to get the raw content
    final resp = await _dio!.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken);
    if (resp.statusCode == 200 && resp.data != null) {
      return Uint8List.fromList(List<int>.from(resp.data!));
    }

    throw StateError(
        'Unexpected response downloading icon: ${resp.statusCode}');
  }

  /// Get a persistently cached icon file. If the file does not exist locally
  /// it will be downloaded via `downloadIcon` and saved to the application
  /// support directory. Returns the bytes read from disk.
  // Persistent icon caching moved to `IconCacheService` to keep network and
  // storage responsibilities separated.
}
