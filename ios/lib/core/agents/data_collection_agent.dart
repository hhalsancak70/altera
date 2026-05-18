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
    logCallback('data_collection', 'Veri toplama ajanı başlatıldı', LogLevel.info);

    try {
      // Tüm bu ayki işlemleri çek
      final now = DateTime.now();
      final allThisMonth = await _dbHelper.getTransactions(
        fromDate: DateTime(now.year, now.month, 1),
      );
      final analyzed = allThisMonth.where((t) => t.isAnalyzed).length;
      final total = allThisMonth.length;

      logCallback(
        'data_collection',
        'Bu ay toplam $total işlem bulundu — $analyzed tanesi zaten analiz edilmiş',
        LogLevel.info,
      );

      // Gemini analizi bekleyen (is_analyzed=0) işlemleri al
      final pending = await _dbHelper.getUnanalyzedTransactions(limit: 100);

      if (pending.isEmpty) {
        logCallback(
          'data_collection',
          'Tüm işlemler analiz edilmiş, bekleyen yok',
          LogLevel.info,
        );
      } else {
        logCallback(
          'data_collection',
          '${pending.length} işlem Gemini analizi kuyruğuna alındı',
          LogLevel.info,
        );
        // İlk birkaç işlemi listele
        final preview = pending.take(3).map((t) =>
          '"${t.description.length > 20 ? '${t.description.substring(0, 20)}…' : t.description}"'
        ).join(', ');
        logCallback(
          'data_collection',
          'Kuyruktaki işlemler: $preview${pending.length > 3 ? ' ve ${pending.length - 3} diğeri' : ''}',
          LogLevel.info,
        );
      }

      stopwatch.stop();
      logCallback(
        'data_collection',
        'Veri toplama tamamlandı (${stopwatch.elapsedMilliseconds}ms)',
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
