import 'package:equatable/equatable.dart';

import 'shell_quote.dart';

/// `transikey://unwrap?addr=<server>&ns=<namespace>&token=<wrapping token>`
///
/// A one-time link for handing a response-wrapped secret to a colleague.
/// The wrapping token is single use, so a link that fails to unwrap has been
/// opened by someone else.
class ShareLink extends Equatable {
  const ShareLink({
    required this.address,
    required this.token,
    this.namespace = '',
  });

  static const scheme = 'transikey';
  static const _action = 'unwrap';

  final String address;
  final String namespace;
  final String token;

  Uri toUri() => Uri(
    scheme: scheme,
    host: _action,
    queryParameters: {
      'addr': address,
      if (namespace.isNotEmpty) 'ns': namespace,
      'token': token,
    },
  );

  /// Shell command for recipients without the app. Works with `vault` too.
  String toCliCommand() => [
    'BAO_ADDR=${shellQuote(address)}',
    if (namespace.isNotEmpty) 'BAO_NAMESPACE=${shellQuote(namespace)}',
    'bao unwrap ${shellQuote(token)}',
  ].join(' ');

  /// Returns null for anything that is not a well-formed unwrap link.
  static ShareLink? tryParse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || uri.scheme != scheme || uri.host != _action) return null;
    final address = uri.queryParameters['addr']?.trim() ?? '';
    final token = uri.queryParameters['token']?.trim() ?? '';
    final server = Uri.tryParse(address);
    final validServer =
        server != null &&
        (server.scheme == 'https' || server.scheme == 'http') &&
        server.host.isNotEmpty;
    if (!validServer || token.isEmpty) return null;
    return ShareLink(
      address: address,
      namespace: uri.queryParameters['ns']?.trim() ?? '',
      token: token,
    );
  }

  @override
  List<Object?> get props => [address, namespace, token];

  @override
  String toString() => 'ShareLink(address: $address, token: ***)';
}
