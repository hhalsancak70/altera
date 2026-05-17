import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/transaction.dart';
import '../../../core/providers.dart';
import '../../../core/services/ai_button_cooldown.dart';
import '../../../core/services/gemini_service.dart';

/// Dashboard'da Gemini'nin detaylı finansal raporunu gösteren kart.
/// "Detaylı Analiz" butonuna basınca full screen bottom sheet açılır.
class GeminiInsightCard extends ConsumerStatefulWidget {
  const GeminiInsightCard({super.key});

  @override
  ConsumerState<GeminiInsightCard> createState() => _GeminiInsightCardState();
}

class _GeminiInsightCardState extends ConsumerState<GeminiInsightCard> {
  DetailedFinancialReport? _report;
  bool _isLoading = false;
  String? _error;

  Future<void> _generateReport() async {
    if (!AiButtonCooldown.tryUse('insight')) {
      final secs = AiButtonCooldown.remainingSeconds('insight');
      setState(() => _error = 'Çok hızlı! $secs saniye sonra tekrar dene.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final gemini = await ref.read(geminiServiceProvider.future);
      final db = ref.read(dbHelperProvider);
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      final spending = await db.getMonthlySpendingByCategory(now);
      final prevSpending = await db.getMonthlySpendingByCategory(lastMonth);
      final income = await db.getMonthlyIncome(now);
      final expense = await db.getMonthlyExpense(now);
      final savings = income - expense;

      // İhtiyaç/istek sayısı için bu ayki tüm işlemleri çek
      final monthTx = await db.getTransactions(
        fromDate: DateTime(now.year, now.month, 1),
      );
      final needCount =
          monthTx.where((t) => t.type == TransactionType.need).length;
      final wantCount =
          monthTx.where((t) => t.type == TransactionType.want).length;

      final budgets = await db.getBudgetsForMonth(now);
      final budgetMap = <TransactionCategory, double>{
        for (final b in budgets) b.category: b.limitAmount,
      };

      final report = await gemini.generateDetailedReport(
        spending: spending,
        previousMonthSpending: prevSpending,
        budgets: budgetMap,
        monthlyIncome: income,
        monthlyExpense: expense,
        savings: savings,
        needCount: needCount,
        wantCount: wantCount,
      );

      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });

      // Rapor hazır → otomatik bottom sheet aç
      if (mounted) _showReportSheet();
    } on GeminiException catch (e) {
      if (mounted) {
        setState(() {
          if (e.isQuotaExceeded) {
            final wait = e.retryAfterSeconds != null
                ? '${e.retryAfterSeconds} sn'
                : 'birkaç dakika';
            _error = 'Gemini kotası doldu — $wait sonra tekrar dene';
          } else {
            _error = e.message;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Bağlantı hatası. Tekrar dene.';
          _isLoading = false;
        });
      }
    }
  }

  void _showReportSheet() {
    if (_report == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReportSheet(report: _report!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.primary, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gemini Detaylı Tahlil',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Kategori analizi, tasarruf engelleri, aksiyon önerileri',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_report != null && !_isLoading)
                    IconButton(
                      onPressed: _generateReport,
                      icon: const Icon(Icons.refresh,
                          color: AppColors.textSecondary, size: 18),
                      tooltip: 'Yenile',
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1F2937)),
            if (_report == null && !_isLoading && _error == null)
              _GenerateButton(onTap: _generateReport)
            else if (_isLoading)
              const _LoadingState()
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _generateReport)
            else
              _ReportPreview(
                report: _report!,
                onOpen: _showReportSheet,
              ),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GenerateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Detaylı Analiz Yap',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
          SizedBox(height: 12),
          Text(
            'Gemini detaylı analiz ediyor...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(color: AppColors.warning, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: const Text('Tekrar dene',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}

/// Karttaki kompakt önizleme — özet + skor + "Detaylı Gör" butonu
class _ReportPreview extends StatelessWidget {
  final DetailedFinancialReport report;
  final VoidCallback onOpen;

  const _ReportPreview({required this.report, required this.onOpen});

  Color get _scoreColor {
    if (report.overallScore >= 70) return AppColors.success;
    if (report.overallScore >= 50) return AppColors.warning;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _scoreColor, width: 2),
                ),
                child: Text(
                  '${report.overallScore}',
                  style: TextStyle(
                    color: _scoreColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finansal Sağlık Skoru',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '/ 100',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.summary,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.analytics_outlined, size: 16),
              label: const Text('Detaylı Tahlili Aç'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full screen bottom sheet — rapor detayı
class _ReportSheet extends StatelessWidget {
  final DetailedFinancialReport report;

  const _ReportSheet({required this.report});

  Color _verdictColor(String verdict) {
    final v = verdict.toLowerCase();
    if (v.contains('iyi')) return AppColors.success;
    if (v.contains('dikkat')) return AppColors.warning;
    if (v.contains('kritik')) return AppColors.danger;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Gemini Detaylı Tahlil',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // Özet
                  const _SectionTitle(icon: Icons.summarize, title: 'Genel Özet'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.summary,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Kategori analizleri
                  if (report.categoryAnalyses.isNotEmpty) ...[
                    const _SectionTitle(
                        icon: Icons.category, title: 'Kategori Bazlı Analiz'),
                    const SizedBox(height: 8),
                    ...report.categoryAnalyses.map((ca) => _CategoryRow(
                          analysis: ca,
                          verdictColor: _verdictColor(ca.verdict),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Tasarruf engelleri
                  if (report.savingsBlockers.isNotEmpty) ...[
                    const _SectionTitle(
                        icon: Icons.block, title: 'Tasarruf Engelleri'),
                    const SizedBox(height: 8),
                    ...report.savingsBlockers.map((b) => _BulletItem(
                          text: b,
                          color: AppColors.warning,
                          icon: Icons.warning_amber,
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Aksiyon önerileri
                  if (report.actions.isNotEmpty) ...[
                    const _SectionTitle(
                        icon: Icons.task_alt, title: 'Önerilen Aksiyonlar'),
                    const SizedBox(height: 8),
                    ...report.actions.map((a) => _BulletItem(
                          text: a,
                          color: AppColors.success,
                          icon: Icons.check_circle_outline,
                        )),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryAnalysis analysis;
  final Color verdictColor;
  const _CategoryRow({required this.analysis, required this.verdictColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: verdictColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(analysis.category.emoji,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                analysis.category.displayNameTr,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: verdictColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  analysis.verdict,
                  style: TextStyle(
                    color: verdictColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            analysis.comment,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _BulletItem({
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
