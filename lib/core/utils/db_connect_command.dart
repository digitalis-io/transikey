import 'shell_quote.dart';

enum DbClient {
  psql('psql', 'PostgreSQL', 5432),
  mysql('mysql', 'MySQL / MariaDB', 3306);

  const DbClient(this.binary, this.label, this.defaultPort);

  final String binary;
  final String label;
  final int defaultPort;
}

/// Where the database lives. Not part of the Vault response, so the user
/// keeps it in settings.
class DbTarget {
  const DbTarget({
    required this.client,
    required this.host,
    required this.port,
    required this.database,
  });

  final DbClient client;
  final String host;
  final int port;
  final String database;
}

/// Shell one-liner that connects with dynamic credentials. The password
/// travels through the client's environment variable, not through argv,
/// so it does not show up in `ps`.
String dbConnectCommand(DbTarget target, String username, String password) {
  final host = shellQuote(target.host.trim());
  final user = shellQuote(username);
  final db = shellQuote(target.database.trim());
  return switch (target.client) {
    DbClient.psql =>
      'PGPASSWORD=${shellQuote(password)} psql '
          '-h $host -p ${target.port} -U $user -d $db',
    DbClient.mysql =>
      'MYSQL_PWD=${shellQuote(password)} mysql '
          '-h $host -P ${target.port} -u $user $db',
  };
}

/// Connection URI for tools that take one (DBeaver, DataGrip, drivers).
String dbConnectUri(DbTarget target, String username, String password) {
  final scheme = switch (target.client) {
    DbClient.psql => 'postgresql',
    DbClient.mysql => 'mysql',
  };
  return Uri(
    scheme: scheme,
    userInfo:
        '${Uri.encodeComponent(username)}:'
        '${Uri.encodeComponent(password)}',
    host: target.host.trim(),
    port: target.port,
    path: '/${target.database.trim()}',
  ).toString();
}
