import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/api/vault_api_client.dart';

class FakeDatabaseServer extends Mock implements VaultApiClient {}

/// State shared by the database steps of one scenario.
class DatabaseWorld {
  static late FakeDatabaseServer server;

  /// Mount path -> engine type, as the server reveals them.
  static late Map<String, String> mounts;
}
