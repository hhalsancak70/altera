// ALTERA Ajan 1: Veri Toplama Ajanı
import '../database/db_helper.dart';
import '../models/agent_log_entry.dart';

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
/// Sorumluluğu: Kullanıcının manuel girdiği veya PDF/Excel'den içe aktardığı
/// işlemler arasında Gemini analizi bekleyenleri tespit eder ve raporlar.
///
/// Veri kaynakları:
///   - Manuel giriş (AddEditTransactionScreen)
///   - PDF/Excel içe aktarma (ImportService)
///
/// Kullanım:
/// ```dart
/// final agent = DataCollectionAgent(dbHelper: db);
/// final result = await agent.run(logCallback: orchestrator.log);
/// ```
class DataCollectionAgent {
  final DbHelper _dbHelper;

  DataCollectionAgent({required DbHelper dbHelper}) : _dbHelper = dbHelper;

  /// Ajan çalışma döngüsü - Orchestrator bu metodu çağırır.
  ///
  /// [logCallback] Her adımı Orchestrator'a bildiren callback
  /// Returns: Analiz bekleyen işlem sayısı ve süre
  Future<DataCollectionResult> run({
    required void Function(String agent, String message, LogLevel level)
        logCallback,
  }) async {
    final stopwatch = Stopwatch()..start();
    logCallback('data_collection', 'Veri kontrolü başladı', LogLevel.info);

    try {
      // Gemini analizi bekleyen (is_analyzed=0) işlemleri say
      final pending = await _dbHelper.getUnanalyzedTransactions(limit: 100);

      logCallback(
        'data_collection',
        '${pending.length} işlem Gemini analizi bekliyor',
        LogLevel.info,
      );

      stopwatch.stop();
      logCallback(
        'data_collection',
        'Kontrol tamamlandı (${stopwatch.elapsedMilliseconds}ms)',
        LogLevel.success,
      );

      return DataCollectionResult(
        newTransactionsCount: pending.length,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      logCallback('data_collection', 'Hata: $e', LogLevel.error);
      rethrow;
    }
  }
}
