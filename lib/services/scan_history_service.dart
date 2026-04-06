import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanHistoryService {
  ScanHistoryService._();
  static final ScanHistoryService instance = ScanHistoryService._();

  static const _key = 'scan_history';
  static const _maxEntries = 50;

  Future<List<Map<String, dynamic>>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> addScan({
    required String productName,
    required String nutriScore,
    required String ecoScore,
    required double sugar,
    required double proteins,
    required double fats,
    required double sodium,
    required String analysisResult,
    String source = 'barcode', // 'barcode' or 'ocr'
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();

    final entry = {
      'product_name': productName,
      'nutri_score': nutriScore,
      'eco_score': ecoScore,
      'sugar': sugar,
      'proteins': proteins,
      'fats': fats,
      'sodium': sodium,
      'analysis_result': analysisResult,
      'source': source,
      'scanned_at': DateTime.now().toIso8601String(),
    };

    history.insert(0, entry);

    // Keep only last 50 entries
    final trimmed = history.take(_maxEntries).toList();
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // Returns today's scans only
  Future<List<Map<String, dynamic>>> getTodayScans() async {
    final all = await getHistory();
    final today = DateTime.now();
    return all.where((e) {
      final scannedAt = DateTime.tryParse(e['scanned_at'] ?? '');
      if (scannedAt == null) return false;
      return scannedAt.year == today.year &&
          scannedAt.month == today.month &&
          scannedAt.day == today.day;
    }).toList();
  }

  // Returns totals for today's scans
  Future<Map<String, double>> getTodayTotals() async {
    final todayScans = await getTodayScans();
    double totalSugar = 0, totalProteins = 0, totalFats = 0, totalSodium = 0;
    for (final scan in todayScans) {
      totalSugar += (scan['sugar'] as num? ?? 0).toDouble();
      totalProteins += (scan['proteins'] as num? ?? 0).toDouble();
      totalFats += (scan['fats'] as num? ?? 0).toDouble();
      totalSodium += (scan['sodium'] as num? ?? 0).toDouble();
    }
    return {
      'sugar': totalSugar,
      'proteins': totalProteins,
      'fats': totalFats,
      'sodium': totalSodium,
    };
  }
}