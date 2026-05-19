// Bir ajanın gerçekleştirdiği işlem veya kararı kaydeden model
import 'package:flutter/foundation.dart';

/// ALTERA ajan türleri
enum AgentType {
  orchestrator,
  dataCollection,
  analysis,
  action;

  String get displayNameTr {
    switch (this) {
      case AgentType.orchestrator:
        return 'Orchestrator';
      case AgentType.dataCollection:
        return 'Veri Toplama';
      case AgentType.analysis:
        return 'Gemini Analiz';
      case AgentType.action:
        return 'Aksiyon';
    }
  }

  /// DB ve API için kısa isim
  String get shortName {
    switch (this) {
      case AgentType.orchestrator:
        return 'orchestrator';
      case AgentType.dataCollection:
        return 'data_collection';
      case AgentType.analysis:
        return 'analysis';
      case AgentType.action:
        return 'action';
    }
  }
}

/// Log kaydı önem seviyesi
enum LogLevel {
  info,
  warning,
  error,
  success;

  String get displayNameTr {
    switch (this) {
      case LogLevel.info:
        return 'Bilgi';
      case LogLevel.warning:
        return 'Uyarı';
      case LogLevel.error:
        return 'Hata';
      case LogLevel.success:
        return 'Başarı';
    }
  }
}

/// Bir ajanın gerçekleştirdiği işlem veya kararı kaydeder.
///
/// Örnek kullanım:
/// ```dart
/// final entry = AgentLogEntry(
///   id: 'uuid-1',
///   agent: AgentType.analysis,
///   message: '15 işlem Gemini tarafından analiz edildi',
///   timestamp: DateTime.now(),
///   level: LogLevel.success,
///   durationMs: 3200,
/// );
/// ```
@immutable
class AgentLogEntry {
  /// Benzersiz log kimliği
  final String id;

  /// Hangi ajan bu kaydı oluşturdu
  final AgentType agent;

  /// İnsan okunabilir açıklama
  final String message;

  /// Opsiyonel teknik detay (JSON string veya ek bilgi)
  final String? detail;

  /// Log kaydı zamanı
  final DateTime timestamp;

  /// Önem seviyesi
  final LogLevel level;

  /// İşlemin kaç ms sürdüğü
  final int durationMs;

  const AgentLogEntry({
    required this.id,
    required this.agent,
    required this.message,
    this.detail,
    required this.timestamp,
    required this.level,
    this.durationMs = 0,
  });

  /// Gemini'nin yaptığı bir log mu?
  bool get isGeminiLog => agent == AgentType.analysis;

  AgentLogEntry copyWith({
    String? id,
    AgentType? agent,
    String? message,
    String? detail,
    DateTime? timestamp,
    LogLevel? level,
    int? durationMs,
  }) {
    return AgentLogEntry(
      id: id ?? this.id,
      agent: agent ?? this.agent,
      message: message ?? this.message,
      detail: detail ?? this.detail,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'agent': agent.shortName,
    'message': message,
    'detail': detail,
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'durationMs': durationMs,
  };

  factory AgentLogEntry.fromJson(Map<String, dynamic> json) {
    // shortName'den AgentType bul
    final agentStr = json['agent'] as String? ?? 'orchestrator';
    final agentType = AgentType.values.firstWhere(
      (a) => a.shortName == agentStr,
      orElse: () => AgentType.orchestrator,
    );

    return AgentLogEntry(
      id: json['id'] as String,
      agent: agentType,
      message: json['message'] as String,
      detail: json['detail'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: LogLevel.values.byName(json['level'] as String? ?? 'info'),
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentLogEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AgentLogEntry(agent: ${agent.name}, level: ${level.name}, message: $message)';
}
