// Gerçek bir banka API'sini simüle eden servis
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/transaction.dart';
import '../models/investment_fund.dart';

/// Gerçek bir banka API'sini simüle eden servis.
/// Gerçek uygulamada Open Banking API ile değiştirilecek.
/// Şu an: assets/data/mock_transactions.json okur.
///
/// Kullanım:
/// ```dart
/// final bank = BankMockService();
/// final txList = await bank.fetchRecentTransactions(days: 30);
/// ```
class BankMockService {
  final _uuid = const Uuid();
  final _random = Random();

  List<Transaction>? _cachedTransactions;
  List<InvestmentFund>? _cachedFunds;

  /// Mock JSON'dan tüm işlemleri yükler (önbellek kullanır)
  Future<List<Transaction>> fetchAllTransactions() async {
    if (_cachedTransactions != null) return _cachedTransactions!;

    final jsonStr =
        await rootBundle.loadString('assets/data/mock_transactions.json');
    final list = jsonDecode(jsonStr) as List<dynamic>;

    _cachedTransactions = list.map((json) {
      final map = json as Map<String, dynamic>;
      return Transaction(
        id: map['id'] as String,
        description: map['description'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        category: TransactionCategory.values.byName(
          map['category'] as String? ?? 'other',
        ),
        type: TransactionType.values.byName(
          map['type'] as String? ?? 'need',
        ),
        aiReason: map['aiReason'] as String?,
        isAnalyzed: (map['isAnalyzed'] as int? ?? 0) == 1,
        source: map['source'] as String? ?? 'bank_mock',
        createdAt: DateTime.now(),
      );
    }).toList();

    return _cachedTransactions!;
  }

  /// Son N güne ait işlemleri döndürür
  Future<List<Transaction>> fetchRecentTransactions({int days = 30}) async {
    final all = await fetchAllTransactions();
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return all.where((tx) => tx.date.isAfter(cutoff)).toList();
  }

  /// Belirtilen tarihten sonraki yeni işlemleri döndürür.
  /// Gerçek bankacılık webhook'unu simüle eder.
  Future<List<Transaction>> fetchTransactionsSince(DateTime since) async {
    final all = await fetchAllTransactions();
    return all.where((tx) => tx.date.isAfter(since)).toList();
  }

  /// Yatırım fonlarını yükler
  Future<List<InvestmentFund>> fetchInvestmentFunds() async {
    if (_cachedFunds != null) return _cachedFunds!;

    final jsonStr =
        await rootBundle.loadString('assets/data/investment_funds.json');
    final list = jsonDecode(jsonStr) as List<dynamic>;

    _cachedFunds = list
        .map((json) => InvestmentFund.fromJson(json as Map<String, dynamic>))
        .toList();

    return _cachedFunds!;
  }

  /// Simüle yatırım transferi - sadece kaydeder, gerçek para hareketi yok.
  ///
  /// [fundId] Hedef fon kimliği
  /// [amount] Transfer tutarı (TL)
  /// [reason] Gemini'nin öneri gerekçesi
  /// Returns: Başarılı mı?
  Future<({bool success, String transferId})> executeInvestmentTransfer({
    required String fundId,
    required double amount,
    required String reason,
  }) async {
    // Gerçekçi API simülasyonu için gecikme
    await Future.delayed(
        Duration(milliseconds: AppConstants.kBankMockDelayMs));

    // %95 başarı oranı - gerçek API'lerdeki hata payını simüle eder
    final success = _random.nextDouble() < AppConstants.kTransferSuccessRate;
    final transferId = _uuid.v4();

    return (success: success, transferId: transferId);
  }

  /// Önbelleği temizler - test için kullanışlı
  void clearCache() {
    _cachedTransactions = null;
    _cachedFunds = null;
  }
}
