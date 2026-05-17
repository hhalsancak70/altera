// ALTERA Dashboard - ana kontrol paneli ekranı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers.dart';
import '../../core/services/gemini_service.dart';
import 'widgets/agent_status_card.dart';
import 'widgets/monthly_summary_card.dart';
import 'widgets/spending_pie_chart.dart';
import 'widgets/budget_progress_section.dart';
import 'widgets/recent_transactions_section.dart';

/// Ana kontrol paneli ekranı.
/// Kullanıcının günlük finans özetini gösterir ve ajan durumunu anlık yansıtır.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orchestratorState = ref.watch(orchestratorProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ALTERA',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: const Text(
                'Gemini 2.0',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentMonthTransactionsProvider);
          ref.invalidate(monthlySpendingProvider);
          ref.invalidate(currentMonthBudgetsProvider);
          ref.invalidate(recentTransactionsProvider);
          ref.invalidate(monthlySummaryProvider);
        },
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: const [
            AgentStatusCard(),
            SizedBox(height: 8),
            MonthlySummaryCard(),
            SizedBox(height: 8),
            SpendingPieChart(),
            SizedBox(height: 8),
            BudgetProgressSection(),
            SizedBox(height: 8),
            RecentTransactionsSection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: orchestratorState.isRunning
            ? null
            : () async {
                ref.invalidate(geminiServiceProvider);
                if (!await GeminiService.hasApiKey()) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Önce Ayarlar\'dan Gemini API key kaydet (💾 ikonuna bas)',
                        ),
                        backgroundColor: AppColors.warning,
                      ),
                    );
                  }
                  return;
                }
                await ref.read(orchestratorProvider.notifier).runOnce();
                ref.invalidate(currentMonthTransactionsProvider);
                ref.invalidate(recentTransactionsProvider);
                ref.invalidate(monthlySpendingProvider);
                ref.invalidate(monthlySummaryProvider);
                ref.invalidate(currentMonthBudgetsProvider);
                ref.invalidate(recentAgentLogsProvider);
              },
        backgroundColor:
            orchestratorState.isRunning ? AppColors.surfaceLight : AppColors.accent,
        foregroundColor: AppColors.primary,
        icon: Icon(
          orchestratorState.isRunning ? Icons.hourglass_empty : Icons.play_arrow,
        ),
        label: Text(
          orchestratorState.isRunning ? 'Çalışıyor...' : 'Ajan Döngüsü',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
