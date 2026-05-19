// ALTERA Ajan 2: Analiz Ajanı - Gemini 2.0 Flash entegrasyonu
import 'dart:async';
import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/agent_log_entry.dart';
import '../models/transaction.dart';
import '../services/gemini_service.dart';

/// Analiz sonucu
class AnalysisResult {
  final int analyzedCount;
  final int failedCount;
  final Map<TransactionCategory, int> categoryDistribution;
  final int durationMs;

  const AnalysisResult({
    required this.analyzedCount,
    required this.failedCount,
    required this.categoryDistribution,
    required this.durationMs,
  });
}

/// ALTERA Ajan 2: Analiz Ajanı (Gemini 2.0 Flash)
///
/// Sorumluluğu: Analiz edilmemiş işlemleri Gemini'ye gönderir,
/// dönen kategori + ihtiyaç/istek bilgisini veritabanına kaydeder.
///
/// Önemli: Gemini API rate limit'e dikkat - istekler arasında
/// kısa bekleme uygula (_kDelayBetweenRequestsMs).
///
/// Girdi: Veritabanındaki is_analyzed=0 olan işlemler
/// Çıktı: Analiz tamamlanan işlem sayısı + kategori dağılımı
///
/// Kullanım:
/// ```dart
/// final agent = AnalysisAgent(gemini: service, dbHelper: db);
/// final result = await agent.run(logCallback: orchestrator.log);
/// ```
class AnalysisAgent {
  final GeminiService _gemini;
  final DbHelper _dbHelper;

  /// Gemini API çağrıları arası bekleme süresi (ms) - rate limit aşımını önler
  static const int _kDelayBetweenRequestsMs = AppConstants.kAnalysisDelayMs;

  /// Bir döngüde maksimum analiz edilecek işlem sayısı
  static const int _kMaxTransactionsPerCycle =
      AppConstants.kMaxTransactionsPerCycle;

  AnalysisAgent({required GeminiService gemini, required DbHelper dbHelper})
    : _gemini = gemini,
      _dbHelper = dbHelper;

  /// Ajan çalışma döngüsü
  Future<AnalysisResult> run({
    required void Function(String agent, String message, LogLevel level)
    logCallback,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Gemini disabled ise AI analizi yapılamaz; sessizce dön
    if (!_gemini.isEnabled) {
      logCallback(
        'analysis',
        'Gemini API key yok; AI analizleri bekletiliyor.',
        LogLevel.info,
      );
      stopwatch.stop();
      return AnalysisResult(
        analyzedCount: 0,
        failedCount: 0,
        categoryDistribution: {},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Adım 1: Analiz edilmemiş işlemleri çek
    final unanalyzed = await _dbHelper.getUnanalyzedTransactions(
      limit: _kMaxTransactionsPerCycle,
    );

    if (unanalyzed.isEmpty) {
      logCallback(
        'analysis',
        'Analiz bekleyen işlem yok, atlanıyor',
        LogLevel.info,
      );
      stopwatch.stop();
      return AnalysisResult(
        analyzedCount: 0,
        failedCount: 0,
        categoryDistribution: {},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    logCallback(
      'analysis',
      'Gemini 2.0 Flash ile ${unanalyzed.length} işlem analiz edilecek',
      LogLevel.info,
    );

    var analyzedCount = 0;
    var failedCount = 0;
    final distribution = <TransactionCategory, int>{};

    // Adım 2: Her işlem için Gemini analizi
    for (var i = 0; i < unanalyzed.length; i++) {
      final tx = unanalyzed[i];

      final shortDesc =
          tx.description.length > 25
              ? '${tx.description.substring(0, 25)}…'
              : tx.description;

      logCallback(
        'analysis',
        '[${i + 1}/${unanalyzed.length}] "${shortDesc}" analiz ediliyor...',
        LogLevel.info,
      );

      try {
        final analysis = await _gemini.analyzeTransaction(tx);

        // Veritabanını güncelle
        await _dbHelper.updateTransactionAnalysis(
          tx.id,
          analysis.category,
          analysis.type,
          analysis.reason,
        );

        // Dağılım istatistiğini güncelle
        distribution[analysis.category] =
            (distribution[analysis.category] ?? 0) + 1;

        analyzedCount++;

        logCallback(
          'analysis',
          '  → Kategori: ${analysis.category.displayNameTr} | '
              'Tür: ${analysis.type.name} | '
              'Süre: ${analysis.durationMs}ms',
          LogLevel.success,
        );
      } catch (e) {
        failedCount++;
        final errMsg =
            e is GeminiException
                ? e.message
                : e.toString().replaceAll(RegExp(r'https?://\S+'), '').trim();
        final short =
            errMsg.length > 80 ? '${errMsg.substring(0, 80)}…' : errMsg;
        logCallback(
          'analysis',
          '"${tx.description.length > 20 ? '${tx.description.substring(0, 20)}…' : tx.description}" analiz edilemedi: $short',
          LogLevel.warning,
        );

        // Kota veya rate limit hatası → kalan işlemleri deneme, cooldown bekle
        if (GeminiService.isRateLimitError(errMsg)) {
          logCallback(
            'analysis',
            'API kota/rate limit aşıldı. Kalan ${unanalyzed.length - i - 1} işlem sonraki döngüde analiz edilecek. '
                '${AppConstants.kRateLimitDelayMs ~/ 1000}s bekleniyor...',
            LogLevel.warning,
          );
          // Orchestrator'ın hemen tekrar denememesi için burada bekliyoruz.
          // Bu sayede bir sonraki cycle başladığında rate limit penceresi geçmiş olur.
          await Future.delayed(
            Duration(milliseconds: AppConstants.kRateLimitDelayMs),
          );
          break;
        }
      }

      // Rate limit aşımını önlemek için bekleme
      if (i < unanalyzed.length - 1) {
        await Future.delayed(Duration(milliseconds: _kDelayBetweenRequestsMs));
      }
    }

    stopwatch.stop();

    if (distribution.isNotEmpty) {
      final distSummary = distribution.entries
          .map((e) => '${e.key.displayNameTr}: ${e.value}')
          .join(' | ');
      logCallback(
        'analysis',
        'Kategori dağılımı → $distSummary',
        LogLevel.info,
      );
    }

    final summary =
        analyzedCount > 0
            ? '$analyzedCount işlem başarıyla kategorize edildi'
                '${failedCount > 0 ? ', $failedCount işlem başarısız' : ''}'
                ' — toplam ${stopwatch.elapsedMilliseconds}ms'
            : 'Hiçbir işlem analiz edilemedi${failedCount > 0 ? ' ($failedCount hata)' : ''}';

    logCallback(
      'analysis',
      summary,
      failedCount == 0 ? LogLevel.success : LogLevel.warning,
    );

    return AnalysisResult(
      analyzedCount: analyzedCount,
      failedCount: failedCount,
      categoryDistribution: distribution,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }
}
