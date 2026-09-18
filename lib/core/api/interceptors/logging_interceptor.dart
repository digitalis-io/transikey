import 'package:dio/dio.dart';

import '../../utils/app_logger.dart';

/// Structured request logging. Logs method, path, status and latency only.
/// Headers and bodies are never logged.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor(this._log);

  final AppLogger _log;
  static const _startKey = 'vault.startedAt';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log.debug(
      'vault.request',
      _fields(response.requestOptions)..['status'] = response.statusCode,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.warning(
      'vault.request.failed',
      _fields(err.requestOptions)
        ..['status'] = err.response?.statusCode
        ..['kind'] = err.type.name,
    );
    handler.next(err);
  }

  Map<String, Object?> _fields(RequestOptions o) {
    final started = o.extra[_startKey] as DateTime?;
    return {
      'method': o.method,
      'path': o.path,
      if (started != null)
        'ms': DateTime.now().difference(started).inMilliseconds,
    };
  }
}
