// ALTERA Ajan 1: Veri Toplama Ajanı
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../database/hive_boxes.dart';
import '../models/agent_log_entry.dart';
import '../services/bank_mock_service.dart';

/// Veri toplama sonucu
class DataCollectionResult {
  final int newTransactionsCount;
  final int durationMs;

  const DataCollectionResult({
    required this.newTransactionsCount,
    required this.durationMs,
  });
}

/// ALTERA Ajan 1: Veri Toplama Ajanı
///
/// Sorumluluğu: Banka ve fatura kaynaklarından ham işlem verisi toplar,
/// yapılandırılmış formata dönüştürür ve veritabanına yazar.
///
/// Girdi: Hiç (dış tetikleyici - Orchestrator çağırır)
/// Çıktı: Yeni eklenen işlem sayısı
///
/// Kullanım:
/// ```dart
/// final agent = DataCollectionAgent(bankService: ..., dbHelper: ...);
/// final result = await agent.run(logCallback: orchestrator.log);
/// ```
class DataCollectionAgent {
  final BankMockService _bankService;
  final DbHelper _dbHelper;
  DataCollectionAgent({
    required BankMockService bankService,
    required DbHelper dbHelper,
  })  : _bankService = bankService,
        _dbHelper = dbHelper;

  /// Ajan çalışma döngüsü - Orchestrator bu metodu çağırır.
  ///
  /// [logCallback] Her adımı Orchestrator'a bildiren callback
  /// Returns: Yeni eklenen işlem sayısı ve süre
  Future<DataCollectionResult> run({
    required void Function(String agent, String message, LogLevel level)
        logCallback,
  }) async {
    final stopwatch = Stopwatch()..start();
    logCallback('data_collection', 'Veri toplama başladı', LogLevel.info);

    try {
      // Adım 1: Son çalışma zamanını Hive'dan oku
      final agentBox = Hive.box<String>(HiveBoxes.agentState);
      final lastRunStr = agentBox.get(AppConstants.kHiveKeyLastAgentRun);
      final lastRun = lastRunStr != null
          ? DateTime.parse(lastRunStr)
          : DateTime.now().subtract(const Duration(days: 90));

      logCallback(
        'data_collection',
        'Son çalışma: ${lastRun.day}.${lastRun.month}.${lastRun.year}',
        LogLevel.info,
      );

      // Adım 2: Bankadan yeni işlemleri çek
      final allTransactions = await _bankService.fetchTransactionsSince(lastRun);
      logCallback(
        'data_collection',
        '${allTransactions.length} işlem kaynaktan alındı',
        LogLevel.info,
      );

      // Adım 3-4: Duplicate kontrolü ve yeni işlemleri kaydet
      var newCount = 0;
      for (final tx in allTransactions) {
        final exists = await _dbHelper.transactionExists(tx.id);
        if (!exists) {
          await _dbHelper.insertTransaction(tx);
          newCount++;
        }
      }

      // Adım 5: Son çalışma zamanını güncelle
      await agentBox.put(
        AppConstants.kHiveKeyLastAgentRun,
        DateTime.now().toIso8601String(),
      );

      stopwatch.stop();
      logCallback(
        'data_collection',
        '$newCount yeni işlem eklendi (${stopwatch.elapsedMilliseconds}ms)',
        newCount > 0 ? LogLevel.success : LogLevel.info,
      );

      return DataCollectionResult(
        newTransactionsCount: newCount,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      logCallback('data_collection', 'Hata: $e', LogLevel.error);
      rethrow;
    }
  }
}
