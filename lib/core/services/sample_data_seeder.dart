// Test için gerçekçi örnek veri yükleyici
import 'package:uuid/uuid.dart';

import '../database/db_helper.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

/// Test amaçlı örnek işlem ve bütçe yükleyici.
/// Tüm işlemler manuel girişle aynı mantıkta — kategori önceden doğru atanmış,
/// `isAnalyzed=true` olarak işaretli. Gemini analizine gerek yok.
class SampleDataSeeder {
  SampleDataSeeder._();

  static const _uuid = Uuid();

  /// Son 30 güne yayılmış 25 gerçekçi Türkçe işlem + birkaç bütçe yükler.
  /// İşlemler önceden kategorize edilmiş — Gemini İçgörü için hazır veri.
  static Future<({int transactions, int budgets})> seed(DbHelper db) async {
    final now = DateTime.now();
    final samples = _buildSampleTransactions(now);

    for (final tx in samples) {
      await db.insertTransaction(tx);
    }

    final budgets = _buildSampleBudgets(now);
    for (final b in budgets) {
      await db.upsertBudget(b);
    }

    return (transactions: samples.length, budgets: budgets.length);
  }

  static List<Transaction> _buildSampleTransactions(DateTime now) {
    // (açıklama, tutar, gün önce, kategori, tür)
    final entries = <(String, double, int, TransactionCategory, TransactionType)>[
      // Gelir
      ('Maaş - Tekno A.Ş.', 32000.0, 1, TransactionCategory.income, TransactionType.income),
      ('Freelance proje ödemesi', 4500.0, 8, TransactionCategory.income, TransactionType.income),

      // Market (zorunlu)
      ('Migros market alışverişi', -850.50, 0, TransactionCategory.market, TransactionType.need),
      ('A101 hızlı alışveriş', -245.30, 2, TransactionCategory.market, TransactionType.need),
      ('BİM haftalık market', -678.90, 5, TransactionCategory.market, TransactionType.need),
      ('Şok Market', -310.00, 9, TransactionCategory.market, TransactionType.need),
      ('Carrefour market', -1240.75, 14, TransactionCategory.market, TransactionType.need),
      ('Migros online sipariş', -560.20, 21, TransactionCategory.market, TransactionType.need),

      // Restoran / kafe (istek)
      ('Starbucks kahve', -185.00, 0, TransactionCategory.restaurant, TransactionType.want),
      ('Burger King menü', -220.00, 3, TransactionCategory.restaurant, TransactionType.want),
      ('Restoran akşam yemeği', -780.00, 6, TransactionCategory.restaurant, TransactionType.want),
      ('Kahve Dünyası', -95.50, 11, TransactionCategory.restaurant, TransactionType.want),
      ('McDonalds drive-thru', -165.00, 17, TransactionCategory.restaurant, TransactionType.want),

      // Ulaşım (karışık)
      ('İstanbulkart dolum', -200.00, 1, TransactionCategory.transport, TransactionType.need),
      ('Uber ride', -85.40, 4, TransactionCategory.transport, TransactionType.want),
      ('Shell akaryakıt', -1850.00, 7, TransactionCategory.transport, TransactionType.need),
      ('BiTaksi', -120.00, 12, TransactionCategory.transport, TransactionType.want),
      ('Opet benzin', -2100.00, 19, TransactionCategory.transport, TransactionType.need),

      // Faturalar (zorunlu)
      ('Türk Telekom internet', -349.90, 2, TransactionCategory.bill, TransactionType.need),
      ('Turkcell hat ödemesi', -189.00, 10, TransactionCategory.bill, TransactionType.need),
      ('İSKİ su faturası', -127.40, 15, TransactionCategory.bill, TransactionType.need),
      ('Elektrik faturası BEDAŞ', -456.80, 22, TransactionCategory.bill, TransactionType.need),

      // Eğlence / dijital (istek)
      ('Netflix aboneliği', -149.99, 8, TransactionCategory.entertainment, TransactionType.want),
      ('Spotify Premium', -59.99, 13, TransactionCategory.entertainment, TransactionType.want),
      ('Steam oyun satın alma', -340.00, 18, TransactionCategory.entertainment, TransactionType.want),

      // Giyim (istek)
      ('LCW alışveriş', -890.00, 4, TransactionCategory.clothing, TransactionType.want),
      ('Zara online sipariş', -1250.00, 16, TransactionCategory.clothing, TransactionType.want),

      // Sağlık (zorunlu)
      ('Eczane - ilaç', -245.00, 6, TransactionCategory.health, TransactionType.need),
      ('Doktor muayene', -800.00, 20, TransactionCategory.health, TransactionType.need),
    ];

    return entries.map((e) {
      final date = now.subtract(Duration(days: e.$3));
      return Transaction(
        id: _uuid.v4(),
        description: e.$1,
        amount: e.$2,
        date: date,
        category: e.$4,
        type: e.$5,
        aiReason: 'Örnek veri — manuel kategorize',
        isAnalyzed: true, // Kategori zaten atanmış
        source: 'sample',
        createdAt: date,
      );
    }).toList();
  }

  static List<Budget> _buildSampleBudgets(DateTime now) {
    final month = DateTime(now.year, now.month);
    final categories = {
      TransactionCategory.market: 3500.0,
      TransactionCategory.restaurant: 1500.0,
      TransactionCategory.transport: 5000.0,
      TransactionCategory.bill: 1500.0,
      TransactionCategory.entertainment: 600.0,
      TransactionCategory.clothing: 2000.0,
    };
    return categories.entries
        .map((e) => Budget(
              id: _uuid.v4(),
              category: e.key,
              limitAmount: e.value,
              spentAmount: 0,
              month: month,
            ))
        .toList();
  }
}
