// Aylık döngü ve istatistik arşivleme servisi
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../database/hive_boxes.dart';
import '../models/monthly_archive.dart';
import '../models/transaction.dart';
import '../services/notification_service.dart';

/// Döngü kontrol sonucu
sealed class CycleCheckResult {
  const CycleCheckResult();
}

/// Bu ay zaten arşivlendi
class CycleAlreadyDone extends CycleCheckResult {
  const CycleAlreadyDone();
}

/// Arşivlenecek ayda işlem yoktu — arşiv oluşturulmadı
class CycleSkipped extends CycleCheckResult {
  const CycleSkipped();
}

/// Döngü günü henüz gelmedi
class CycleNotYet extends CycleCheckResult {
  final DateTime nextCycleDate;
  const CycleNotYet({required this.nextCycleDate});
}

/// Arşivleme başarıyla tamamlandı
class CycleCompleted extends CycleCheckResult {
  final MonthlyArchive archive;
  const CycleCompleted({required this.archive});
}

/// Aylık döngü ve arşivleme servisi.
///
/// Uygulama her açılışında [checkAndRunIfNeeded] çağrılır.
/// Kullanıcının seçtiği gün (1-28) geldiğinde:
///   1. Geçen ayın istatistikleri kalıcı olarak arşivlenir
///   2. Bütçe harcama sayaçları sıfırlanır (limitler korunur)
///   3. Kullanıcıya özet bildirimi gönderilir
///
/// Uygulama o gün açılmazsa bir sonraki açılışta tetiklenir.
class CycleService {
  static const _hiveKeyLastArchived = 'last_archived_month';
  static const _hiveKeyCycleDay = 'cycle_day';
  static const int defaultCycleDay = 1;

  final DbHelper _db;
  final NotificationService _notifications;
  final _uuid = const Uuid();

  CycleService({
    required DbHelper db,
    required NotificationService notifications,
  }) : _db = db,
       _notifications = notifications;

  /// Kullanıcının seçtiği aylık döngü günü (1-28)
  int get cycleDay {
    final box = Hive.box<String>(HiveBoxes.agentState);
    return int.tryParse(box.get(_hiveKeyCycleDay) ?? '') ?? defaultCycleDay;
  }

  /// Döngü gününü günceller
  Future<void> setCycleDay(int day) async {
    final clamped = day.clamp(1, 28);
    final box = Hive.box<String>(HiveBoxes.agentState);
    await box.put(_hiveKeyCycleDay, clamped.toString());
  }

  /// Uygulama açılışında çağrılır — gerekiyorsa arşivler.
  Future<CycleCheckResult> checkAndRunIfNeeded() async {
    final today = DateTime.now();
    final day = cycleDay;

    // Son arşivleme tarihini oku
    final box = Hive.box<String>(HiveBoxes.agentState);
    final lastArchivedStr = box.get(_hiveKeyLastArchived);

    if (lastArchivedStr != null) {
      final lastArchived = DateTime.parse(lastArchivedStr);
      // Bu ay zaten arşivlendi mi?
      if (lastArchived.year == today.year &&
          lastArchived.month == today.month) {
        return const CycleAlreadyDone();
      }
    }

    // Döngü günü geldi mi?
    if (today.day < day) {
      return CycleNotYet(nextCycleDate: DateTime(today.year, today.month, day));
    }

    // Arşivleme zamanı geldi
    return await _archiveAndReset(today);
  }

  /// Geçen ayın verilerini arşivler ve yeni aya hazırlanır.
  Future<CycleCheckResult> _archiveAndReset(DateTime now) async {
    // Arşivlenecek ay: bir önceki ay
    final archiveMonth =
        now.month == 1
            ? DateTime(now.year - 1, 12)
            : DateTime(now.year, now.month - 1);

    // Zaten arşivlenmiş mi?
    final exists = await _db.monthlyArchiveExists(
      archiveMonth.year,
      archiveMonth.month,
    );
    if (exists) {
      // Arşiv var ama Hive'da işaretlenmemiş — düzelt
      await _markArchived(now);
      final archives = await _db.getMonthlyArchives();
      final map = archives.firstWhere(
        (m) =>
            m['year'] == archiveMonth.year && m['month'] == archiveMonth.month,
      );
      return CycleCompleted(archive: MonthlyArchive.fromDbMap(map));
    }

    // Geçen ayın işlemlerini topla
    final transactions = await _db.getTransactionsForMonth(archiveMonth);

    // İşlem yoksa boş arşiv oluşturma — sadece döngüyü tamamlandı olarak işaretle
    if (transactions.isEmpty) {
      await _markArchived(now);
      return const CycleSkipped();
    }

    final income = transactions
        .where((t) => t.amount > 0)
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.amount < 0)
        .fold(0.0, (s, t) => s + t.amount.abs());

    // Kategori harcamaları
    final categorySpending = <String, double>{};
    for (final tx in transactions) {
      if (tx.amount < 0) {
        categorySpending[tx.category.name] =
            (categorySpending[tx.category.name] ?? 0) + tx.amount.abs();
      }
    }

    // En çok harcanan kategori
    String? topCategory;
    if (categorySpending.isNotEmpty) {
      topCategory =
          categorySpending.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
    }

    final archive = MonthlyArchive(
      id: _uuid.v4(),
      year: archiveMonth.year,
      month: archiveMonth.month,
      totalIncome: income,
      totalExpense: expense,
      totalSavings: income - expense,
      categorySpending: categorySpending,
      transactionCount: transactions.length,
      topCategory: topCategory,
      archivedAt: now,
    );

    // Arşivi kaydet
    await _db.insertMonthlyArchive(archive.toDbMap());

    // Bütçe harcama sayaçlarını sıfırla (limitler korunur)
    // Sıfırlama: bütçe kaydında `spent_amount` sütunu olsaydı burada sıfırlanırdı.
    // Şu an harcamalar transactions tablosundan dinamik hesaplanıyor — sıfırlama gerekmez.

    // Son arşivleme tarihini güncelle
    await _markArchived(now);

    // Özet bildirimi gönder
    try {
      await _notifications.showMonthlySummary(
        month: archiveMonth,
        totalSavings: income - expense,
        topCategory:
            topCategory != null ? _categoryDisplayName(topCategory) : null,
      );
    } catch (_) {
      // Bildirim başarısız olursa arşivleme yine de tamamlandı
    }

    return CycleCompleted(archive: archive);
  }

  /// Son arşivleme tarihini Hive'a yazar
  Future<void> _markArchived(DateTime when) async {
    final box = Hive.box<String>(HiveBoxes.agentState);
    await box.put(_hiveKeyLastArchived, when.toIso8601String());
  }

  String _categoryDisplayName(String categoryName) {
    try {
      return TransactionCategory.values.byName(categoryName).displayNameTr;
    } catch (_) {
      return categoryName;
    }
  }

  /// Tüm arşivleri döndürür (en yeni başta)
  Future<List<MonthlyArchive>> getAllArchives() async {
    final maps = await _db.getMonthlyArchives();
    return maps.map(MonthlyArchive.fromDbMap).toList();
  }
}
