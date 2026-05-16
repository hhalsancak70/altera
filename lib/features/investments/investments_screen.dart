// Yatırım önerileri ve simüle transfer ekranı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/investment_fund.dart';
import '../../core/providers.dart';

/// Yatırım önerileri ve simüle transfer ekranı.
class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fundsAsync = ref.watch(investmentFundsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final historyAsync = ref.watch(investmentHistoryProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Yatırım'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Risk profili kartı
          profileAsync.when(
            data: (profile) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFF1F2937), width: 1),
                ),
                child: Row(
                  children: [
                    Text(
                      profile.riskProfile.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Risk Profilin',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            profile.riskProfile.displayNameTr,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            profile.riskProfile.descriptionTr,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Ay sonu tasarruf tahmini
          summaryAsync.when(
            data: (summary) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.savings_outlined,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bu Ay Tasarruf',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₺${summary.savings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (summary.savings > 500)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Yatırıma Hazır!',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Yatırım fonları başlığı
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Mevcut Fonlar',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Fon kartları
          fundsAsync.when(
            data: (funds) => Column(
              children: funds
                  .map((f) => _InvestmentFundCard(
                        fund: f,
                        onTransfer: (amount) async {
                          await _executeTransfer(context, ref, f, amount);
                        },
                      ))
                  .toList(),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
            error: (_, __) => const Center(
              child: Text('Fonlar yüklenemedi',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),

          // Yatırım geçmişi
          historyAsync.when(
            data: (history) {
              if (history.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Geçmiş Transferler',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...history.map((h) => _HistoryTile(record: h)),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransfer(
    BuildContext context,
    WidgetRef ref,
    InvestmentFund fund,
    double amount,
  ) async {
    final bank = ref.read(bankMockServiceProvider);
    final db = ref.read(dbHelperProvider);

    final result = await bank.executeInvestmentTransfer(
      fundId: fund.id,
      amount: amount,
      reason: 'Manuel transfer',
    );

    if (result.success) {
      await db.insertInvestmentRecord(
        id: result.transferId,
        fundId: fund.id,
        fundName: fund.name,
        amount: amount,
        action: 'buy',
        aiReason: 'Kullanıcı tarafından manuel transfer',
      );

      ref.invalidate(investmentHistoryProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ ₺${amount.toStringAsFixed(0)} ${fund.name}\'a aktarıldı'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer başarısız oldu, tekrar deneyin'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

class _InvestmentFundCard extends StatelessWidget {
  final InvestmentFund fund;
  final Future<void> Function(double amount) onTransfer;

  const _InvestmentFundCard({required this.fund, required this.onTransfer});

  Color get _riskColor {
    return switch (fund.riskLevel) {
      RiskLevel.low => AppColors.success,
      RiskLevel.medium => AppColors.warning,
      RiskLevel.high => AppColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fund.isRecommended
                ? AppColors.accent.withOpacity(0.3)
                : const Color(0xFF1F2937),
            width: fund.isRecommended ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(fund.type.emoji,
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            fund.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (fund.isRecommended) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '✨ Gemini Öneriyor',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        fund.code,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '%${fund.annualReturnRate}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'yıllık getiri',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              fund.description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _riskColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fund.riskLevel.displayNameTr,
                    style: TextStyle(
                      color: _riskColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => _showTransferDialog(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Aktar', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          '${fund.name}\'a Aktar',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Tutar (TL)',
            prefixText: '₺ ',
            prefixStyle: TextStyle(color: AppColors.accent),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(ctx);
                onTransfer(amount);
              }
            },
            child: const Text('Onayla'),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> record;

  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(record['date'] as String);
    final amount = (record['amount'] as num).toDouble();
    final fundName = record['fund_name'] as String? ?? '-';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fundName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${date.day}.${date.month}.${date.year}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '₺${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
