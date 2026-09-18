import '../../../core/models/database_credentials.dart';
import '../../../core/utils/db_target_detection.dart';

abstract class DatabaseRepository {
  /// Database mounts the server reveals to this token. Empty when it
  /// reveals none.
  Future<List<String>> discoverMounts();
  Future<List<String>> listRoles(String mount);
  Future<DatabaseCredentials> requestCredentials(String mount, String role);
  Future<DetectedDatabase> describeRole(String mount, String role);
}
