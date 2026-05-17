// ALTERA Baş Ajan: Orchestrator - LangGraph ilhamlı durum makinesi
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../database/db_helper.dart';
import '../models/agent_log_entry.dart';
import '../services/gemini_service.dart';
import 'data_collection_agent.dart';
import 'analysis_agent.dart';
import 'action_agent.dart';

// ─────────────────────────────────────────────────────────────
// ORCHESTRATOR DURUM SINIFI
// ─────────────────────────────────────────────────────────────

sealed class OrchestratorState {
  const OrchestratorState();
  bool get isRunning => this is! OrchestratorStateIdle;
}

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

class OrchestratorStateCollecting extends OrchestratorState {
  const OrchestratorStateCollecting();
}

class OrchestratorStateAnalyzing extends OrchestratorState {
  final int collectedCount;
  const OrchestratorStateAnalyzing({required this.collectedCount});
}

class OrchestratorStateActing extends OrchestratorState {
  final int analyzedCount;
  const OrchestratorStateActing({required this.analyzedCount});
}

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

class OrchestratorStateError extends OrchestratorState {
  final String message;
  const OrchestratorStateError({required this.message});
}

// ─────────────────────────────────────────────────────────────
// ORCHESTRATOR
// ─────────────────────────────────────────────────────────────

/// ALTERA Baş Ajan: Orchestrator
///
/// Akış: IDLE → COLLECTING → ANALYZING → ACTING → IDLE
///
/// Ajan örnekleri callback ile sağlanır — Gemini yüklendiğinde
/// orchestrator yeniden yaratılmaz, her döngüde güncel ajanı okur.
class Orchestrator extends StateNotifier<OrchestratorState> {
  final DataCollectionAgent _dataAgent;
  final DbHelper _dbHelper;

  /// Her döngüde güncel ActionAgent'ı döndüren callback
  final ActionAgent Function() _getActionAgent;

  Timer? _autoTimer;
  final _uuid = const Uuid();

  Orchestrator({
    required DataCollectionAgent dataAgent,
    required DbHelper dbHelper,
    required ActionAgent Function() getActionAgent,
  })  : _dataAgent = dataAgent,
        _dbHelper = dbHelper,
        _getActionAgent = getActionAgent,
        super(const OrchestratorStateIdle());

  /// Tek seferlik ajan döngüsü
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
    if (!await GeminiService.hasApiKey()) {
      _log(
        'orchestrator',
        'Gemini API key bulunamadı — Ayarlar\'dan kaydet ve 💾 butonuna bas',
        LogLevel.warning,
      );
      analysisResult = const AnalysisResult(
        analyzedCount: 0,
        failedCount: 0,
        categoryDistribution: {},
        durationMs: 0,
      );
    } else {
      try {
        final gemini = await GeminiService.initialize();
        final analysisAgent = AnalysisAgent(
          gemini: gemini,
          dbHelper: _dbHelper,
        );
        analysisResult = await analysisAgent.run(logCallback: _log);
      } on GeminiException catch (e) {
        _log('orchestrator', 'Gemini: ${e.message}', LogLevel.warning);
        analysisResult = const AnalysisResult(
          analyzedCount: 0,
          failedCount: 0,
          categoryDistribution: {},
          durationMs: 0,
        );
      } catch (e) {
        _log('orchestrator', 'Analiz hatası: $e', LogLevel.error);
        analysisResult = const AnalysisResult(
          analyzedCount: 0,
          failedCount: 0,
          categoryDistribution: {},
          durationMs: 0,
        );
      }
    }

    // ─── AŞAMA 3: AKSİYONLAR ───
    state = OrchestratorStateActing(analyzedCount: analysisResult.analyzedCount);

    late ActionResult actionResult;
    try {
      actionResult = await _getActionAgent().run(logCallback: _log);
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

  void startAutoMode() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      Duration(seconds: AppConstants.kAgentCycleIntervalSeconds),
      (_) => runOnce(),
    );
    _log('orchestrator', 'Otomatik mod aktif', LogLevel.info);
  }

  void stopAutoMode() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _log('orchestrator', 'Otomatik mod durduruldu', LogLevel.info);
  }

  bool get isAutoModeActive => _autoTimer?.isActive ?? false;

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
