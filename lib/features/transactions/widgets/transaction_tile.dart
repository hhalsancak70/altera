// Tek işlem satırı widget'ı
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transaction.dart';

/// Tek işlem satırı.
/// Sol: Kategori ikonu, Orta: Açıklama + tarih, Sağ: Tutar
/// Alt: İhtiyaç/İstek rozeti + kategori etiketi
/// Tıklandığında detay modal gösterilir
class TransactionTile extends StatelessWidget {
  final Transaction tx;

  const TransactionTile({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Kategori ikonu
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(tx.category.emoji,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                // Açıklama ve tarih
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tx.date.day}.${tx.date.month}.${tx.date.year}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tutar
                Text(
                  '${tx.amount > 0 ? '+' : ''}₺${tx.amount.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    color: tx.amount > 0 ? AppColors.income : AppColors.expense,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            // Etiketler
            const SizedBox(height: 8),
            Row(
              children: [
                // Kategori etiketi
                _Badge(
                  label: tx.category.displayNameTr,
                  color: AppColors.textSecondary.withOpacity(0.15),
                  textColor: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                // Analiz durumu / tür rozeti
                if (tx.isAnalyzed)
                  _Badge(
                    label: tx.type.displayNameTr,
                    color: tx.type == TransactionType.income
                        ? AppColors.success.withOpacity(0.15)
                        : tx.type == TransactionType.need
                            ? AppColors.info.withOpacity(0.15)
                            : AppColors.warning.withOpacity(0.15),
                    textColor: tx.type == TransactionType.income
                        ? AppColors.success
                        : tx.type == TransactionType.need
                            ? AppColors.info
                            : AppColors.warning,
                  )
                else
                  _Badge(
                    label: '⏳ Analiz Bekliyor',
                    color: AppColors.surfaceLight,
                    textColor: AppColors.textTertiary,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tx.category.emoji,
                    style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tx.description,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Tutar',
              value: '${tx.amount > 0 ? '+' : ''}₺${tx.amount.abs().toStringAsFixed(2)}',
              valueColor: tx.amount > 0 ? AppColors.income : AppColors.expense,
            ),
            _DetailRow(
              label: 'Tarih',
              value: '${tx.date.day}.${tx.date.month}.${tx.date.year} ${tx.date.hour}:${tx.date.minute.toString().padLeft(2, '0')}',
            ),
            _DetailRow(
              label: 'Kategori',
              value: tx.category.displayNameTr,
            ),
            _DetailRow(
              label: 'Tür',
              value: tx.type.displayNameTr,
            ),
            if (tx.aiReason != null) ...[
              const SizedBox(height: 12),
              const Text(
                '✨ Gemini Gerekçesi',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tx.aiReason!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
