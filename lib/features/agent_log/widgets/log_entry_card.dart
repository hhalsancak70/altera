// Tek ajan log kaydı kart widget'ı
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/agent_log_entry.dart';

/// Tek ajan log kaydı kartı.
/// Sol kenar rengi: info=mavi, success=yeşil, warning=sarı, error=kırmızı
/// Üst: Ajan adı rozeti + zaman damgası + süre (ms)
/// Orta: Mesaj
/// Alt (opsiyonel): Teknik detay (geniş letilebilir)
/// Gemini log'larında küçük ✨ ikonu
class LogEntryCard extends StatefulWidget {
  final AgentLogEntry entry;

  const LogEntryCard({super.key, required this.entry});

  @override
  State<LogEntryCard> createState() => _LogEntryCardState();
}

class _LogEntryCardState extends State<LogEntryCard> {
  bool _isExpanded = false;

  Color get _levelColor {
    return switch (widget.entry.level) {
      LogLevel.info => AppColors.info,
      LogLevel.success => AppColors.success,
      LogLevel.warning => AppColors.warning,
      LogLevel.error => AppColors.danger,
    };
  }

  Color get _agentBadgeColor {
    return switch (widget.entry.agent) {
      AgentType.orchestrator => const Color(0xFF8B5CF6),
      AgentType.dataCollection => AppColors.info,
      AgentType.analysis => AppColors.accent,
      AgentType.action => AppColors.warning,
    };
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: _levelColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _agentBadgeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.entry.isGeminiLog) ...[
                                  const Text(
                                    '✨',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  widget.entry.agent.displayNameTr,
                                  style: TextStyle(
                                    color: _agentBadgeColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(widget.entry.timestamp),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                          ),
                          if (widget.entry.durationMs > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '${widget.entry.durationMs}ms',
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.entry.message,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      if (widget.entry.detail != null) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap:
                              () => setState(() => _isExpanded = !_isExpanded),
                          child: Row(
                            children: [
                              Icon(
                                _isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: AppColors.textTertiary,
                                size: 14,
                              ),
                              Text(
                                _isExpanded ? 'Gizle' : 'Detayları Gör',
                                style: const TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isExpanded)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.entry.detail!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
