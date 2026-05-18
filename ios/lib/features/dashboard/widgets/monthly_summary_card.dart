// Aylık gelir/gider/tasarruf özet kartı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers.dart';

/// Aylık finansal özet kartı - gelir, gider, tasarruf
class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final now = DateTime.now();
    final monthNames = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${monthNames[now.month]} ${now.year}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Aylık Özet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            summaryAsync.when(
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: _SummaryItem(
                      label: 'Gelir',
                      amount: summary.income,
                      color: AppColors.success,
                      icon: Icons.arrow_downward,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: const Color(0xFF1F2937),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: 'Gider',
                      amount: summary.expense,
                      color: AppColors.danger,
                      icon: Icons.arrow_upward,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: const Color(0xFF1F2937),
                  ),
                  Expanded(
                    child: _SummaryItem(
                      label: 'Tasarruf',
                      amount: summary.savings,
                      color: summary.savings >= 0
                          ? AppColors.accent
                          : AppColors.danger,
                      icon: Icons.savings_outlined,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(
                child: SizedBox(
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
              error: (_, __) => const Text(
                'Veri yüklenemedi',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  String _formatAmount(double amount) {
    final abs = amount.abs();
    if (abs >= 1000) {
      return '₺${(abs / 1000).toStringAsFixed(1)}B';
    }
    return '₺${abs.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 6),
        Text(
          _formatAmount(amount),
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
