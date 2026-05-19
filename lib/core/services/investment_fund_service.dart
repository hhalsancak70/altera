// Yatırım fonu verileri ve simüle transfer servisi
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/investment_fund.dart';

/// Yatırım transferi simülasyon sonucu
class TransferResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;

  const TransferResult.success({required String transactionId})
    : success = true,
      transactionId = transactionId,
      errorMessage = null;

  const TransferResult.failure({required String errorMessage})
    : success = false,
      transactionId = null,
      errorMessage = errorMessage;
}

/// Yatırım fonu verileri ve simüle transfer servisi.
///
/// Fon listesi assets/data/investment_funds.json'dan okunur.
/// Transfer işlemi simüle edilir — gerçek aracı kurum API'si entegrasyonu
/// bu sınıftaki executeInvestmentTransfer metodu üzerinden yapılacak.
class InvestmentFundService {
  final _uuid = const Uuid();
  final _random = Random();
  List<InvestmentFund>? _cachedFunds;

  /// Mevcut yatırım fonlarını döndürür (önbellek kullanır).
  Future<List<InvestmentFund>> fetchInvestmentFunds() async {
    if (_cachedFunds != null) return _cachedFunds!;

    final jsonStr = await rootBundle.loadString(
      'assets/data/investment_funds.json',
    );
    final list = jsonDecode(jsonStr) as List<dynamic>;

    _cachedFunds =
        list.map((json) {
          final map = json as Map<String, dynamic>;
          return InvestmentFund.fromJson(map);
        }).toList();

    return _cachedFunds!;
  }

  /// Yatırım transferi gerçekleştirir (şu an simüle edilmektedir).
  ///
  /// [fundId] Hedef fonun ID'si
  /// [amount] Transfer tutarı (TL)
  /// [reason] Gemini tarafından üretilen gerekçe
  ///
  /// Gerçek aracı kurum API entegrasyonunda bu metot güncellenir.
  Future<TransferResult> executeInvestmentTransfer({
    required String fundId,
    required double amount,
    required String reason,
  }) async {
    // Ağ gecikmesini simüle et (300-800ms arası)
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(500)));

    // %95 başarı oranı — gerçek API'yi simüle eder
    if (_random.nextDouble() < 0.95) {
      return TransferResult.success(transactionId: _uuid.v4());
    }

    return const TransferResult.failure(
      errorMessage: 'Simüle transfer başarısız — gerçek API\'de yeniden dene',
    );
  }
}
