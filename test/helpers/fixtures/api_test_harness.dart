import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Drives a [Dio] instance with mocked responses and records every request.
///
/// The mock adapter replaces the HTTP transport, while the recording
/// interceptor keeps the real [RequestOptions] so tests can assert the exact
/// payload, query parameters and path that [ApiService] produced.
class ApiTestHarness {
  ApiTestHarness(this.dio, {bool matchMethod = false}) {
    adapter = DioAdapter(
      dio: dio,
      matcher: UrlRequestMatcher(matchMethod: matchMethod),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.next(options);
        },
      ),
    );
  }

  final Dio dio;
  late final DioAdapter adapter;
  final List<RequestOptions> requests = [];

  RequestOptions get lastRequest => requests.last;
}
