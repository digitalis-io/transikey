import '../../../core/models/database_credentials.dart';

abstract class DatabaseRepository {
  Future<List<String>> listRoles();
  Future<DatabaseCredentials> requestCredentials(String role);
}
