import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple local JSON storage for up to ~10 users.
/// Data persists across app restarts via SharedPreferences.
class LocalUserService {
  LocalUserService._();
  static final LocalUserService instance = LocalUserService._();

  static const _key = 'local_users';

  Future<List<Map<String, dynamic>>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _writeAll(List<Map<String, dynamic>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(users));
  }

  String _newId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final r = Random().nextInt(1 << 20);
    return '${ts}_$r';
  }

  Future<Map<String, dynamic>?> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final users = await _readAll();
    try {
      return users.firstWhere(
        (u) =>
            u['email'] == email.trim().toLowerCase() &&
            u['password'] == password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> createUser({
    required String email,
    required String password,
    required String fullName,
    required String age,
    required String? gender,
    required String? dietaryPreference,
    required String allergies,
    required String? pregnancyStatus,
  }) async {
    final users = await _readAll();
    final normalizedEmail = email.trim().toLowerCase();

    final exists = users.any((u) => u['email'] == normalizedEmail);
    if (exists) throw Exception('email-already-in-use');

    final userId = _newId();
    final now = DateTime.now().toUtc().toIso8601String();

    users.add({
      'user_id': userId,
      'email': normalizedEmail,
      'password': password,
      'full_name': fullName,
      'profilepic': '',
      'gender': gender,
      'pregnancy_status': pregnancyStatus,
      'age': age,
      'dietary_preference': dietaryPreference,
      'allergies': allergies,
      'created_at': now,
      'updated_at': now,
    });

    await _writeAll(users);
    return userId;
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    final users = await _readAll();
    try {
      return users.firstWhere((u) => u['user_id'] == userId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> userExistsByEmail(String email) async {
    final users = await _readAll();
    return users.any((u) => u['email'] == email.trim().toLowerCase());
  }

  Future<void> updateUser(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final users = await _readAll();
    final idx = users.indexWhere((u) => u['user_id'] == userId);
    if (idx == -1) throw Exception('User not found');

    users[idx] = {
      ...users[idx],
      ...updates,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await _writeAll(users);
  }
}
