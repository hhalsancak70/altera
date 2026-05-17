// Ajan Aktivitesi ekranı için günlük metrik kartı
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/agent_log_entry.dart';

/// Bugünkü log verilerinden metrik özetleri üretip kart olarak gösterir.
/// - Toplam log
/// - Başarı / uyarı / hata sayıları
/// - Gemini ortalama yanıt süresi
class AgentMetricsCard extends StatelessWidget {
  final List<AgentLogEntry> logs;

  const AgentMetricsCard({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayLogs = logs.where((l) {
      return l.timestamp.year == today.year &&
          l.timestamp.month == today.month &&
          l.timestamp.day == today.day;
    }).toList();

    final total = todayLogs.length;
    final successCount =
        todayLogs.where((l) => l.level == LogLevel.success).length;
    final warningCount =
        todayLogs.where((l) => l.level == LogLevel.warning).length;
    final errorCount =
        todayLogs.where((l) => l.level == LogLevel.error).length;

    // Gemini ortalama süre
    final geminiLogs = todayLogs
        .where((l) => l.agent == AgentType.analysis && l.durationMs > 0)
        .toList();
    final avgGeminiMs = geminiLogs.isEmpty
        ? 0
        : geminiLogs.fold<int>(0, (s, l) => s + l.durationMs) ~/
            geminiLogs.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined,
                  color: AppColors.accent, size: 14),
              const SizedBox(width: 6),
              const Text(
                'BUGÜNKÜ METRİKLER',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              Text(
                '$total kayıt',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MetricChip(
                icon: Icons.check_circle,
                label: 'Başarı',
                value: '$successCount',
                color: AppColors.success,
              ),
              const SizedBox(width: 6),
              _MetricChip(
                icon: Icons.warning_amber,
                label: 'Uyarı',
                value: '$warningCount',
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              _MetricChip(
                icon: Icons.error_outline,
                label: 'Hata',
                value: '$errorCount',
                color: AppColors.danger,
              ),
            ],
          ),
          if (avgGeminiMs > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 11)),
                const SizedBox(width: 4),
                Text(
                  'Gemini ortalama: ${(avgGeminiMs / 1000).toStringAsFixed(2)}s',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '${geminiLogs.length} çağrı',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 12),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
