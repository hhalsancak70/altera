// Orchestrator akış diyagramı görsel widget'ı
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agents/orchestrator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers.dart';

/// Orchestrator akış diyagramını gösterir.
/// IDLE → COLLECTING → ANALYZING → ACTING → IDLE
/// Aktif adım vurgulanır (accent mavi, animated border)
class AgentFlowDiagram extends ConsumerWidget {
  const AgentFlowDiagram({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orchestratorProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1F2937), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajan Akışı',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _FlowStep(
                  label: 'Bekleme',
                  icon: Icons.pause_circle_outline,
                  isActive: state is OrchestratorStateIdle,
                  isCompleted: state is! OrchestratorStateIdle,
                ),
                _Arrow(
                  isActive:
                      state is OrchestratorStateCollecting ||
                      state is OrchestratorStateAnalyzing ||
                      state is OrchestratorStateActing ||
                      state is OrchestratorStateCompleted,
                ),
                _FlowStep(
                  label: 'Veri',
                  icon: Icons.cloud_download_outlined,
                  isActive: state is OrchestratorStateCollecting,
                  isCompleted:
                      state is OrchestratorStateAnalyzing ||
                      state is OrchestratorStateActing ||
                      state is OrchestratorStateCompleted,
                ),
                _Arrow(
                  isActive:
                      state is OrchestratorStateAnalyzing ||
                      state is OrchestratorStateActing ||
                      state is OrchestratorStateCompleted,
                ),
                _FlowStep(
                  label: 'Gemini',
                  icon: Icons.auto_awesome,
                  isActive: state is OrchestratorStateAnalyzing,
                  isCompleted:
                      state is OrchestratorStateActing ||
                      state is OrchestratorStateCompleted,
                ),
                _Arrow(
                  isActive:
                      state is OrchestratorStateActing ||
                      state is OrchestratorStateCompleted,
                ),
                _FlowStep(
                  label: 'Aksiyon',
                  icon: Icons.flash_on,
                  isActive: state is OrchestratorStateActing,
                  isCompleted: state is OrchestratorStateCompleted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isCompleted;

  const _FlowStep({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color iconColor;
    Color borderColor;

    if (isActive) {
      bgColor = AppColors.accent.withOpacity(0.2);
      iconColor = AppColors.accent;
      borderColor = AppColors.accent;
    } else if (isCompleted) {
      bgColor = AppColors.success.withOpacity(0.15);
      iconColor = AppColors.success;
      borderColor = AppColors.success;
    } else {
      bgColor = AppColors.surfaceLight;
      iconColor = AppColors.textSecondary;
      borderColor = Colors.transparent;
    }

    return Expanded(
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:
                  isActive
                      ? AppColors.accent
                      : isCompleted
                      ? AppColors.success
                      : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final bool isActive;

  const _Arrow({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.arrow_forward,
      size: 14,
      color: isActive ? AppColors.accent : AppColors.textTertiary,
    );
  }
}
