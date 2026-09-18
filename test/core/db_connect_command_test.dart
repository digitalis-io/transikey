import 'package:flutter_test/flutter_test.dart';
import 'package:transikey/core/utils/db_connect_command.dart';

void main() {
  const pg = DbTarget(
    client: DbClient.psql,
    host: '127.0.0.1',
    port: 5432,
    database: 'app',
  );
  const my = DbTarget(
    client: DbClient.mysql,
    host: 'db.internal',
    port: 3306,
    database: 'shop',
  );

  test('psql command passes the password through the environment', () {
    expect(
      dbConnectCommand(pg, 'v-token-ro', 'p@ss'),
      "PGPASSWORD='p@ss' psql -h '127.0.0.1' -p 5432 -U 'v-token-ro' -d 'app'",
    );
  });

  test('mysql command uses MYSQL_PWD and -P for the port', () {
    expect(
      dbConnectCommand(my, 'u', 'pw'),
      "MYSQL_PWD='pw' mysql -h 'db.internal' -P 3306 -u 'u' 'shop'",
    );
  });

  test('a single quote in the password cannot break out of the quoting', () {
    expect(
      dbConnectCommand(pg, 'u', "a'b"),
      startsWith("PGPASSWORD='a'\\''b' psql"),
    );
  });

  test('whitespace around host and database is ignored', () {
    const t = DbTarget(
      client: DbClient.psql,
      host: ' 10.0.0.2 ',
      port: 5433,
      database: ' app ',
    );
    expect(dbConnectCommand(t, 'u', 'p'), contains("-h '10.0.0.2' -p 5433"));
    expect(dbConnectCommand(t, 'u', 'p'), endsWith("-d 'app'"));
  });

  test('the URI percent-encodes user and password', () {
    expect(
      dbConnectUri(pg, 'v-token', 'p@ss/w:ord'),
      'postgresql://v-token:p%40ss%2Fw%3Aord@127.0.0.1:5432/app',
    );
    expect(dbConnectUri(my, 'u', 'p'), 'mysql://u:p@db.internal:3306/shop');
  });
}
