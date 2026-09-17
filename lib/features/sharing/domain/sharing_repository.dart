import '../../../core/models/wrapped_secret.dart';

abstract class SharingRepository {
  Future<WrappedSecret> wrap(Map<String, dynamic> payload, Duration ttl);
  Future<UnwrappedSecret> unwrap(String wrappingToken);

  Future<void> cubbyholeStore(String path, Map<String, dynamic> data);
  Future<Map<String, dynamic>> cubbyholeRetrieve(String path);
  Future<void> cubbyholeDelete(String path);
  Future<List<String>> cubbyholeList();
}

/// Outcome of the last secret-sharing operation.
sealed class SharingResult {
  const SharingResult();
}

class WrapResult extends SharingResult {
  const WrapResult(this.secret);
  final WrappedSecret secret;
}

class UnwrapResult extends SharingResult {
  const UnwrapResult(this.secret);
  final UnwrappedSecret secret;
}

class CubbyholeReadResult extends SharingResult {
  const CubbyholeReadResult(this.path, this.data);
  final String path;
  final Map<String, dynamic> data;
}

class CubbyholeChangedResult extends SharingResult {
  const CubbyholeChangedResult(this.message);
  final String message;
}
