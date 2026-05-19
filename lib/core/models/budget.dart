// Bir kategori için aylık bütçe limitini temsil eden model
import 'package:flutter/foundation.dart';
import 'transaction.dart';

/// Bütçe doluluk durumu
enum BudgetStatus {
  /// %0-%79 arası - güvende
  safe,

  /// %80-%99 arası - uyarı
  warning,

  /// %100+ - limit aşıldı
  danger;

  String get displayNameTr {
    switch (this) {
      case BudgetStatus.safe:
        return 'Güvende';
      case BudgetStatus.warning:
        return 'Uyarı';
      case BudgetStatus.danger:
        return 'Aşıldı';
    }
  }
}

/// Bir kategori için aylık bütçe limitini temsil eder.
///
/// Örnek kullanım:
/// ```dart
/// final budget = Budget(
///   id: 'uuid-1',
///   category: TransactionCategory.restaurant,
///   limitAmount: 1500.0,
///   spentAmount: 1200.0,
///   month: DateTime(2026, 5),
/// );
/// print(budget.usagePercentage); // 0.8
/// print(budget.status);          // BudgetStatus.warning
/// ```
@immutable
class Budget {
  /// Benzersiz bütçe kimliği
  final String id;

  /// Bütçe kategorisi
  final TransactionCategory category;

  /// Aylık limit (TL)
  final double limitAmount;

  /// Bu ay harcanan (TL) - işlemlerden hesaplanır
  final double spentAmount;

  /// Hangi ay (yıl+ay yeterli, gün 1 olarak set edilir)
  final DateTime month;

  const Budget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.spentAmount,
    required this.month,
  });

  /// Kalan bütçe - negatif ise limit aşılmış
  double get remainingAmount => limitAmount - spentAmount;

  /// Kullanım yüzdesi (0.0 - 1.0+)
  double get usagePercentage =>
      limitAmount > 0 ? spentAmount / limitAmount : 0.0;

  /// Bütçe durumu - %80 uyarı, %100 tehlike
  BudgetStatus get status {
    if (usagePercentage >= 1.0) return BudgetStatus.danger;
    if (usagePercentage >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  /// Aşım miktarı - sadece danger durumunda anlamlı
  double get overspentAmount =>
      spentAmount > limitAmount ? spentAmount - limitAmount : 0.0;

  Budget copyWith({
    String? id,
    TransactionCategory? category,
    double? limitAmount,
    double? spentAmount,
    DateTime? month,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limitAmount: limitAmount ?? this.limitAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      month: month ?? this.month,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.name,
    'limitAmount': limitAmount,
    'spentAmount': spentAmount,
    'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
  };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    category: TransactionCategory.values.byName(json['category'] as String),
    limitAmount: (json['limitAmount'] as num).toDouble(),
    spentAmount: (json['spentAmount'] as num? ?? 0).toDouble(),
    month: DateTime.parse('${json['month']}-01'),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Budget && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Budget(category: ${category.name}, limit: $limitAmount, spent: $spentAmount, status: ${status.name})';
}
