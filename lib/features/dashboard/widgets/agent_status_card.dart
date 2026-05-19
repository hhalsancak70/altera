// Orchestrator durumunu gösteren kart widget'ı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agents/orchestrator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers.dart';

/// Orchestrator durumunu gösteren kart.
/// IDLE: "Ajan hazır" - sakin lacivert
/// COLLECTING: "Veri toplanıyor..." - animasyonlu mavi
/// ANALYZING: "Gemini analiz ediyor..." - animasyonlu, Gemini rozeti
/// ACTING: "Aksiyonlar alınıyor..." - yeşil
class AgentStatusCard extends ConsumerStatefulWidget {
  const AgentStatusCard({super.key});

  @override
  ConsumerState<AgentStatusCard> createState() => _AgentStatusCardState();
}

class _AgentStatusCardState extends ConsumerState<AgentStatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orchestratorProvider);

    final config = _getConfig(state);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: config.borderColor.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Animasyonlu durum ikonu
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Opacity(
                  opacity: state.isRunning ? _animation.value : 1.0,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: config.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(config.icon, color: config.iconColor, size: 22),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (state is OrchestratorStateCompleted)
              _CompletedBadge(state: state),
          ],
        ),
      ),
    );
  }

  _CardConfig _getConfig(OrchestratorState state) {
    return switch (state) {
      OrchestratorStateIdle idle => _CardConfig(
        title: 'ALTERA Ajan Hazır',
        subtitle:
            idle.lastRunAt != null
                ? 'Son çalışma: ${_formatTime(idle.lastRunAt!)}'
                : 'Döngüyü başlatmak için FAB\'a bas',
        icon: Icons.smart_toy_outlined,
        iconColor: AppColors.accent,
        iconBg: AppColors.accent.withOpacity(0.15),
        borderColor: AppColors.accent,
      ),
      OrchestratorStateCollecting() => _CardConfig(
        title: 'Veri Toplanıyor...',
        subtitle: 'Banka işlemleri çekiliyor',
        icon: Icons.cloud_download_outlined,
        iconColor: AppColors.info,
        iconBg: AppColors.info.withOpacity(0.15),
        borderColor: AppColors.info,
      ),
      OrchestratorStateAnalyzing a => _CardConfig(
        title: 'Gemini Analiz Ediyor...',
        subtitle: '${a.collectedCount} yeni işlem kategorize ediliyor',
        icon: Icons.auto_awesome,
        iconColor: AppColors.accent,
        iconBg: AppColors.accent.withOpacity(0.15),
        borderColor: AppColors.accent,
      ),
      OrchestratorStateActing a => _CardConfig(
        title: 'Aksiyonlar Alınıyor...',
        subtitle: '${a.analyzedCount} işlem analiz edildi',
        icon: Icons.flash_on,
        iconColor: AppColors.warning,
        iconBg: AppColors.warning.withOpacity(0.15),
        borderColor: AppColors.warning,
      ),
      OrchestratorStateCompleted() => _CardConfig(
        title: 'Döngü Tamamlandı ✓',
        subtitle: 'Tüm ajanlar başarıyla çalıştı',
        icon: Icons.check_circle_outline,
        iconColor: AppColors.success,
        iconBg: AppColors.success.withOpacity(0.15),
        borderColor: AppColors.success,
      ),
      OrchestratorStateError e => _CardConfig(
        title: 'Hata Oluştu',
        subtitle: e.message,
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        iconBg: AppColors.danger.withOpacity(0.15),
        borderColor: AppColors.danger,
      ),
    };
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CardConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color borderColor;

  const _CardConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.borderColor,
  });
}

class _CompletedBadge extends StatelessWidget {
  final OrchestratorStateCompleted state;

  const _CompletedBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Stat(label: 'İşlem', value: '${state.collectedCount}'),
        _Stat(label: 'Analiz', value: '${state.analyzedCount}'),
        _Stat(label: 'Aksiyon', value: '${state.actionsCount}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.success,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
