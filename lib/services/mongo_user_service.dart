// MongoUserService now delegates to LocalUserService (local JSON storage).
// All existing callers work unchanged.
import 'package:everybite/services/local_user_service.dart';

class MongoUserService {
  MongoUserService._();
  static final MongoUserService instance = MongoUserService._();

  final _local = LocalUserService.instance;

  Future<Map<String, dynamic>?> loginWithEmailPassword({
    required String email,
    required String password,
  }) =>
      _local.loginWithEmailPassword(email: email, password: password);

  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String age,
    required String? gender,
    required String? dietaryPreference,
    required String allergies,
    required String? pregnancyStatus,
  }) =>
      _local.createUser(
        email: email,
        password: password,
        fullName: fullName,
        age: age,
        gender: gender,
        dietaryPreference: dietaryPreference,
        allergies: allergies,
        pregnancyStatus: pregnancyStatus,
      );

  Future<Map<String, dynamic>?> getUserById(String userId) =>
      _local.getUserById(userId);

  Future<bool> userExistsByEmail(String email) =>
      _local.userExistsByEmail(email);

  Future<void> updateUser(String userId, Map<String, dynamic> updates) =>
      _local.updateUser(userId, updates);
}
