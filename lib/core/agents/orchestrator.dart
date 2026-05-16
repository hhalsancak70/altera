// ALTERA Baş Ajan: Orchestrator - LangGraph ilhamlı durum makinesi
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/agent_log_entry.dart';
import 'data_collection_agent.dart';
import 'analysis_agent.dart';
import 'action_agent.dart';

// ─────────────────────────────────────────────────────────────
// ORCHESTRATOR DURUM SINIFI
// ─────────────────────────────────────────────────────────────

/// Orchestrator'ın anlık çalışma durumu - sealed class ile tip güvenliği
sealed class OrchestratorState {
  const OrchestratorState();
  bool get isRunning => this is! OrchestratorStateIdle;
}

/// Ajan bekleme durumu
class OrchestratorStateIdle extends OrchestratorState {
  final int? lastCollectedCount;
  final int? lastAnalyzedCount;
  final int? lastActionsCount;
  final DateTime? lastRunAt;

  const OrchestratorStateIdle({
    this.lastCollectedCount,
    this.lastAnalyzedCount,
    this.lastActionsCount,
    this.lastRunAt,
  });
}

/// Veri toplama ajanı çalışıyor
class OrchestratorStateCollecting extends OrchestratorState {
  const OrchestratorStateCollecting();
}

/// Gemini analiz ajanı çalışıyor
class OrchestratorStateAnalyzing extends OrchestratorState {
  final int collectedCount;

  const OrchestratorStateAnalyzing({required this.collectedCount});
}

/// Aksiyon ajanı çalışıyor
class OrchestratorStateActing extends OrchestratorState {
  final int analyzedCount;

  const OrchestratorStateActing({required this.analyzedCount});
}

/// Döngü tamamlandı - kısa süre gösterilir, sonra idle'a döner
class OrchestratorStateCompleted extends OrchestratorState {
  final int collectedCount;
  final int analyzedCount;
  final int actionsCount;

  const OrchestratorStateCompleted({
    required this.collectedCount,
    required this.analyzedCount,
    required this.actionsCount,
  });
}

/// Hata durumu
class OrchestratorStateError extends OrchestratorState {
  final String message;

  const OrchestratorStateError({required this.message});
}

// ─────────────────────────────────────────────────────────────
// ORCHESTRATOR
// ─────────────────────────────────────────────────────────────

/// ALTERA Baş Ajan: Orchestrator
///
/// LangGraph'tan ilham alan durum makinesi.
/// 3 ajanı sıralı olarak çalıştırır, her adımı loglar.
///
/// Akış:
///   IDLE → COLLECTING → ANALYZING → ACTING → IDLE
///
/// Riverpod StateNotifier ile UI'ya anlık durum iletir.
/// Arka planda döngü çalıştırır (her kAgentCycleIntervalSeconds saniyede).
///
/// Örnek kullanım:
/// ```dart
/// final orchestrator = ref.read(orchestratorProvider.notifier);
/// await orchestrator.runOnce(); // Manuel tetikleme
/// orchestrator.startAutoMode(); // Otomatik döngü
/// ```
class Orchestrator extends StateNotifier<OrchestratorState> {
  final DataCollectionAgent _dataAgent;
  final AnalysisAgent _analysisAgent;
  final ActionAgent _actionAgent;
  final DbHelper _dbHelper;

  Timer? _autoTimer;
  final _uuid = const Uuid();

  Orchestrator({
    required DataCollectionAgent dataAgent,
    required AnalysisAgent analysisAgent,
    required ActionAgent actionAgent,
    required DbHelper dbHelper,
  })  : _dataAgent = dataAgent,
        _analysisAgent = analysisAgent,
        _actionAgent = actionAgent,
        _dbHelper = dbHelper,
        super(const OrchestratorStateIdle());

