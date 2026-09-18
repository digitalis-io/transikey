import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:transikey/core/api/vault_api_client.dart';

class FakeSharingServer extends Mock implements VaultApiClient {}

/// State shared by the secret sharing steps of one scenario.
class SharingWorld {
  static late FakeSharingServer server;
  static late ProviderContainer container;
}
