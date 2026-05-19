// ALTERA Ajan 3: Aksiyon Ajanı - proaktif finansal aksiyonlar
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../database/hive_boxes.dart';
import '../models/agent_log_entry.dart';
import '../models/budget.dart';
import '../models/user_profile.dart';
import '../services/investment_fund_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';
import '../services/yahoo_finance_service.dart';

/// Aksiyon sonucu
class ActionResult {
  final List<String> actionsPerformed;
  final int durationMs;

  const ActionResult({
    required this.actionsPerformed,
    required this.durationMs,
  });
}

/// ALTERA Ajan 3: Aksiyon Ajanı
///
/// Sorumluluğu: Analiz sonuçlarını değerlendirerek proaktif aksiyonlar alır.
/// Bütçe aşımında uyarı + öneri, ay sonu tasarrufu yatırıma yönlendirir.
///
/// Bu ajan sadece düşünmez - HAREKET EDER.
/// Hackathon fark yaratan özellik: pasif aksiyon alma.
///
/// Kullanım:
/// ```dart
/// final agent = ActionAgent(dbHelper: db, gemini: gemini, ...);
/// final result = await agent.run(logCallback: orchestrator.log);
/// ```
class ActionAgent {
  final DbHelper _dbHelper;
  final GeminiService _gemini;
  final NotificationService _notifications;
  final InvestmentFundService _fundService;
  final _uuid = const Uuid();

  ActionAgent({
    required DbHelper dbHelper,
    required GeminiService gemini,
    required NotificationService notifications,
    required InvestmentFundService fundService,
  }) : _dbHelper = dbHelper,
       _gemini = gemini,
       _notifications = notifications,
       _fundService = fundService;

