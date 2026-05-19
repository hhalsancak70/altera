// Kullanıcının finansal tercihlerini ve risk profilini tutan model
import 'package:flutter/foundation.dart';

/// Kullanıcı risk profili - yatırım önerisini yönlendirir
enum RiskProfile {
  /// Sermaye koruması öncelikli - mevduat ve altın tercihli
  conservative,

  /// Risk/getiri dengesi - karma portföy
  balanced,

  /// Yüksek getiri hedefli - hisse ve forex toleranslı
  aggressive;

  String get displayNameTr {
    switch (this) {
      case RiskProfile.conservative:
        return 'Muhafazakâr';
      case RiskProfile.balanced:
        return 'Dengeli';
      case RiskProfile.aggressive:
        return 'Agresif';
    }
  }

  String get descriptionTr {
    switch (this) {
      case RiskProfile.conservative:
        return 'Sermayeni koru, düşük risk al. Mevduat ve altın ağırlıklı.';
      case RiskProfile.balanced:
        return 'Risk ve getiriyi dengele. Karma portföy stratejisi.';
      case RiskProfile.aggressive:
        return 'Yüksek getiri için yüksek risk kabul et. Hisse ve döviz ağırlıklı.';
    }
  }

  String get emoji {
    switch (this) {
      case RiskProfile.conservative:
        return '🛡️';
      case RiskProfile.balanced:
        return '⚖️';
      case RiskProfile.aggressive:
        return '🚀';
    }
  }
}

/// Kullanıcının finansal tercihlerini ve risk profilini tutar.
///
/// Örnek kullanım:
/// ```dart
/// final profile = UserProfile(
///   id: 'user-1',
///   name: 'Ahmet Yılmaz',
///   riskProfile: RiskProfile.balanced,
///   monthlyIncome: 25000.0,
///   currency: 'TRY',
///   locale: 'tr',
///   createdAt: DateTime.now(),
///   updatedAt: DateTime.now(),
/// );
/// ```
@immutable
class UserProfile {
  /// Kullanıcı kimliği
  final String id;

  /// Kullanıcı adı
  final String name;

  /// Yatırım risk profili
  final RiskProfile riskProfile;

  /// Aylık gelir (TL)
  final double monthlyIncome;

  /// Para birimi - varsayılan 'TRY'
  final String currency;

  /// Dil kodu ('tr' | 'en')
  final String locale;

  /// Profil oluşturulma tarihi
  final DateTime createdAt;

  /// Profil son güncelleme tarihi
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.riskProfile,
    required this.monthlyIncome,
    this.currency = 'TRY',
    this.locale = 'tr',
    required this.createdAt,
    required this.updatedAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    RiskProfile? riskProfile,
    double? monthlyIncome,
    String? currency,
    String? locale,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      riskProfile: riskProfile ?? this.riskProfile,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      currency: currency ?? this.currency,
      locale: locale ?? this.locale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'riskProfile': riskProfile.name,
    'monthlyIncome': monthlyIncome,
    'currency': currency,
    'locale': locale,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    riskProfile: RiskProfile.values.byName(
      json['riskProfile'] as String? ?? 'balanced',
    ),
    monthlyIncome: (json['monthlyIncome'] as num? ?? 0).toDouble(),
    currency: json['currency'] as String? ?? 'TRY',
    locale: json['locale'] as String? ?? 'tr',
    createdAt: DateTime.parse(
      json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    ),
    updatedAt: DateTime.parse(
      json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
    ),
  );

  /// Varsayılan profil - onboarding tamamlanmadan kullanılır
  factory UserProfile.defaults() => UserProfile(
    id: 'default-user',
    name: 'Kullanıcı',
    riskProfile: RiskProfile.balanced,
    monthlyIncome: 0,
    currency: 'TRY',
    locale: 'tr',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserProfile(name: $name, risk: ${riskProfile.name}, income: $monthlyIncome)';
}
