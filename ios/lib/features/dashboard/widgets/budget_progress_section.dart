// Bütçe doluluk çubukları bölümü
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/budget.dart';
import '../../../core/providers.dart';

/// Dashboard bütçe ilerleme bölümü - kategori bazlı çubuklar
class BudgetProgressSection extends ConsumerWidget {
  const BudgetProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(currentMonthBudgetsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bütçe Durumu',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            budgetsAsync.when(
              data: (budgets) {
                if (budgets.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Henüz bütçe tanımlanmadı. Bütçe sekmesinden ekleyebilirsin.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  );
                }
                return Column(
                  children: budgets
                      .map((b) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BudgetProgressBar(budget: b),
                          ))
                      .toList(),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              error: (_, __) => const Text(
                'Bütçe verileri yüklenemedi',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir bütçe kategorisi için doluluk çubuğu.
/// Yüzdeye göre renk değişir: safe=yeşil, warning=sarı, danger=kırmızı
class BudgetProgressBar extends StatelessWidget {
  final Budget budget;

  const BudgetProgressBar({super.key, required this.budget});

  Color get _barColor {
    return switch (budget.status) {
      BudgetStatus.safe => AppColors.success,
      BudgetStatus.warning => AppColors.warning,
      BudgetStatus.danger => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final pct = budget.usagePercentage.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${budget.category.emoji} ${budget.category.displayNameTr}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '₺${budget.spentAmount.toStringAsFixed(0)} / ₺${budget.limitAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              height: 6,
              width: MediaQuery.of(context).size.width * 0.7 * pct,
              decoration: BoxDecoration(
                color: _barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
        if (budget.status == BudgetStatus.danger) ...[
          const SizedBox(height: 4),
          Text(
            '${budget.overspentAmount.toStringAsFixed(0)} TL aşım',
            style: const TextStyle(
              color: AppColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