  /// Ajan çalışma döngüsü
  Future<ActionResult> run({
    required void Function(String agent, String message, LogLevel level)
    logCallback,
  }) async {
    final stopwatch = Stopwatch()..start();
    final actions = <String>[];
    final now = DateTime.now();

    logCallback('action', 'Aksiyon ajanı başlatıldı', LogLevel.info);

    // Kullanıcı profilini oku
    final profileJson = Hive.box<String>(
      HiveBoxes.userProfile,
    ).get(AppConstants.kHiveKeyUserProfile);
    final profile =
        profileJson != null
            ? UserProfile.fromJson(
              jsonDecode(profileJson) as Map<String, dynamic>,
            )
            : UserProfile.defaults();

    logCallback(
      'action',
      'Kullanıcı profili yüklendi — risk: ${profile.riskProfile.name}',
      LogLevel.info,
    );

    // ─── AKSİYON 1: BÜTÇE KONTROLÜ ───
    logCallback('action', 'Bütçe limitleri kontrol ediliyor...', LogLevel.info);
    try {
      final budgets = await _dbHelper.getBudgetsForMonth(now);

      if (budgets.isEmpty) {
        logCallback(
          'action',
          'Bu ay için tanımlı bütçe bulunamadı',
          LogLevel.info,
        );
      } else {
        logCallback(
          'action',
          '${budgets.length} bütçe kategorisi inceleniyor',
          LogLevel.info,
        );
      }

      bool firstBudgetGeminiCall = true;
      for (final budget in budgets) {
        if (budget.limitAmount <= 0) continue;

        if (budget.status == BudgetStatus.danger) {
          // Kritik: %100+ aşım — Gemini çağırmadan bildirim gönder
          await _notifications.showBudgetDanger(
            category: budget.category,
            overspentAmount: budget.overspentAmount,
          );

          final action =
              '${budget.category.displayNameTr} bütçesi aşıldı (${budget.overspentAmount.toStringAsFixed(0)} TL fazla)';
          actions.add(action);
          logCallback('action', action, LogLevel.warning);
        } else if (budget.status == BudgetStatus.warning) {
          // Uyarı: %80-99 arası — sadece ilk uyarı için Gemini çağır (etkinse)
          try {
            String suggestion;
            if (firstBudgetGeminiCall && _gemini.isEnabled) {
              suggestion = await _gemini.generateBudgetAlert(
                category: budget.category,
                overspentAmount: budget.spentAmount - budget.limitAmount * 0.8,
              );
              firstBudgetGeminiCall = false;
              // Bir sonraki olası Gemini çağrısından önce bekle
              await Future.delayed(const Duration(seconds: 5));
            } else {
              suggestion = 'Bu kategoride harcamalarını gözden geçirmeyi dene.';
            }

            await _notifications.showBudgetWarning(
              category: budget.category,
              usagePercentage: budget.usagePercentage,
              suggestion: suggestion,
            );

            final action =
                '${budget.category.displayNameTr} uyarısı: %${(budget.usagePercentage * 100).toStringAsFixed(0)} dolu';
            actions.add(action);
            logCallback('action', action, LogLevel.warning);
          } catch (_) {
            // Gemini başarısız - yine de bildirim gönder
            await _notifications.showBudgetWarning(
              category: budget.category,
              usagePercentage: budget.usagePercentage,
              suggestion: 'Bu kategoride harcamalarını gözden geçir.',
            );
          }
        }
      }
    } catch (e) {
      logCallback('action', 'Bütçe kontrolü hatası: $e', LogLevel.error);
    }

    // ─── AKSİYON 2: AY SONU TASARRUF YATIRIMI ───
    logCallback(
      'action',
      'Ay sonu yatırım kontrolü — bugün ayın ${now.day}. günü '
          '(eşik: ${AppConstants.kMonthEndDayThreshold}. gün)',
      LogLevel.info,
    );
    if (now.day >= AppConstants.kMonthEndDayThreshold) {
      try {
        final income = await _dbHelper.getMonthlyIncome(now);
        final expense = await _dbHelper.getMonthlyExpense(now);
        final savings = income - expense;

        logCallback(
          'action',
          'Ay sonu tasarrufu: ${savings.toStringAsFixed(0)} TL',
          LogLevel.info,
        );

        if (savings >= AppConstants.kMinInvestmentAmount) {
          logCallback(
            'action',
            'Yatırım eşiği aşıldı (min ${AppConstants.kMinInvestmentAmount.toStringAsFixed(0)} TL). '
                'Gemini\'den fon önerisi isteniyor...',
            LogLevel.info,
          );
          final funds = await _fundService.fetchInvestmentFunds();
          final spending = await _dbHelper.getMonthlySpendingByCategory(now);

          final recommendation = await _gemini.analyzeAndRecommendInvestment(
            spending: spending,
            riskProfile: profile.riskProfile,
            savingsAmount: savings,
            funds: funds,
          );

          // Simüle transferi gerçekleştir
          final transferResult = await _fundService.executeInvestmentTransfer(
            fundId: recommendation.fundId,
            amount: recommendation.suggestedAmount,
            reason: recommendation.reasoning,
          );

          if (transferResult.success) {
            await _dbHelper.insertInvestmentRecord(
              id: _uuid.v4(),
              fundId: recommendation.fundId,
              fundName: recommendation.fundName,
              amount: recommendation.suggestedAmount,
              action: 'buy',
              aiReason: recommendation.reasoning,
            );

            await _notifications.showInvestmentCompleted(
              fundName: recommendation.fundName,
              amount: recommendation.suggestedAmount,
            );

            final action =
                '${recommendation.suggestedAmount.toStringAsFixed(0)} TL ${recommendation.fundName}\'a aktarıldı';
            actions.add(action);
            logCallback('action', action, LogLevel.success);
          }
        } else {
          logCallback(
            'action',
            'Tasarruf yeterli değil (min ${AppConstants.kMinInvestmentAmount} TL)',
            LogLevel.info,
          );
        }
      } catch (e) {
        logCallback('action', 'Yatırım aksiyon hatası: $e', LogLevel.error);
      }
    }

    // ─── AKSİYON 3: HARCAMA ANOMALİSİ ───
    logCallback(
      'action',
      'Haftalık harcama anomalisi taranıyor...',
      LogLevel.info,
    );
    try {
      final weeklyData = await _dbHelper.getWeeklySpendingComparison();
      final thisWeek = weeklyData.thisWeek;
      final lastWeek = weeklyData.lastWeek;

      logCallback(
        'action',
        'Bu hafta: ${thisWeek.toStringAsFixed(0)} TL | '
            'Geçen hafta: ${lastWeek.toStringAsFixed(0)} TL',
        LogLevel.info,
      );

      if (lastWeek > 0 && thisWeek > lastWeek * 1.5) {
        // %50+ artış anomali sayılır
        final increasePercent = ((thisWeek - lastWeek) / lastWeek * 100)
            .toStringAsFixed(0);
        final anomalyMsg =
            'Anomali tespit edildi! Bu hafta harcamalar geçen haftaya göre %$increasePercent arttı';
        actions.add(anomalyMsg);
        logCallback('action', anomalyMsg, LogLevel.warning);
      } else {
        logCallback(
          'action',
          'Anomali yok, harcamalar normal seyrediyor',
          LogLevel.info,
        );
      }
    } catch (e) {
      logCallback('action', 'Anomali kontrolü hatası: $e', LogLevel.error);
    }

    // ─── AKSİYON 4: PORTFÖY TAKİBİ ───
    logCallback(
      'action',
      'Portföy fiyat değişimleri kontrol ediliyor...',
      LogLevel.info,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final portfolioRaw = prefs.getString('altera_portfolio');

      if (portfolioRaw == null || portfolioRaw == '[]') {
        logCallback('action', 'Portföyde henüz varlık yok', LogLevel.info);
      } else {
        final List<dynamic> portfolioList = jsonDecode(portfolioRaw);

        // USD/TRY kurunu al
        double usdRate = 1.0;
        try {
          final tryData = await fetchYahooQuote('TRY=X');
          usdRate = (tryData['price'] as num?)?.toDouble() ?? 1.0;
          logCallback(
            'action',
            'Dolar/TL kuru: ₺${usdRate.toStringAsFixed(2)}',
            LogLevel.info,
          );
        } catch (_) {}

        double totalDailyDeltaTl = 0;
        double totalCurrentTl = 0;
        double totalCostTl = 0;
        final insightBuf = StringBuffer();

        for (final item in portfolioList) {
          final name = item['name'] as String;
          final symbol = item['symbol'] as String;
          final units = (item['units'] as num).toDouble();
          final costTl = (item['totalCost'] as num).toDouble();

          if (units <= 0) continue;

          try {
            final data = await fetchYahooQuote(symbol);
            final rawPrice = (data['price'] as num).toDouble();
            final changePct = (data['changePercent'] as num).toDouble();

            // Fiyatı TL'ye çevir (investments_screen mantığıyla aynı)
            double livePriceTl = rawPrice;
            if (symbol == 'GC=F' || symbol == 'SI=F') {
              livePriceTl = (rawPrice / 31.1034768) * usdRate;
            } else if (symbol.contains('-USD') || symbol == 'SPY') {
              livePriceTl = rawPrice * usdRate;
            }

            final currentValTl = units * livePriceTl;
            final prevValTl = currentValTl / (1 + changePct / 100);
            final dailyDeltaTl = currentValTl - prevValTl;
            final profitTl = currentValTl - costTl;
            final profitPct = costTl > 0 ? (profitTl / costTl) * 100 : 0.0;

            totalDailyDeltaTl += dailyDeltaTl;
            totalCurrentTl += currentValTl;
            totalCostTl += costTl;

            final dailySign = dailyDeltaTl >= 0 ? '+' : '';
            final profitSign = profitTl >= 0 ? '+' : '';
            final arrow = changePct >= 0 ? '▲' : '▼';

            final logLevel =
                changePct.abs() >= 3.0
                    ? LogLevel
                        .warning // ±3%+ → dikkat çekici
                    : LogLevel.info;

            logCallback(
              'action',
              '$arrow $name: bugün $dailySign₺${dailyDeltaTl.toStringAsFixed(0)} '
                  '($dailySign${changePct.toStringAsFixed(2)}%) | '
                  'toplam kâr/zarar $profitSign₺${profitTl.toStringAsFixed(0)} ($profitSign${profitPct.toStringAsFixed(1)}%)',
              logLevel,
            );

            // Önemli hareket (±5%) → bildirim gönder
            if (changePct.abs() >= 5.0) {
              await _notifications.showPortfolioAlert(
                assetName: name,
                assetSymbol: symbol,
                changePct: changePct,
                deltaAmountTl: dailyDeltaTl,
              );
              actions.add(
                '$name portföy alarmı: $dailySign${changePct.toStringAsFixed(2)}%',
              );
            }

            // Gemini bağlamı için
            insightBuf.writeln(
              '• $name: maliyet ₺${costTl.toStringAsFixed(0)}, '
              'güncel ₺${currentValTl.toStringAsFixed(0)} '
              '($profitSign₺${profitTl.toStringAsFixed(0)}, $profitSign${profitPct.toStringAsFixed(1)}%), '
              'bugün $dailySign₺${dailyDeltaTl.toStringAsFixed(0)} ($dailySign${changePct.toStringAsFixed(2)}%)',
            );
          } catch (e) {
            logCallback(
              'action',
              '$name fiyatı alınamadı: $e',
              LogLevel.warning,
            );
          }
        }

        // Portföy özeti
        if (totalCurrentTl > 0) {
          final totalDailySign = totalDailyDeltaTl >= 0 ? '+' : '';
          final totalProfitTl = totalCurrentTl - totalCostTl;
          final totalProfitSign = totalProfitTl >= 0 ? '+' : '';
          final totalDailyPct =
              totalCurrentTl > 0
                  ? (totalDailyDeltaTl / (totalCurrentTl - totalDailyDeltaTl)) *
                      100
                  : 0.0;

          logCallback(
            'action',
            'Portföy özeti → güncel ₺${totalCurrentTl.toStringAsFixed(0)} | '
                'bugün $totalDailySign₺${totalDailyDeltaTl.toStringAsFixed(0)} '
                '($totalDailySign${totalDailyPct.toStringAsFixed(2)}%) | '
                'toplam kâr/zarar $totalProfitSign₺${totalProfitTl.toStringAsFixed(0)}',
            totalDailyDeltaTl >= 0 ? LogLevel.success : LogLevel.warning,
          );

          // Günlük değişim ±2%'yi geçtiyse Gemini'den öneri al (etkinse)
          // Kota tasarrufu: son 30 dakika içinde çağrıldıysa atla
          if (_gemini.isEnabled &&
              totalDailyPct.abs() >= 2.0 &&
              insightBuf.isNotEmpty) {
            const _kPortfolioInsightCooldownKey =
                'action_agent_last_portfolio_insight_ms';
            const _kCooldownMs = 30 * 60 * 1000; // 30 dakika
            final prefs2 = await SharedPreferences.getInstance();
            final lastMs = prefs2.getInt(_kPortfolioInsightCooldownKey) ?? 0;
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            final canCall = (nowMs - lastMs) >= _kCooldownMs;

            if (canCall) {
              logCallback(
                'action',
                'Günlük değişim eşiği aşıldı, Gemini analizi isteniyor...',
                LogLevel.info,
              );
              try {
                insightBuf.writeln(
                  '\nTOPLAM: güncel ₺${totalCurrentTl.toStringAsFixed(0)}, bugün $totalDailySign₺${totalDailyDeltaTl.toStringAsFixed(0)}',
                );
                final insight = await _gemini.generatePortfolioInsights(
                  insightBuf.toString(),
                );
                await prefs2.setInt(_kPortfolioInsightCooldownKey, nowMs);
                for (final line in insight.split('\n')) {
                  final trimmed = line.trim();
                  if (trimmed.isEmpty) continue;
                  final isAlert = trimmed.toUpperCase().contains('SAT');
                  logCallback(
                    'action',
                    trimmed,
                    isAlert ? LogLevel.warning : LogLevel.info,
                  );
                }
                actions.add('Portföy AL/SAT analizi tamamlandı');
              } catch (e) {
                logCallback(
                  'action',
                  'Gemini portföy analizi başarısız: $e',
                  LogLevel.warning,
                );
              }
            } else {
              final remainMin = (_kCooldownMs - (nowMs - lastMs)) ~/ 60000;
              logCallback(
                'action',
                'Portföy analizi cooldown aktif ($remainMin dk kaldı), atlanıyor',
                LogLevel.info,
              );
            }
          }
        }
      }
    } catch (e) {
      logCallback('action', 'Portföy takip hatası: $e', LogLevel.error);
    }

    stopwatch.stop();
    logCallback(
      'action',
      '${actions.length} aksiyon gerçekleştirildi (${stopwatch.elapsedMilliseconds}ms)',
      actions.isEmpty ? LogLevel.info : LogLevel.success,
    );

    return ActionResult(
      actionsPerformed: actions,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }
}
