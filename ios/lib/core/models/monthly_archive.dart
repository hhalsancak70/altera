// Aylık istatistik arşivi modeli
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'transaction.dart';

/// Bir aya ait arşivlenmiş finansal istatistik.
///
/// Arşiv kaydı değiştirilemez — ay kapandıktan sonra sabit kalır.
/// Gelecekte başvurmak için geçmişi korur.
@immutable
class MonthlyArchive {
  final String id;
  final int year;
  final int month;
  final double totalIncome;
  final double totalExpense;
  final double totalSavings;
  final Map<String, double> categorySpending; // category.name → tutar
  final int transactionCount;
  final String? topCategory;
  final DateTime archivedAt;

  const MonthlyArchive({
    required this.id,
    required this.year,
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSavings,
    required this.categorySpending,
    required this.transactionCount,
    this.topCategory,
    required this.archivedAt,
  });

  /// Türkçe ay adı (Ocak, Şubat, ...)
  String get monthNameTr {
    const names = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    return names[month];
  }

  /// Tasarruf oranı (0.0-1.0), gelir sıfırsa 0 döner
  double get savingsRate =>
      totalIncome > 0 ? (totalSavings / totalIncome).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'total_savings': totalSavings,
      'category_json': jsonEncode(categorySpending),
      'budget_json': '{}', // Gelecekte bütçe arşivi eklenebilir
      'transaction_count': transactionCount,
      'top_category': topCategory,
      'archived_at': archivedAt.toIso8601String(),
    };
  }

  factory MonthlyArchive.fromDbMap(Map<String, dynamic> map) {
    final categoryJson =
        jsonDecode(map['category_json'] as String? ?? '{}') as Map<String, dynamic>;

    return MonthlyArchive(
      id: map['id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      totalIncome: (map['total_income'] as num).toDouble(),
      totalExpense: (map['total_expense'] as num).toDouble(),
      totalSavings: (map['total_savings'] as num).toDouble(),
      categorySpending: categoryJson.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      transactionCount: map['transaction_count'] as int,
      topCategory: map['top_category'] as String?,
      archivedAt: DateTime.parse(map['archived_at'] as String),
    );
  }

  /// En fazla harcama yapılan kategoriyi emoji ile döndürür
  String? get topCategoryDisplay {
    if (topCategory == null) return null;
    try {
      final cat = TransactionCategory.values.byName(topCategory!);
      return '${cat.emoji} ${cat.displayNameTr}';
    } catch (_) {
      return topCategory;
    }
  }
}
