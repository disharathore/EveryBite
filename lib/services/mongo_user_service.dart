import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:mongo_dart/mongo_dart.dart';

class MongoUserService {
  MongoUserService._();

  static final MongoUserService instance = MongoUserService._();

  Db? _db;
  DbCollection? _users;

  String get _dbName => dotenv.env['MONGO_DB_NAME'] ?? 'everybite';

  String get _usersCollection =>
      dotenv.env['MONGO_USERS_COLLECTION'] ?? 'users';

  String get _dataApiUrl => dotenv.env['MONGO_DATA_API_URL'] ?? '';

  String get _dataApiKey => dotenv.env['MONGO_DATA_API_KEY'] ?? '';

  String get _dataSource => dotenv.env['MONGO_DATA_SOURCE'] ?? 'Cluster0';

  Future<void> _ensureConnected() async {
    if (_db != null && _db!.isConnected && _users != null) {
      return;
    }

    final mongoUri = dotenv.env['MONGO_URI'] ?? '';
    final dbName = _dbName;
    final usersCollection = _usersCollection;

    if (mongoUri.isEmpty) {
      throw Exception('MONGO_URI is missing in .env');
    }

    final uri = Uri.parse(mongoUri);
    final hasDbInPath = uri.pathSegments.isNotEmpty && uri.pathSegments.first.isNotEmpty;
    final resolvedUri = hasDbInPath ? mongoUri : '$mongoUri/$dbName';

    _db = await Db.create(resolvedUri);
    await _db!.open();
    _users = _db!.collection(usersCollection);
  }

  Future<Map<String, dynamic>> _callDataApi(
    String action,
    Map<String, dynamic> payload,
  ) async {
    if (_dataApiUrl.isEmpty || _dataApiKey.isEmpty) {
      throw Exception(
        'Web requires MONGO_DATA_API_URL and MONGO_DATA_API_KEY in .env',
      );
    }

    final response = await http.post(
      Uri.parse('$_dataApiUrl/action/$action'),
      headers: {
        'Content-Type': 'application/json',
        'api-key': _dataApiKey,
      },
      body: jsonEncode({
        'dataSource': _dataSource,
        'database': _dbName,
        'collection': _usersCollection,
        ...payload,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Mongo Data API failed: ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _generateUserId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1 << 20);
    return '${now}_$random';
  }

  Future<Map<String, dynamic>?> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) {
      final response = await _callDataApi('findOne', {
        'filter': {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      });
      final doc = response['document'];
      return doc is Map<String, dynamic> ? doc : null;
    }

    await _ensureConnected();

    return _users!.findOne(where
      ..eq('email', email.trim().toLowerCase())
      ..eq('password', password));
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
    if (kIsWeb) {
      final normalizedEmail = email.trim().toLowerCase();
      final existing = await _callDataApi('findOne', {
        'filter': {'email': normalizedEmail},
      });
      if (existing['document'] != null) {
        throw Exception('email-already-in-use');
      }

      final userId = _generateUserId();
      await _callDataApi('insertOne', {
        'document': {
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
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      });
      return userId;
    }

    await _ensureConnected();

    final normalizedEmail = email.trim().toLowerCase();
    final existing = await _users!.findOne(where.eq('email', normalizedEmail));
    if (existing != null) {
      throw Exception('email-already-in-use');
    }

    final userId = _generateUserId();

    await _users!.insertOne({
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
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    return userId;
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    if (kIsWeb) {
      final response = await _callDataApi('findOne', {
        'filter': {'user_id': userId},
      });
      final doc = response['document'];
      return doc is Map<String, dynamic> ? doc : null;
    }

    await _ensureConnected();
    return _users!.findOne(where.eq('user_id', userId));
  }

  Future<bool> userExistsByEmail(String email) async {
    if (kIsWeb) {
      final response = await _callDataApi('findOne', {
        'filter': {'email': email.trim().toLowerCase()},
      });
      return response['document'] != null;
    }

    await _ensureConnected();
    final user =
        await _users!.findOne(where.eq('email', email.trim().toLowerCase()));
    return user != null;
  }

  Future<void> updateUser(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    if (kIsWeb) {
      final safeUpdates = Map<String, dynamic>.from(updates);
      safeUpdates['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _callDataApi('updateOne', {
        'filter': {'user_id': userId},
        'update': {
          r'$set': safeUpdates,
        },
      });
      return;
    }

    await _ensureConnected();

    final safeUpdates = Map<String, dynamic>.from(updates);
    safeUpdates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final modifier = modify;
    safeUpdates.forEach((key, value) {
      modifier.set(key, value);
    });

    await _users!.updateOne(
      where.eq('user_id', userId),
      modifier,
    );
  }
}
