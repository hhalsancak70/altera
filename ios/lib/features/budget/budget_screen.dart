// Aylık bütçe yönetim ekranı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/agents/orchestrator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/budget.dart';
import '../../core/models/transaction.dart';
import '../../core/providers.dart';
import '../dashboard/widgets/budget_progress_section.dart';

/// Aylık bütçe yönetim ekranı.
class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(currentMonthBudgetsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);

    // Gemini analizi bittiğinde kategoriler güncellenmiş olabilir — bütçeyi yenile
    ref.listen(orchestratorProvider, (prev, next) {
      if (next is OrchestratorStateIdle && prev != null && prev.isRunning) {
        _refresh();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Bütçe'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // Aylık özet bant
          summaryAsync.when(
            data: (summary) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF1F2937), width: 1),
                ),
                child: Row(
                  children: [
                    _SummaryColumn(
                      label: 'Toplam Bütçe',
                      value: budgetsAsync.when(
                        data: (b) =>
                            b.fold(0.0, (s, e) => s + e.limitAmount),
                        loading: () => 0.0,
                        error: (_, __) => 0.0,
                      ),
                      color: AppColors.textPrimary,
                    ),
                    const _Divider(),
                    _SummaryColumn(
                      label: 'Harcanan',
                      value: summary.expense,
                      color: AppColors.danger,
                    ),
                    const _Divider(),
                    _SummaryColumn(
                      label: 'Kalan',
                      value: budgetsAsync.when(
                            data: (b) =>
                                b.fold(0.0, (s, e) => s + e.limitAmount),
                            loading: () => 0.0,
                            error: (_, __) => 0.0,
                          ) -
                          summary.expense,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Bütçe kartları
          budgetsAsync.when(
            data: (budgets) {
              if (budgets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.textSecondary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz bütçe tanımlanmadı',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Kategori bazlı bütçe limitleri ekleyerek\nharcamalarını takip edebilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: budgets
                    .map((b) => _BudgetCard(budget: b, onRefresh: _refresh))
                    .toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
            ),
            error: (_, __) => const Center(
              child: Text(
                'Bütçeler yüklenemedi',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBudgetSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Bütçe Ekle'),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primary,
      ),
    );
  }

  void _refresh() {
    ref.invalidate(currentMonthBudgetsProvider);
    ref.invalidate(monthlySummaryProvider);
  }

  void _showAddBudgetSheet(BuildContext context) {
    TransactionCategory? selected;
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yeni Bütçe Limiti',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kategori Seç',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TransactionCategory.values
                    .where((c) => c != TransactionCategory.income)
                    .map((cat) {
                  final isSel = selected == cat;
                  return GestureDetector(
                    onTap: () => setSheetState(() => selected = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.accent.withOpacity(0.2)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel
                              ? AppColors.accent
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        '${cat.emoji} ${cat.displayNameTr}',
                        style: TextStyle(
                          color: isSel
                              ? AppColors.accent
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Aylık limit (TL)',
                  prefixText: '₺ ',
                  prefixStyle: TextStyle(color: AppColors.accent),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selected == null) return;
                    final amount = double.tryParse(controller.text);
                    if (amount == null || amount <= 0) return;

                    final now = DateTime.now();
                    final budget = Budget(
                      id: const Uuid().v4(),
                      category: selected!,
                      limitAmount: amount,
                      spentAmount: 0,
                      month: DateTime(now.year, now.month),
                    );

                    await ref.read(dbHelperProvider).upsertBudget(budget);
                    _refresh();
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final Budget budget;
  final VoidCallback onRefresh;

  const _BudgetCard({required this.budget, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: budget.status == BudgetStatus.danger
                ? AppColors.danger.withOpacity(0.3)
                : budget.status == BudgetStatus.warning
                    ? AppColors.warning.withOpacity(0.3)
                    : const Color(0xFF1F2937),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            BudgetProgressBar(budget: budget),
            if (budget.status == BudgetStatus.danger) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${budget.category.displayNameTr} bütçesi aşıldı! '
                        '${budget.overspentAmount.toStringAsFixed(0)} TL fazla harcama yapıldı.',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '₺${(value.abs() / 1000).toStringAsFixed(1)}B',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: const Color(0xFF1F2937),
    );
  }
}
