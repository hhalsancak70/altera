// İşlem verisi için tek yetkili kaynak (Single Source of Truth)
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../models/transaction.dart';

/// Repository hatası — kullanıcıya gösterilecek mesaj içerir
class RepositoryException implements Exception {
  final String message;
  const RepositoryException(this.message);

  @override
  String toString() => 'RepositoryException: $message';
}

/// Toplu import sonucu
class BulkImportResult {
  final int added;
  final int skipped;
  final int errors;

  const BulkImportResult({
    required this.added,
    required this.skipped,
    required this.errors,
  });

  int get total => added + skipped + errors;
}

/// İşlem verisi için tek yetkili veri katmanı.
class TransactionRepository {
  final DbHelper _db;
  final _uuid = const Uuid();

  TransactionRepository({required DbHelper db}) : _db = db;

  /// Yeni işlem ekler.
  Future<String> addTransaction(Transaction transaction) async {
    try {
      final id = transaction.id.isEmpty ? _uuid.v4() : transaction.id;
      final now = DateTime.now();

      final txToSave = Transaction(
        id: id,
        description: transaction.description,
        amount: transaction.amount,
        date: transaction.date,
        category: transaction.category,
        type: transaction.type,
        aiReason: transaction.aiReason,
        isAnalyzed: transaction.isAnalyzed,
        source: transaction.source.isEmpty ? 'manual' : transaction.source,
        createdAt: now,
      );

      await _db.insertTransaction(txToSave); // dönüş bool; manuel eklemede duplicate nadirdir
      return id;
    } catch (e) {
      throw RepositoryException('İşlem eklenemedi: $e');
    }
  }

  /// İşlemi günceller.
  ///
  /// [isManualEdit] true ise kullanıcı kategoriyi elle değiştirmiş demektir;
  /// bu durumda AI yeniden analiz tetiklenmez ve isAnalyzed=true kalır.
  Future<void> updateTransaction(
    Transaction updated, {
    bool isManualEdit = false,
  }) async {
    try {
      final existing = await _db.getTransactionById(updated.id);
      if (existing == null) {
        throw RepositoryException('İşlem bulunamadı: ${updated.id}');
      }

      // Manuel düzenleme → AI override yok
      // Programatik güncelleme ve kategori değiştiyse → yeniden analiz
      final needsReanalysis =
          !isManualEdit &&
          updated.category != existing.category &&
          updated.description == existing.description &&
          updated.amount == existing.amount;

      final toSave = Transaction(
        id: updated.id,
        description: updated.description,
        amount: updated.amount,
        date: updated.date,
        category: updated.category,
        type: updated.type,
        aiReason:
            isManualEdit
                ? existing.aiReason
                : (needsReanalysis ? null : updated.aiReason),
        isAnalyzed:
            isManualEdit
                ? true
                : (needsReanalysis ? false : updated.isAnalyzed),
        source: updated.source,
        createdAt: existing.createdAt,
      );

      await _db.updateTransaction(toSave);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('İşlem güncellenemedi: $e');
    }
  }

  /// İşlemi kalıcı olarak siler.
  Future<void> deleteTransaction(String id) async {
    try {
      final exists = await _db.getTransactionById(id);
      if (exists == null) {
        throw RepositoryException('İşlem bulunamadı: $id');
      }
      await _db.deleteTransaction(id);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('İşlem silinemedi: $e');
    }
  }

  /// ID'ye göre tek işlem döndürür
  Future<Transaction?> getById(String id) async {
    try {
      return await _db.getTransactionById(id);
    } catch (e) {
      throw RepositoryException('İşlem okunamadı: $e');
    }
  }

  /// Tüm işlemleri döndürür (filtrelenebilir)
  Future<List<Transaction>> getAll({
    DateTime? fromDate,
    TransactionCategory? category,
    int? limit,
  }) async {
    try {
      return await _db.getTransactions(
        fromDate: fromDate,
        category: category,
        limit: limit,
      );
    } catch (e) {
      throw RepositoryException('İşlemler okunamadı: $e');
    }
  }

  /// Bu ayın işlemlerini döndürür
  Future<List<Transaction>> getCurrentMonth() async {
    final now = DateTime.now();
    return getAll(fromDate: DateTime(now.year, now.month, 1));
  }

  /// Toplu işlem ekler, duplicate olanları atlar.
  /// Fingerprint: DbHelper.buildFingerprint kullanır (DB ile birebir aynı format).
  Future<BulkImportResult> addBulk(List<Transaction> transactions) async {
    int added = 0;
    int skipped = 0;
    int errors = 0;

    for (final tx in transactions) {
      try {
        final fingerprint = DbHelper.buildFingerprint(
          tx.date,
          tx.amount,
          tx.description,
          tx.type,
        );
        final isDuplicate = await _db.transactionFingerprintExists(fingerprint);
        if (isDuplicate) {
          skipped++;
          continue;
        }
        // insertTransaction da fingerprint'i DB'ye yazar; çift kontrol duplicate'i garantiler
        final inserted = await _db.insertTransaction(tx);
        if (inserted) {
          added++;
        } else {
          skipped++;
        }
      } catch (_) {
        errors++;
      }
    }

    return BulkImportResult(added: added, skipped: skipped, errors: errors);
  }
}
