// Kategori bazlı harcama dağılımı pasta grafiği
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transaction.dart';
import '../../../core/providers.dart';

/// fl_chart PieChart ile kategori harcama dağılımı.
/// Tıklanan dilim büyür + altında kategori detayı açılır.
class SpendingPieChart extends ConsumerStatefulWidget {
  const SpendingPieChart({super.key});

  @override
  ConsumerState<SpendingPieChart> createState() => _SpendingPieChartState();
}

class _SpendingPieChartState extends ConsumerState<SpendingPieChart> {
  int _touchedIndex = -1;

  static Color _categoryColor(TransactionCategory category) {
    return switch (category) {
      TransactionCategory.market => AppColors.categoryMarket,
      TransactionCategory.restaurant => AppColors.categoryRestaurant,
      TransactionCategory.transport => AppColors.categoryTransport,
      TransactionCategory.bill => AppColors.categoryBill,
      TransactionCategory.clothing => AppColors.categoryClothing,
      TransactionCategory.entertainment => AppColors.categoryEntertainment,
      TransactionCategory.health => AppColors.categoryHealth,
      TransactionCategory.education => AppColors.categoryEducation,
      TransactionCategory.investment => AppColors.categoryInvestment,
      TransactionCategory.income => AppColors.categoryIncome,
      TransactionCategory.other => AppColors.categoryOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final spendingAsync = ref.watch(monthlySpendingProvider);

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
              'Harcama Dağılımı',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            spendingAsync.when(
              data: (spending) {
                if (spending.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Henüz işlem verisi yok',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }

                final total = spending.values.fold(0.0, (a, b) => a + b);
                final entries =
                    spending.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));

                return Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              pieTouchData: PieTouchData(
                                touchCallback: (event, response) {
                                  if (!event.isInterestedForInteractions ||
                                      response == null ||
                                      response.touchedSection == null) {
                                    setState(() => _touchedIndex = -1);
                                    return;
                                  }
                                  setState(() {
                                    _touchedIndex =
                                        response
                                            .touchedSection!
                                            .touchedSectionIndex;
                                  });
                                },
                              ),
                              sections:
                                  entries.asMap().entries.map((e) {
                                    final isSelected = e.key == _touchedIndex;
                                    final cat = e.value.key;
                                    final val = e.value.value;
                                    return PieChartSectionData(
                                      color: _categoryColor(cat),
                                      value: val,
                                      radius: isSelected ? 72 : 60,
                                      showTitle: isSelected,
                                      title:
                                          isSelected
                                              ? '${(val / total * 100).toStringAsFixed(0)}%'
                                              : '',
                                      titleStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    );
                                  }).toList(),
                              centerSpaceRadius: 52,
                              sectionsSpace: 2,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Toplam',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '₺${(total / 1000).toStringAsFixed(1)}B',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Kategori listesi (en yüksekten)
                    ...entries
                        .take(6)
                        .map(
                          (e) => _LegendItem(
                            category: e.key,
                            amount: e.value,
                            total: total,
                            color: _categoryColor(e.key),
                          ),
                        ),
                  ],
                );
              },
              loading:
                  () => const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
              error:
                  (_, __) => const Text(
                    'Grafik yüklenemedi',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final TransactionCategory category;
  final double amount;
  final double total;
  final Color color;

  const _LegendItem({
    required this.category,
    required this.amount,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (amount / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '${category.emoji} ${category.displayNameTr}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '%${pct.toStringAsFixed(0)}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
