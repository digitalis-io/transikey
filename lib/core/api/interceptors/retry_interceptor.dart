import 'package:dio/dio.dart';

import 'auth_interceptor.dart';

/// Retries requests that never reached the server (connect timeout or
/// connection error). Responses and receive timeouts are never retried
/// because credential endpoints are not idempotent.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 400),
  });

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;

  static const _attemptKey = 'vault.retryAttempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    final retryable =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.connectionError;
    if (!retryable ||
        attempt >= maxRetries ||
        options.extra[extraNoRetry] == true) {
      return handler.next(err);
    }
    await Future<void>.delayed(baseDelay * (1 << attempt));
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}
