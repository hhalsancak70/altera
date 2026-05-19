// Simüle yatırım fonu veri modeli
import 'package:flutter/foundation.dart';

/// Yatırım fonu türü
enum FundType {
  gold,
  deposit,
  stock,
  bond,
  forex,
  mixed;

  String get displayNameTr {
    switch (this) {
      case FundType.gold:
        return 'Altın';
      case FundType.deposit:
        return 'TL Mevduat';
      case FundType.stock:
        return 'Hisse Senedi';
      case FundType.bond:
        return 'Tahvil';
      case FundType.forex:
        return 'Döviz';
      case FundType.mixed:
        return 'Karma';
    }
  }

  String get emoji {
    switch (this) {
      case FundType.gold:
        return '🥇';
      case FundType.deposit:
        return '🏦';
      case FundType.stock:
        return '📊';
      case FundType.bond:
        return '📜';
      case FundType.forex:
        return '💱';
      case FundType.mixed:
        return '🧺';
    }
  }
}

/// Risk seviyesi - kullanıcı risk profiliyle eşleştirilir
enum RiskLevel {
  low,
  medium,
  high;

  String get displayNameTr {
    switch (this) {
      case RiskLevel.low:
        return 'Düşük Risk';
      case RiskLevel.medium:
        return 'Orta Risk';
      case RiskLevel.high:
        return 'Yüksek Risk';
    }
  }
}

/// Simüle yatırım fonunu temsil eder.
///
/// Örnek kullanım:
/// ```dart
/// final fund = InvestmentFund(
///   id: 'fund-001',
///   name: 'Altın Fonu',
///   code: 'GLD-TRY',
///   type: FundType.gold,
///   annualReturnRate: 28.5,
///   riskLevel: RiskLevel.medium,
///   description: 'Türk altın piyasasına bağlı fon',
///   isRecommended: true,
/// );
/// ```
@immutable
class InvestmentFund {
  /// Benzersiz fon kimliği
  final String id;

  /// Fon adı (Türkçe)
  final String name;

  /// Fon kodu (ör. 'GLD-TRY')
  final String code;

  /// Fon türü
  final FundType type;

  /// Yıllık tahmini getiri (%)
  final double annualReturnRate;

  /// Risk seviyesi
  final RiskLevel riskLevel;

  /// Fon açıklaması
  final String description;

  /// Gemini bu ay önerdi mi?
  final bool isRecommended;

  const InvestmentFund({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.annualReturnRate,
    required this.riskLevel,
    required this.description,
    this.isRecommended = false,
  });

  InvestmentFund copyWith({
    String? id,
    String? name,
    String? code,
    FundType? type,
    double? annualReturnRate,
    RiskLevel? riskLevel,
    String? description,
    bool? isRecommended,
  }) {
    return InvestmentFund(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      annualReturnRate: annualReturnRate ?? this.annualReturnRate,
      riskLevel: riskLevel ?? this.riskLevel,
      description: description ?? this.description,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    'type': type.name,
    'annualReturnRate': annualReturnRate,
    'riskLevel': riskLevel.name,
    'description': description,
    'isRecommended': isRecommended,
  };

  factory InvestmentFund.fromJson(Map<String, dynamic> json) => InvestmentFund(
    id: json['id'] as String,
    name: json['name'] as String,
    code: json['code'] as String,
    type: FundType.values.byName(json['type'] as String),
    annualReturnRate: (json['annualReturnRate'] as num).toDouble(),
    riskLevel: RiskLevel.values.byName(json['riskLevel'] as String),
    description: json['description'] as String,
    isRecommended: json['isRecommended'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestmentFund &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'InvestmentFund(name: $name, type: ${type.name}, return: $annualReturnRate%)';
}