  /// Tek seferlik ajan döngüsü - UI butonundan veya otomatik moddan çağrılır
  Future<void> runOnce() async {
    if (state.isRunning) {
      _log('orchestrator', 'Döngü zaten çalışıyor, atlandı', LogLevel.warning);
      return;
    }

    _log('orchestrator', '─── Ajan döngüsü başladı ───', LogLevel.info);

    // ─── AŞAMA 1: VERİ TOPLAMA ───
    state = const OrchestratorStateCollecting();

    late DataCollectionResult collectionResult;
    try {
      collectionResult = await _dataAgent.run(logCallback: _log);
    } catch (e) {
      state = OrchestratorStateError(message: 'Veri toplama hatası: $e');
      _log('orchestrator', 'Döngü hatayla sonlandı: $e', LogLevel.error);
      await Future.delayed(const Duration(seconds: 3));
      state = const OrchestratorStateIdle();
      return;
    }

    // ─── AŞAMA 2: GEMİNİ ANALİZİ ───
    state = OrchestratorStateAnalyzing(
        collectedCount: collectionResult.newTransactionsCount);

    late AnalysisResult analysisResult;
    try {
      analysisResult = await _analysisAgent.run(logCallback: _log);
    } catch (e) {
      // Analiz hatası tolere edilebilir - aksiyon aşamasına geç
      _log('orchestrator', 'Analiz hatası: $e', LogLevel.error);
      analysisResult = const AnalysisResult(
        analyzedCount: 0,
        failedCount: 0,
        categoryDistribution: {},
        durationMs: 0,
      );
    }

    // ─── AŞAMA 3: AKSİYONLAR ───
    state = OrchestratorStateActing(
        analyzedCount: analysisResult.analyzedCount);

    late ActionResult actionResult;
    try {
      actionResult = await _actionAgent.run(logCallback: _log);
    } catch (e) {
      _log('orchestrator', 'Aksiyon hatası: $e', LogLevel.error);
      actionResult = const ActionResult(actionsPerformed: [], durationMs: 0);
    }

    // ─── TAMAMLANDI ───
    final completed = OrchestratorStateCompleted(
      collectedCount: collectionResult.newTransactionsCount,
      analyzedCount: analysisResult.analyzedCount,
      actionsCount: actionResult.actionsPerformed.length,
    );
    state = completed;

    _log(
      'orchestrator',
      '─── Döngü tamamlandı ✓ (toplanan: ${completed.collectedCount}, analiz: ${completed.analyzedCount}, aksiyon: ${completed.actionsCount}) ───',
      LogLevel.success,
    );

    // Kısa süre tamamlandı ekranını göster, sonra idle'a dön
    await Future.delayed(
        Duration(milliseconds: AppConstants.kAgentCompletedDelayMs));

    if (mounted) {
      state = OrchestratorStateIdle(
        lastCollectedCount: completed.collectedCount,
        lastAnalyzedCount: completed.analyzedCount,
        lastActionsCount: completed.actionsCount,
        lastRunAt: DateTime.now(),
      );
    }
  }

  /// Otomatik döngüyü başlatır - her kAgentCycleIntervalSeconds saniyede çalışır
  void startAutoMode() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      Duration(seconds: AppConstants.kAgentCycleIntervalSeconds),
      (_) => runOnce(),
    );
    _log('orchestrator', 'Otomatik mod aktif', LogLevel.info);
  }

  /// Otomatik döngüyü durdurur
  void stopAutoMode() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _log('orchestrator', 'Otomatik mod durduruldu', LogLevel.info);
  }

  bool get isAutoModeActive => _autoTimer?.isActive ?? false;

  /// Her ajan aksiyonunu veritabanına kaydeden internal metot
  void _log(String agentStr, String message, LogLevel level) {
    final agentType = AgentType.values.firstWhere(
      (a) => a.shortName == agentStr,
      orElse: () => AgentType.orchestrator,
    );

    _dbHelper.insertLog(AgentLogEntry(
      id: _uuid.v4(),
      agent: agentType,
      message: message,
      timestamp: DateTime.now(),
      level: level,
    ));
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }
}
