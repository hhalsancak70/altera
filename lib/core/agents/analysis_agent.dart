// ALTERA Ajan 2: Analiz Ajanı - Gemini 2.0 Flash entegrasyonu
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
  static const int _kDelayBetweenRequestsMs =
      AppConstants.kAnalysisDelayMs;

  /// Bir döngüde maksimum analiz edilecek işlem sayısı
  static const int _kMaxTransactionsPerCycle =
      AppConstants.kMaxTransactionsPerCycle;

  AnalysisAgent({
    required GeminiService gemini,
    required DbHelper dbHelper,
  })  : _gemini = gemini,
        _dbHelper = dbHelper;

  /// Ajan çalışma döngüsü
  Future<AnalysisResult> run({
    required void Function(String agent, String message, LogLevel level)
        logCallback,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Adım 1: Analiz edilmemiş işlemleri çek
    final unanalyzed = await _dbHelper
        .getUnanalyzedTransactions(limit: _kMaxTransactionsPerCycle);

    if (unanalyzed.isEmpty) {
      logCallback('analysis', 'Analiz bekleyen işlem yok', LogLevel.info);
      stopwatch.stop();
      return AnalysisResult(
        analyzedCount: 0,
        failedCount: 0,
        categoryDistribution: {},
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    var analyzedCount = 0;
    var failedCount = 0;
    final distribution = <TransactionCategory, int>{};

    // Adım 2: Cache kontrolü — aynı merchant daha önce analiz edildiyse Gemini'ye gitme
    final needsGemini = <Transaction>[];

    for (final tx in unanalyzed) {
      final cached =
          await _dbHelper.getCachedAnalysisByDescription(tx.description);
      if (cached != null) {
        try {
          final category = TransactionCategory.values.byName(cached['category']!);
          final type = TransactionType.values.byName(cached['type']!);
          await _dbHelper.updateTransactionAnalysis(
              tx.id, category, type, cached['reason']!);
          distribution[category] = (distribution[category] ?? 0) + 1;
          analyzedCount++;
        } catch (_) {
          needsGemini.add(tx);
        }
      } else {
        needsGemini.add(tx);
      }
    }

    final cachedCount = analyzedCount;
    if (cachedCount > 0) {
      logCallback(
        'analysis',
        '$cachedCount işlem önbellekten kategorize edildi',
        LogLevel.info,
      );
    }

    if (needsGemini.isEmpty) {
      stopwatch.stop();
      logCallback(
        'analysis',
        '$analyzedCount işlem analiz edildi — Gemini çağrısı gerekmedi',
        LogLevel.success,
      );
      return AnalysisResult(
        analyzedCount: analyzedCount,
        failedCount: 0,
        categoryDistribution: distribution,
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }

    logCallback(
      'analysis',
      '${needsGemini.length} yeni işlem Gemini\'ye gönderiliyor (model: ${_gemini.activeModel})...',
      LogLevel.info,
    );

    // Adım 3: Kalan işlemleri tek API çağrısında Gemini'ye gönder (batch)
    try {
      final results = await _gemini.analyzeTransactionsBatch(needsGemini);

      for (var i = 0; i < needsGemini.length; i++) {
        final tx = needsGemini[i];
        final analysis = results[i];

        if (analysis == null) {
          failedCount++;
          logCallback(
            'analysis',
            '"${tx.description.length > 20 ? '${tx.description.substring(0, 20)}…' : tx.description}" batch\'te yanıt gelmedi',
            LogLevel.warning,
          );
          continue;
        }

        await _dbHelper.updateTransactionAnalysis(
          tx.id,
          analysis.category,
          analysis.type,
          analysis.reason,
        );

        distribution[analysis.category] =
            (distribution[analysis.category] ?? 0) + 1;
        analyzedCount++;
      }
    } on GeminiException catch (e) {
      if (e.isQuotaExceeded) {
        final retryHint = e.retryAfterSeconds != null
            ? '${e.retryAfterSeconds}sn sonra'
            : '1–2 dk sonra';
        logCallback(
          'analysis',
          'Kota: ${e.message} → ${needsGemini.length} işlem bekliyor ($retryHint tekrar dene)',
          LogLevel.warning,
        );
        stopwatch.stop();
        return AnalysisResult(
          analyzedCount: cachedCount,
          failedCount: needsGemini.length,
          categoryDistribution: {},
          durationMs: stopwatch.elapsedMilliseconds,
        );
      }
      // Batch başarısız olduysa tek tek dene
      logCallback(
        'analysis',
        'Batch analiz başarısız, tek tek deneniyor: ${e.message}',
        LogLevel.warning,
      );
      for (var i = 0; i < needsGemini.length; i++) {
        final tx = needsGemini[i];
        try {
          final analysis = await _gemini.analyzeTransaction(tx);
          await _dbHelper.updateTransactionAnalysis(
            tx.id,
            analysis.category,
            analysis.type,
            analysis.reason,
          );
          distribution[analysis.category] =
              (distribution[analysis.category] ?? 0) + 1;
          analyzedCount++;
        } on GeminiException catch (e2) {
          failedCount++;
          if (e2.isQuotaExceeded) {
            logCallback('analysis', 'Kota doldu, kalan işlemler bekleniyor', LogLevel.warning);
            break;
          }
        } catch (_) {
          failedCount++;
        }
        if (i < needsGemini.length - 1) {
          await Future.delayed(const Duration(milliseconds: _kDelayBetweenRequestsMs));
        }
      }
    } catch (e) {
      final errMsg = e.toString().replaceAll(RegExp(r'https?://\S+'), '').trim();
      logCallback(
        'analysis',
        'Beklenmedik hata, tek tek deneniyor: ${errMsg.length > 60 ? '${errMsg.substring(0, 60)}…' : errMsg}',
        LogLevel.warning,
      );
      for (var i = 0; i < needsGemini.length; i++) {
        final tx = needsGemini[i];
        try {
          final analysis = await _gemini.analyzeTransaction(tx);
          await _dbHelper.updateTransactionAnalysis(
              tx.id, analysis.category, analysis.type, analysis.reason);
          distribution[analysis.category] =
              (distribution[analysis.category] ?? 0) + 1;
          analyzedCount++;
        } on GeminiException catch (e2) {
          failedCount++;
          if (e2.isQuotaExceeded) {
            logCallback('analysis', 'Kota doldu, kalan işlemler bekleniyor',
                LogLevel.warning);
            break;
          }
        } catch (_) {
          failedCount++;
        }
        if (i < needsGemini.length - 1) {
          await Future.delayed(
              const Duration(milliseconds: _kDelayBetweenRequestsMs));
        }
      }
    }

    stopwatch.stop();

    final summary =
        '$analyzedCount işlem analiz edildi${failedCount > 0 ? ', $failedCount hata' : ''} (${stopwatch.elapsedMilliseconds}ms)';

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
