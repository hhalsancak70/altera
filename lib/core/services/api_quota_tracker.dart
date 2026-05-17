// Gemini API günlük çağrı sayacı — Hive'da tarihli sayaç tutar
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../database/hive_boxes.dart';

/// Hive'da tarih bazlı API çağrı sayacı.
/// Format: { "2026-05-17": 47, "2026-05-16": 312 }
class ApiQuotaTracker {
  ApiQuotaTracker._();

  static const _hiveKey = 'api_call_counts';
  static const _failedHiveKey = 'api_call_failed_counts';
  static const _lastErrorHiveKey = 'api_last_error';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Bugünkü çağrı sayısını 1 artırır
  static Future<void> increment() async {
    final box = Hive.box<dynamic>(HiveBoxes.settings);
    final counts = _readCounts(box);
    final today = _todayKey();
    counts[today] = (counts[today] ?? 0) + 1;
    _cleanOldEntries(counts);
    await box.put(_hiveKey, counts);
  }

  /// Bugünkü toplam çağrı sayısı
  static int todayCount() {
    final box = Hive.box<dynamic>(HiveBoxes.settings);
    final counts = _readCounts(box);
    return counts[_todayKey()] ?? 0;
  }

  /// Başarısız çağrıyı sayar + son hatayı saklar (debug için)
  static Future<void> incrementFailed(String errorMessage) async {
    final box = Hive.box<dynamic>(HiveBoxes.settings);
    final counts = _readFailedCounts(box);
    final today = _todayKey();
    counts[today] = (counts[today] ?? 0) + 1;
    _cleanOldEntries(counts);
    await box.put(_failedHiveKey, counts);
    // Son hatanın ilk 200 karakteri
    final trimmed = errorMessage.length > 200
        ? '${errorMessage.substring(0, 200)}...'
        : errorMessage;
    await box.put(_lastErrorHiveKey, trimmed);
  }

  /// Bugünkü başarısız çağrı sayısı
  static int todayFailedCount() {
    final box = Hive.box<dynamic>(HiveBoxes.settings);
    final counts = _readFailedCounts(box);
    return counts[_todayKey()] ?? 0;
  }

  /// Son hata mesajı (debug için)
  static String? lastError() {
    final box = Hive.box<dynamic>(HiveBoxes.settings);
    return box.get(_lastErrorHiveKey) as String?;
  }

  /// Sayaçları ve son hatayı sıfırla
  static Future<void> reset() async {
    final box = Hive.box<dynamic>(HiveBoxes.settings);
    await box.delete(_hiveKey);
    await box.delete(_failedHiveKey);
    await box.delete(_lastErrorHiveKey);
  }

  static Map<String, int> _readFailedCounts(Box<dynamic> box) {
    final raw = box.get(_failedHiveKey);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return <String, int>{};
  }

  /// Günlük limit aşıldı mı?
  static bool isLimitReached() => todayCount() >= AppConstants.kDailyApiCallLimit;

  /// Uyarı eşiğine ulaşıldı mı? (%80)
  static bool isNearLimit() =>
      todayCount() >= AppConstants.kDailyApiCallWarnThreshold;

  /// Kalan çağrı sayısı
  static int remaining() =>
      (AppConstants.kDailyApiCallLimit - todayCount()).clamp(0, AppConstants.kDailyApiCallLimit);

  static Map<String, int> _readCounts(Box<dynamic> box) {
    final raw = box.get(_hiveKey);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }
    return <String, int>{};
  }

  /// 7 günden eski kayıtları sil
  static void _cleanOldEntries(Map<String, int> counts) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    counts.removeWhere((dateStr, _) {
      final parts = dateStr.split('-');
      if (parts.length != 3) return true;
      try {
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        return date.isBefore(cutoff);
      } catch (_) {
        return true;
      }
    });
  }
}
