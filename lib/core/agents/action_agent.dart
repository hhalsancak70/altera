// ALTERA Ajan 3: Aksiyon Ajanı - proaktif finansal aksiyonlar
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../database/hive_boxes.dart';
import '../models/agent_log_entry.dart';
import '../models/budget.dart';
import '../models/user_profile.dart';
import '../services/bank_mock_service.dart';
import '../services/gemini_service.dart';
import '../services/notification_service.dart';

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
  final BankMockService _bankService;
  final _uuid = const Uuid();

  ActionAgent({
    required DbHelper dbHelper,
    required GeminiService gemini,
    required NotificationService notifications,
    required BankMockService bankService,
  })  : _dbHelper = dbHelper,
        _gemini = gemini,
        _notifications = notifications,
        _bankService = bankService;

  /// Ajan çalışma döngüsü
  Future<ActionResult> run({
    required void Function(String agent, String message, LogLevel level)
        logCallback,
  }) async {
    final stopwatch = Stopwatch()..start();
    final actions = <String>[];
    final now = DateTime.now();

    logCallback('action', 'Aksiyon döngüsü başladı', LogLevel.info);

    // Kullanıcı profilini oku
    final profileJson = Hive.box<String>(HiveBoxes.userProfile)
        .get(AppConstants.kHiveKeyUserProfile);
    final profile = profileJson != null
        ? UserProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>)
        : UserProfile.defaults();

    // ─── AKSİYON 1: BÜTÇE KONTROLÜ ───
    try {
      final budgets = await _dbHelper.getBudgetsForMonth(now);

      for (final budget in budgets) {
        if (budget.limitAmount <= 0) continue;

        if (budget.status == BudgetStatus.danger) {
          // Kritik: %100+ aşım
          await _notifications.showBudgetDanger(
            category: budget.category,
            overspentAmount: budget.overspentAmount,
          );

          final action =
              '${budget.category.displayNameTr} bütçesi aşıldı (${budget.overspentAmount.toStringAsFixed(0)} TL fazla)';
          actions.add(action);
          logCallback('action', action, LogLevel.warning);
        } else if (budget.status == BudgetStatus.warning) {
          // Uyarı: %80-99 arası
          try {
            final suggestion = await _gemini.generateBudgetAlert(
              category: budget.category,
              overspentAmount: budget.spentAmount - budget.limitAmount * 0.8,
            );

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
          final funds = await _bankService.fetchInvestmentFunds();
          final spending = await _dbHelper.getMonthlySpendingByCategory(now);

          final recommendation = await _gemini.analyzeAndRecommendInvestment(
            spending: spending,
            riskProfile: profile.riskProfile,
            savingsAmount: savings,
            funds: funds,
          );

          // Simüle transferi gerçekleştir
          final transferResult = await _bankService.executeInvestmentTransfer(
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
    try {
      final weeklyData = await _dbHelper.getWeeklySpendingComparison();
      final thisWeek = weeklyData.thisWeek;
      final lastWeek = weeklyData.lastWeek;

      if (lastWeek > 0 && thisWeek > lastWeek * 1.5) {
        // %50+ artış anomali sayılır
        final increasePercent =
            ((thisWeek - lastWeek) / lastWeek * 100).toStringAsFixed(0);
        final anomalyMsg =
            'Bu hafta harcamaları geçen haftaya göre %$increasePercent arttı';
        actions.add(anomalyMsg);
        logCallback('action', anomalyMsg, LogLevel.warning);
      }
    } catch (e) {
      logCallback('action', 'Anomali kontrolü hatası: $e', LogLevel.error);
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
