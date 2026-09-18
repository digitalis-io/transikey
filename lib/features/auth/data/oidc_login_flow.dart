import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../../core/api/vault_api_client.dart';
import '../../../core/errors/vault_exception.dart';
import '../../../core/models/auth_response.dart';

/// Browser based OIDC login, the same flow as `vault login -method=oidc`:
///
/// 1. ask the server for the identity provider URL,
/// 2. open it in the system browser,
/// 3. catch the provider's redirect on `http://localhost:8250/oidc/callback`,
/// 4. trade the returned `code` for a Vault token.
///
/// The role must list that redirect URI in `allowed_redirect_uris`.
class OidcLoginFlow {
  OidcLoginFlow({
    required VaultApiClient client,
    required Future<bool> Function(Uri url) openBrowser,
    this.port = 8250,
    this.timeout = const Duration(minutes: 3),
  }) : _client = client,
       _openBrowser = openBrowser;

  final VaultApiClient _client;
  final Future<bool> Function(Uri url) _openBrowser;
  final int port;
  final Duration timeout;

  Uri get redirectUri => Uri.parse('http://localhost:$port/oidc/callback');

  Future<AuthResponse> run(String role) async {
    final HttpServer server;
    try {
      // Loopback only: the callback never leaves this machine.
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      throw ValidationException(
        'Port $port is in use. Close the other login (vault or bao CLI?) '
        'and try again.',
      );
    }
    try {
      final nonce = _nonce();
      final authUrl = await _client.oidcAuthUrl(
        role: role,
        redirectUri: redirectUri,
        clientNonce: nonce,
      );
      final expectedState = authUrl.queryParameters['state'] ?? '';

      if (!await _openBrowser(authUrl)) {
        throw const VaultException('Could not open the system browser.');
      }

      final callback = await _awaitCallback(server).timeout(
        timeout,
        onTimeout: () => throw const AuthenticationException(
          'OIDC login timed out. No response came back from the browser.',
        ),
      );

      final providerError = callback['error'];
      if (providerError != null) {
        throw AuthenticationException(
          'The identity provider refused the login.',
          errors: [callback['error_description'] ?? providerError],
        );
      }
      final state = callback['state'] ?? '';
      final code = callback['code'] ?? '';
      if (code.isEmpty || state.isEmpty || state != expectedState) {
        throw const AuthenticationException(
          'OIDC callback did not match this login attempt.',
        );
      }
      return await _client.oidcCallback(
        state: state,
        code: code,
        clientNonce: nonce,
      );
    } finally {
      await server.close(force: true);
    }
  }

  /// Serves requests until one hits the callback path; returns its query.
  Future<Map<String, String>> _awaitCallback(HttpServer server) async {
    await for (final request in server) {
      final isCallback = request.uri.path == redirectUri.path;
      request.response
        ..statusCode = isCallback ? HttpStatus.ok : HttpStatus.notFound
        ..headers.contentType = ContentType.html
        ..write(isCallback ? _donePage : 'Not found');
      await request.response.close();
      if (isCallback) return request.uri.queryParameters;
    }
    throw const AuthenticationException('OIDC login was interrupted.');
  }

  static String _nonce() {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(24, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  static const _donePage =
      '<!doctype html><meta charset="utf-8">'
      '<title>Transikey</title>'
      '<body style="font-family:system-ui;text-align:center;margin-top:20vh">'
      '<h2>Signed in</h2><p>Return to Transikey. You can close this tab.</p>';
}
