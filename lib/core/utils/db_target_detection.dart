import 'db_connect_command.dart';

/// What the database secrets engine reveals about the connection behind a
/// role. Every part is optional: plugins and policies differ.
class DetectedDatabase {
  const DetectedDatabase({
    required this.connection,
    this.client,
    this.host,
    this.port,
    this.database,
  });

  /// Name of the connection (`db_name` of the role).
  final String connection;
  final DbClient? client;
  final String? host;
  final int? port;
  final String? database;
}

/// Maps a database plugin name to the command line client that talks to it.
DbClient? dbClientForPlugin(String pluginName) {
  final name = pluginName.toLowerCase();
  if (name.startsWith('postgresql') || name.startsWith('redshift')) {
    return DbClient.psql;
  }
  if (name.startsWith('mysql')) return DbClient.mysql;
  if (name.startsWith('cassandra')) return DbClient.cqlsh;
  return null;
}

/// Builds a [DetectedDatabase] from `database/config/<name>`.
///
/// Only host, port and database name are taken from `connection_url`. The
/// URL may embed a password when it is not templated, so it is never kept,
/// shown or logged.
DetectedDatabase detectDatabase(
  String connection,
  String pluginName,
  Map<String, dynamic> connectionDetails,
) {
  final client = dbClientForPlugin(pluginName);
  final url = connectionDetails['connection_url'];
  if (url is String && url.trim().isNotEmpty) {
    final parsed = parseConnectionUrl(url);
    return DetectedDatabase(
      connection: connection,
      client: client,
      host: parsed.host,
      port: parsed.port,
      database: parsed.database,
    );
  }
  // Cassandra style: `hosts` (comma separated) and `port`.
  final hosts = connectionDetails['hosts'];
  final first = hosts is String
      ? hosts
            .split(',')
            .map((h) => h.trim())
            .firstWhere((h) => h.isNotEmpty, orElse: () => '')
      : '';
  return DetectedDatabase(
    connection: connection,
    client: client,
    host: _text(first),
    port: _port('${connectionDetails['port'] ?? ''}'),
  );
}

typedef ConnectionUrlParts = ({String? host, int? port, String? database});

/// Extracts host, port and database from a connection URL. Understands the
/// URI form (`postgresql://user:pass@host:5432/db?opt`) and the Go MySQL
/// DSN form (`user:pass@tcp(host:3306)/db`). Anything unreadable is null.
ConnectionUrlParts parseConnectionUrl(String url) {
  var rest = url.trim();
  final scheme = rest.indexOf('://');
  if (scheme >= 0) rest = rest.substring(scheme + 3);
  // Credentials may contain '@' or '/': the host starts after the last '@'
  // that precedes the path.
  final at = rest.lastIndexOf('@');
  if (at >= 0) rest = rest.substring(at + 1);
  final query = rest.indexOf('?');
  if (query >= 0) rest = rest.substring(0, query);

  String authority;
  String? database;
  final tcp = RegExp(r'^\w+\(([^)]*)\)(?:/(.*))?$').firstMatch(rest);
  if (tcp != null) {
    authority = tcp.group(1)!;
    database = tcp.group(2);
  } else {
    final slash = rest.indexOf('/');
    authority = slash >= 0 ? rest.substring(0, slash) : rest;
    database = slash >= 0 ? rest.substring(slash + 1) : null;
  }
  // Multi-host URLs: the first host is enough to build a command.
  authority = authority.split(',').first.trim();

  String? host;
  int? port;
  final v6 = RegExp(r'^\[([^\]]+)\](?::(\d+))?$').firstMatch(authority);
  if (v6 != null) {
    host = v6.group(1);
    port = _port(v6.group(2));
  } else {
    final colon = authority.lastIndexOf(':');
    if (colon >= 0 && authority.indexOf(':') == colon) {
      host = authority.substring(0, colon);
      port = _port(authority.substring(colon + 1));
    } else {
      host = authority;
    }
  }
  return (host: _text(host), port: port, database: _text(database));
}

/// Server supplied text ends up in a command the user pastes into a shell:
/// anything with control characters or of absurd length is dropped.
String? _text(String? value) {
  final clean = value?.trim() ?? '';
  if (clean.isEmpty || clean.length > 255) return null;
  return RegExp(r'[\x00-\x1f\x7f]').hasMatch(clean) ? null : clean;
}

int? _port(String? value) {
  final port = int.tryParse(value ?? '');
  return port != null && port >= 1 && port <= 65535 ? port : null;
}
