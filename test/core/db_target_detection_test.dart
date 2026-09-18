import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/db_connect_command.dart';
import 'package:transikey/core/utils/db_target_detection.dart';

void main() {
  group('dbClientForPlugin', () {
    test('maps the built-in plugins to their clients', () {
      expect(dbClientForPlugin('postgresql-database-plugin'), DbClient.psql);
      expect(dbClientForPlugin('mysql-database-plugin'), DbClient.mysql);
      expect(dbClientForPlugin('mysql-rds-database-plugin'), DbClient.mysql);
      expect(dbClientForPlugin('cassandra-database-plugin'), DbClient.cqlsh);
    });

    test('an unknown plugin has no client', () {
      expect(dbClientForPlugin('mongodb-database-plugin'), isNull);
      expect(dbClientForPlugin(''), isNull);
    });
  });

  group('parseConnectionUrl', () {
    test('reads a templated PostgreSQL URL', () {
      expect(
        parseConnectionUrl(
          'postgresql://{{username}}:{{password}}@pg.internal:5433/app?sslmode=disable',
        ),
        (host: 'pg.internal', port: 5433, database: 'app'),
      );
    });

    test('reads a Go MySQL DSN', () {
      expect(
        parseConnectionUrl(
          '{{username}}:{{password}}@tcp(db.internal:3306)/shop',
        ),
        (host: 'db.internal', port: 3306, database: 'shop'),
      );
      expect(
        parseConnectionUrl('{{username}}:{{password}}@tcp(db.internal:3306)/'),
        (host: 'db.internal', port: 3306, database: null),
      );
    });

    test('a URL without a port or database leaves them null', () {
      expect(parseConnectionUrl('postgresql://u:p@pg.internal'), (
        host: 'pg.internal',
        port: null,
        database: null,
      ));
    });

    test('reads an IPv6 host', () {
      expect(parseConnectionUrl('postgresql://u:p@[::1]:5432/app'), (
        host: '::1',
        port: 5432,
        database: 'app',
      ));
    });

    test('a password with @ and / does not leak into the host', () {
      final parts = parseConnectionUrl('postgresql://u:p@ss@pg:5432/app');
      expect(parts.host, 'pg');
      expect(parts.database, 'app');
    });

    test('takes the first host of a multi-host URL', () {
      expect(
        parseConnectionUrl('postgresql://u:p@pg1:5432,pg2:5432/app').host,
        'pg1',
      );
    });

    test('control characters from the server never reach a command', () {
      final parts = parseConnectionUrl(
        'postgresql://u:p@pg\nrm -rf ~:5432/a\rb',
      );
      expect(parts.host, isNull);
      expect(parts.database, isNull);
    });

    test('an absurdly long host is dropped', () {
      expect(
        parseConnectionUrl('postgresql://u:p@${'h' * 300}/app').host,
        isNull,
      );
    });

    test('a port outside 1..65535 is dropped', () {
      expect(parseConnectionUrl('postgresql://u:p@pg:70000/app').port, isNull);
      expect(parseConnectionUrl('postgresql://u:p@pg:0/app').port, isNull);
    });

    test('garbage yields nulls instead of throwing', () {
      expect(parseConnectionUrl(''), (host: null, port: null, database: null));
      expect(parseConnectionUrl('://@').host, isNull);
    });
  });

  group('detectDatabase', () {
    test('uses hosts and port for Cassandra', () {
      final d = detectDatabase('cass001', 'cassandra-database-plugin', {
        'hosts': 'c1.internal, c2.internal',
        'port': 9142,
      });
      expect(d.client, DbClient.cqlsh);
      expect(d.host, 'c1.internal');
      expect(d.port, 9142);
      expect(d.database, isNull);
    });

    test('keeps the connection name when nothing else is readable', () {
      final d = detectDatabase('x', 'custom-plugin', const {});
      expect(d.connection, 'x');
      expect(d.client, isNull);
      expect(d.host, isNull);
    });
  });
}
