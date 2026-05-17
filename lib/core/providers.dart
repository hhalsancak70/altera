// Uygulama genelinde kullanılan tüm Riverpod provider'lar
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'agents/action_agent.dart';
import 'agents/analysis_agent.dart';
import 'agents/data_collection_agent.dart';
import 'agents/orchestrator.dart';
import 'constants/app_constants.dart';
import 'database/db_helper.dart';
import 'database/hive_boxes.dart';
import 'models/agent_log_entry.dart';
import 'models/budget.dart';
import 'models/transaction.dart';
import 'models/investment_fund.dart';
import 'models/user_profile.dart';
import 'models/monthly_archive.dart';
import 'repositories/transaction_repository.dart';
import 'services/cycle_service.dart';
import 'services/import_service.dart';
import 'services/investment_fund_service.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';

// ─────────────────────────────────────────────────────────────
// SERVİS PROVIDER'LARI
// ─────────────────────────────────────────────────────────────

/// SQLite veritabanı singleton'ı
final dbHelperProvider = Provider<DbHelper>((ref) => DbHelper());

/// İşlem repository'si — CRUD için tek yetkili kaynak
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(db: ref.read(dbHelperProvider));
});

/// Yatırım fonu servisi
final investmentFundServiceProvider =
    Provider<InvestmentFundService>((ref) => InvestmentFundService());

/// Import servisi — PDF/Excel içe aktarma
final importServiceProvider =
    Provider<ImportService>((ref) => ImportService());

/// Aylık döngü servisi
final cycleServiceProvider = Provider<CycleService>((ref) {
  return CycleService(
    db: ref.read(dbHelperProvider),
    notifications: ref.read(notificationServiceProvider),
  );
});

/// Bildirim servisi (zaten initialize edilmiş)
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService.instance);

/// Gemini servisi - async başlatma (API key güvenli depolamadan okunur)
final geminiServiceProvider = FutureProvider<GeminiService>((ref) async {
  return GeminiService.initialize();
});

/// Hive'dan kullanıcı profilini okur
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final box = Hive.box<String>(HiveBoxes.userProfile);
  final json = box.get(AppConstants.kHiveKeyUserProfile);
  if (json == null) return UserProfile.defaults();
  return UserProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
});

// ─────────────────────────────────────────────────────────────
// AJAN PROVIDER'LARI
// ─────────────────────────────────────────────────────────────

/// DataCollectionAgent instance'ı
final dataCollectionAgentProvider = Provider<DataCollectionAgent>((ref) {
  return DataCollectionAgent(
    dbHelper: ref.read(dbHelperProvider),
  );
});

/// AnalysisAgent - Gemini servisine bağımlı
final analysisAgentProvider = Provider<AnalysisAgent?>((ref) {
  final geminiAsync = ref.watch(geminiServiceProvider);
  return geminiAsync.when(
    data: (gemini) => AnalysisAgent(
      gemini: gemini,
      dbHelper: ref.read(dbHelperProvider),
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});

/// ActionAgent — Gemini opsiyonel (bütçe/anomali API keysiz de çalışır)
final actionAgentProvider = Provider<ActionAgent>((ref) {
  final gemini = ref.watch(geminiServiceProvider).valueOrNull;
  return ActionAgent(
    dbHelper: ref.read(dbHelperProvider),
    gemini: gemini,
    notifications: ref.read(notificationServiceProvider),
    fundService: ref.read(investmentFundServiceProvider),
  );
});

/// Orchestrator - StateNotifier (durumu takip eder)
///
/// NOT: analysisAgentProvider / actionAgentProvider WATCH edilmez.
/// Bunun yerine her döngüde ref.read ile güncel ajan okunur.
/// Bu sayede Gemini yüklendiğinde orchestrator yeniden yaratılmaz
/// ve timer/state sıfırlanmaz.
final orchestratorProvider =
    StateNotifierProvider<Orchestrator, OrchestratorState>((ref) {
  final db = ref.read(dbHelperProvider);

  return Orchestrator(
    dataAgent: ref.read(dataCollectionAgentProvider),
    dbHelper: db,
    getActionAgent: () => ref.read(actionAgentProvider),
  );
});

// ─────────────────────────────────────────────────────────────
// DATA PROVIDER'LARI
// ─────────────────────────────────────────────────────────────

/// Bu ayın işlemleri - ajan döngüsü sonrası yenilenir
final currentMonthTransactionsProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final db = ref.read(dbHelperProvider);
  final now = DateTime.now();
  return db.getTransactions(
    fromDate: DateTime(now.year, now.month, 1),
  );
});

/// Son N işlem - dashboard için
final recentTransactionsProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final db = ref.read(dbHelperProvider);
  final now = DateTime.now();
  return db.getTransactions(
    fromDate: DateTime(now.year, now.month, 1),
    limit: AppConstants.kRecentTransactionsCount,
  );
});

/// Bu ayın bütçeleri
final currentMonthBudgetsProvider =
    FutureProvider.autoDispose<List<Budget>>((ref) async {
  return ref.read(dbHelperProvider).getBudgetsForMonth(DateTime.now());
});

/// Son ajan logları
final recentAgentLogsProvider =
    FutureProvider.autoDispose<List<AgentLogEntry>>((ref) async {
  return ref
      .read(dbHelperProvider)
      .getRecentLogs(limit: AppConstants.kDefaultLogLimit);
});

/// Bu ayın kategori bazlı harcama dağılımı
final monthlySpendingProvider =
    FutureProvider.autoDispose<Map<TransactionCategory, double>>((ref) async {
  return ref
      .read(dbHelperProvider)
      .getMonthlySpendingByCategory(DateTime.now());
});

/// Bu ayın gelir/gider özeti
final monthlySummaryProvider = FutureProvider.autoDispose<
    ({
      double income,
      double expense,
      double savings,
    })>((ref) async {
  final db = ref.read(dbHelperProvider);
  final now = DateTime.now();
  final income = await db.getMonthlyIncome(now);
  final expense = await db.getMonthlyExpense(now);
  return (income: income, expense: expense, savings: income - expense);
});

/// Yatırım fonları listesi
final investmentFundsProvider =
    FutureProvider.autoDispose<List<InvestmentFund>>((ref) async {
  return ref.read(investmentFundServiceProvider).fetchInvestmentFunds();
});

/// Yatırım geçmişi
final investmentHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(dbHelperProvider).getInvestmentHistory();
});

/// Aylık arşivler listesi
final monthlyArchivesProvider =
    FutureProvider.autoDispose<List<MonthlyArchive>>((ref) async {
  return ref.read(cycleServiceProvider).getAllArchives();
});

/// Tüm işlemler (filtrelenebilir)
final allTransactionsProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  return ref.read(dbHelperProvider).getTransactions();
});
