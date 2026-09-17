import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../utils/app_logger.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'vault_connection_config.dart';

/// Builds a [Dio] instance configured for one Vault/OpenBao server.
Dio buildVaultDio({
  required VaultConnectionConfig config,
  required TokenHolder tokenHolder,
  required AppLogger logger,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: config.connectTimeout,
      sendTimeout: config.receiveTimeout,
      receiveTimeout: config.receiveTimeout,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      // Dart forwards custom headers across redirects, so following one could
      // hand X-Vault-Token to another host.
      followRedirects: false,
    ),
  );

  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final context = SecurityContext(withTrustedRoots: true);
      final ca = config.caCertPem;
      if (ca != null && ca.trim().isNotEmpty) {
        context.setTrustedCertificatesBytes(utf8.encode(ca));
      }
      final client = HttpClient(context: context);
      if (!config.tlsVerify) {
        client.badCertificateCallback = (_, __, ___) => true;
      }
      return client;
    },
  );

  dio.interceptors.addAll([
    AuthInterceptor(tokenHolder: tokenHolder, namespace: config.namespace),
    LoggingInterceptor(logger),
    RetryInterceptor(dio: dio, maxRetries: config.maxRetries),
  ]);
  return dio;
}
