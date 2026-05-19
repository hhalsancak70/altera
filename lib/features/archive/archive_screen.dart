// Geçmiş aylara ait arşivlenmiş istatistikler ekranı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/monthly_archive.dart';
import '../../core/providers.dart';

/// Geçmiş ay istatistikleri arşiv ekranı.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivesAsync = ref.watch(monthlyArchivesProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Geçmiş Aylar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: archivesAsync.when(
        data: (archives) {
          if (archives.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 64,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Henüz arşiv yok',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'İlk döngü günü geldiğinde geçen ayın '
                      'istatistikleri burada görünecek.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: archives.length,
            itemBuilder: (ctx, i) => _ArchiveCard(archive: archives[i]),
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
        error:
            (e, _) => Center(
              child: Text(
                'Arşiv yüklenemedi: $e',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
      ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final MonthlyArchive archive;

  const _ArchiveCard({required this.archive});

  @override
  Widget build(BuildContext context) {
    final isPositiveSavings = archive.totalSavings >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${archive.monthNameTr} ${archive.year}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      isPositiveSavings
                          ? Colors.greenAccent.withAlpha(40)
                          : Colors.redAccent.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPositiveSavings
                      ? '+₺${archive.totalSavings.toStringAsFixed(0)}'
                      : '-₺${archive.totalSavings.abs().toStringAsFixed(0)}',
                  style: TextStyle(
                    color:
                        isPositiveSavings
                            ? Colors.greenAccent
                            : Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Gelir / Gider satırları
          _StatRow(
            label: 'Gelir',
            value: '₺${archive.totalIncome.toStringAsFixed(0)}',
            color: Colors.greenAccent,
          ),
          const SizedBox(height: 8),
          _StatRow(
            label: 'Gider',
            value: '₺${archive.totalExpense.toStringAsFixed(0)}',
            color: Colors.redAccent,
          ),

          if (archive.topCategoryDisplay != null) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppColors.textSecondary, height: 1),
            ),
            Row(
              children: [
                const Text(
                  'En fazla harcama: ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  archive.topCategoryDisplay!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Text(
            '${archive.transactionCount} işlem',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
