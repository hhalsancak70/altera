// Ajan karar şeffaflık merkezi - jüri favorisi
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/agents/orchestrator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/agent_log_entry.dart';
import '../../core/providers.dart';
import 'widgets/agent_flow_diagram.dart';
import 'widgets/agent_metrics_card.dart';
import 'widgets/log_entry_card.dart';

/// Ajan aktivite ve karar şeffaflık merkezi.
/// Her ajanın her kararını gerekçesiyle gösterir.
class AgentLogScreen extends ConsumerStatefulWidget {
  const AgentLogScreen({super.key});

  @override
  ConsumerState<AgentLogScreen> createState() => _AgentLogScreenState();
}

class _AgentLogScreenState extends ConsumerState<AgentLogScreen> {
  AgentType? _selectedAgent;

  @override
  Widget build(BuildContext context) {
    final orchestratorState = ref.watch(orchestratorProvider);
    final logsAsync = ref.watch(recentAgentLogsProvider);

    // Döngü tamamlanınca logları ve bütçeyi yenile
    ref.listen(orchestratorProvider, (prev, next) {
      if (next is OrchestratorStateIdle && prev != null && prev.isRunning) {
        ref.invalidate(recentAgentLogsProvider);
        ref.invalidate(currentMonthBudgetsProvider);
        ref.invalidate(monthlySummaryProvider);
        ref.invalidate(monthlySpendingProvider);
      }
    });
    final isRunning = orchestratorState.isRunning;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Row(
          children: [
            const Text('Ajan Aktivitesi'),
            const SizedBox(width: 8),
            AnimatedOpacity(
              opacity: isRunning ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
            onPressed: () => _clearLogs(context),
            tooltip: 'Logları temizle',
          ),
        ],
      ),
      body: Column(
        children: [
          // Akış diyagramı
          const AgentFlowDiagram(),
          const SizedBox(height: 8),

          // Bugünkü metrikler
          logsAsync.maybeWhen(
            data: (logs) => AgentMetricsCard(logs: logs),
            orElse: () => const SizedBox.shrink(),
          ),

          // Ajan filtre çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _AgentChip(
                  label: 'Tümü',
                  isSelected: _selectedAgent == null,
                  onTap: () => setState(() => _selectedAgent = null),
                ),
                const SizedBox(width: 8),
                ...AgentType.values.map((a) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AgentChip(
                        label: a.displayNameTr,
                        isSelected: _selectedAgent == a,
                        onTap: () => setState(() => _selectedAgent = a),
                        isGemini: a == AgentType.analysis,
                      ),
                    )),
              ],
            ),
          ),

          // Log listesi
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                final filtered = _selectedAgent == null
                    ? logs
                    : logs.where((l) => l.agent == _selectedAgent).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.smart_toy_outlined,
                          color: AppColors.textSecondary,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Henüz log kaydı yok',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: orchestratorState.isRunning
                              ? null
                              : () => ref
                                  .read(orchestratorProvider.notifier)
                                  .runOnce(),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Döngüyü Başlat'),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(recentAgentLogsProvider),
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        LogEntryCard(entry: filtered[i]),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Loglar yüklenemedi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _clearLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Logları Temizle',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Tüm ajan log kayıtları silinecek. Emin misin?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(dbHelperProvider).clearAllLogs();
      ref.invalidate(recentAgentLogsProvider);
    }
  }
}

class _AgentChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isGemini;

  const _AgentChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isGemini = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.2)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isGemini) ...[
              const Text('✨', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
