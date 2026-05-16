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

/// İşlem verisi için tek yetkili veri katmanı.
///
/// UI direkt DbHelper'a erişmez — her zaman bu repository kullanılır.
/// Tüm iş kuralları (validasyon, ID üretimi, flag yönetimi) burada.
class TransactionRepository {
  final DbHelper _db;
  final _uuid = const Uuid();

  TransactionRepository({required DbHelper db}) : _db = db;

  /// Yeni işlem ekler ve Gemini analizi için kuyruğa alır.
  ///
  /// [transaction] Kullanıcının girdiği ham işlem (id boş olabilir)
  /// Returns: Eklenen işlemin ID'si
  Future<String> addTransaction(Transaction transaction) async {
    try {
      // ID yoksa UUID v4 üret
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

      await _db.insertTransaction(txToSave);
      return id;
    } catch (e) {
      throw RepositoryException('İşlem eklenemedi: $e');
    }
  }

  /// İşlemi günceller.
  ///
  /// Kullanıcı kategoriyi değiştirdiyse AI analizi tekrar tetiklenir.
  Future<void> updateTransaction(Transaction updated) async {
    try {
      final existing = await _db.getTransactionById(updated.id);
      if (existing == null) {
        throw RepositoryException('İşlem bulunamadı: ${updated.id}');
      }

      // Kategori değiştiyse yeniden analiz için işaretle
      final needsReanalysis = updated.category != existing.category &&
          updated.source != 'import'; // import'ta kategori kullanıcı seçimi

      final toSave = Transaction(
        id: updated.id,
        description: updated.description,
        amount: updated.amount,
        date: updated.date,
        category: updated.category,
        type: updated.type,
        aiReason: needsReanalysis ? null : updated.aiReason,
        isAnalyzed: needsReanalysis ? false : updated.isAnalyzed,
        source: updated.source,
        createdAt: existing.createdAt,
      );

      await _db.updateTransaction(toSave);
    } catch (e) {
      if (e is RepositoryException) rethrow;
      throw RepositoryException('İşlem güncellenemedi: $e');
    }
  }

  /// İşlemi kalıcı olarak siler — geri alınamaz.
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

  /// Toplu işlem ekler (PDF/Excel import için)
  ///
  /// [transactions] Import edilen işlemler listesi
  /// Returns: Başarıyla eklenen işlem sayısı
  Future<int> addBulk(List<Transaction> transactions) async {
    var addedCount = 0;
    for (final tx in transactions) {
      try {
        await addTransaction(tx);
        addedCount++;
      } catch (_) {
        // Tekil hata toplam import'u durdurmaz
      }
    }
    return addedCount;
  }
}
