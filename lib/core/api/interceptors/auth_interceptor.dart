import 'package:dio/dio.dart';

import '../vault_connection_config.dart';

const vaultTokenHeader = 'X-Vault-Token';
const vaultNamespaceHeader = 'X-Vault-Namespace';
const vaultWrapTtlHeader = 'X-Vault-Wrap-TTL';

/// Request `extra` flag: do not attach the session token (login calls).
const extraNoAuth = 'vault.noAuth';

/// Request `extra` flag: never retry this request.
const extraNoRetry = 'vault.noRetry';

/// Injects `X-Vault-Token` and `X-Vault-Namespace`.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokenHolder, required this.namespace});

  final TokenHolder tokenHolder;
  final String namespace;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (namespace.isNotEmpty) {
      options.headers.putIfAbsent(vaultNamespaceHeader, () => namespace);
    }
    final skip =
        options.extra[extraNoAuth] == true ||
        options.headers.containsKey(vaultTokenHeader);
    if (!skip && tokenHolder.hasToken) {
      options.headers[vaultTokenHeader] = tokenHolder.token;
    }
    handler.next(options);
  }
}
