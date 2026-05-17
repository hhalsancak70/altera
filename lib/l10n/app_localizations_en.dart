// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ALTERA';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get transactions => 'Transactions';

  @override
  String get budget => 'Budget';

  @override
  String get investments => 'Investments';

  @override
  String get agentLog => 'Agent Log';

  @override
  String get settings => 'Settings';

  @override
  String get agentReady => 'ALTERA Agent Ready';

  @override
  String get agentCollecting => 'Collecting Data...';

  @override
  String get agentAnalyzing => 'Gemini Analyzing...';

  @override
  String get agentActing => 'Taking Actions...';

  @override
  String get agentCompleted => 'Cycle Complete ✓';

  @override
  String get agentError => 'Error Occurred';

  @override
  String agentAnalyzedCount(int count) {
    return '$count transactions analyzed';
  }

  @override
  String agentCollectedCount(int count) {
    return '$count new transactions added';
  }

  @override
  String get budgetSafe => 'Safe';

  @override
  String get budgetWarning => 'Warning';

  @override
  String get budgetDanger => 'Exceeded';

  @override
  String budgetOverspent(String amount) {
    return '₺$amount over budget';
  }

  @override
  String get categoryMarket => 'Grocery';

  @override
  String get categoryRestaurant => 'Restaurant';

  @override
  String get categoryTransport => 'Transport';

  @override
  String get categoryBill => 'Bill';

  @override
  String get categoryClothing => 'Clothing';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryInvestment => 'Investment';

  @override
  String get categoryIncome => 'Income';

  @override
  String get categoryOther => 'Other';

  @override
  String get transactionTypeNeed => 'Need';

  @override
  String get transactionTypeWant => 'Want';

  @override
  String get transactionTypeIncome => 'Income';

  @override
  String get riskConservative => 'Conservative';

  @override
  String get riskBalanced => 'Balanced';

  @override
  String get riskAggressive => 'Aggressive';

  @override
  String get monthlySummary => 'Monthly Summary';

  @override
  String get totalIncome => 'Income';

  @override
  String get totalExpense => 'Expense';

  @override
  String get totalSavings => 'Savings';

  @override
  String get noTransactions =>
      'No transactions yet.\nStart the agent cycle to load transactions.';

  @override
  String get noBudgets => 'No budgets defined yet.';

  @override
  String get noLogs => 'No log entries yet.';

  @override
  String get startAgentCycle => 'Agent Cycle';

  @override
  String get agentRunning => 'Running...';

  @override
  String notificationBudgetWarningTitle(String category, String percent) {
    return '⚠️ $category Budget $percent% Full';
  }

  @override
  String notificationBudgetDangerTitle(String category) {
    return '🚨 $category Budget Exceeded!';
  }

  @override
  String get notificationInvestmentTitle => '✅ Investment Complete';

  @override
  String notificationInvestmentBody(String amount, String fund) {
    return '₺$amount transferred to $fund.';
  }

  @override
  String get apiKeyLabel => 'Gemini API Key';

  @override
  String get apiKeyHint => 'AIzaSy...';

  @override
  String get apiKeySaved => 'API Key saved';

  @override
  String get apiKeyInfo => 'API key is stored securely on your device.';

  @override
  String get resetAllData => 'Reset All Data';

  @override
  String get resetConfirm =>
      'Transactions, budgets and agent logs will be deleted. This cannot be undone.';

  @override
  String get resetSuccess => 'All data has been reset';

  @override
  String get agentFlowTitle => 'Agent Flow';

  @override
  String get agentFlowIdle => 'Idle';

  @override
  String get agentFlowCollect => 'Collect';

  @override
  String get agentFlowAnalyze => 'Gemini';

  @override
  String get agentFlowAct => 'Action';

  @override
  String get geminiReason => '✨ Gemini Reasoning';

  @override
  String get analysisWaiting => '⏳ Awaiting Analysis';

  @override
  String get transferConfirm => 'Confirm';

  @override
  String get transferCancel => 'Cancel';

  @override
  String transferSuccess(String amount, String fund) {
    return '₺$amount transferred to $fund';
  }

  @override
  String get investmentReady => 'Ready to Invest!';

  @override
  String get thisMonthSavings => 'This Month\'s Savings';

  @override
  String get historicalTransfers => 'Past Transfers';

  @override
  String get onboardingTitle => 'Welcome to\nALTERA!';

  @override
  String get onboardingSubtitle =>
      '3 autonomous agents powered by Gemini 2.0 Flash will guide you to your financial goals.';

  @override
  String get onboardingNext => 'Continue';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingStart => 'Get Started!';

  @override
  String get aboutApp => 'ALTERA v1.0.0';

  @override
  String get aboutAI => 'Gemini 2.0 Flash';

  @override
  String get aboutEvent => 'BTK Hackathon 2026';
}
