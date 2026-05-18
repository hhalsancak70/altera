// Bir banka veya e-fatura işlemini temsil eden veri modeli
import 'package:flutter/foundation.dart';

/// İşlem kategorisi - Gemini tarafından otomatik atanır
enum TransactionCategory {
  market,
  restaurant,
  transport,
  bill,
  clothing,
  entertainment,
  health,
  education,
  investment,
  income,
  other;

  /// Türkçe kategori adı
  String get displayNameTr {
    switch (this) {
      case TransactionCategory.market:
        return 'Market';
      case TransactionCategory.restaurant:
        return 'Restoran';
      case TransactionCategory.transport:
        return 'Ulaşım';
      case TransactionCategory.bill:
        return 'Fatura';
      case TransactionCategory.clothing:
        return 'Giyim';
      case TransactionCategory.entertainment:
        return 'Eğlence';
      case TransactionCategory.health:
        return 'Sağlık';
      case TransactionCategory.education:
        return 'Eğitim';
      case TransactionCategory.investment:
        return 'Yatırım';
      case TransactionCategory.income:
        return 'Gelir';
      case TransactionCategory.other:
        return 'Diğer';
    }
  }

  /// Kategori emoji ikonu
  String get emoji {
    switch (this) {
      case TransactionCategory.market:
        return '🛒';
      case TransactionCategory.restaurant:
        return '🍽️';
      case TransactionCategory.transport:
        return '🚇';
      case TransactionCategory.bill:
        return '📄';
      case TransactionCategory.clothing:
        return '👗';
      case TransactionCategory.entertainment:
        return '🎬';
      case TransactionCategory.health:
        return '💊';
      case TransactionCategory.education:
        return '📚';
      case TransactionCategory.investment:
        return '📈';
      case TransactionCategory.income:
        return '💰';
      case TransactionCategory.other:
        return '📦';
    }
  }
}

/// İşlem türü - ihtiyaç/istek/gelir ayrımı
enum TransactionType {
  need,
  want,
  income;

  String get displayNameTr {
    switch (this) {
      case TransactionType.need:
        return 'İhtiyaç';
      case TransactionType.want:
        return 'İstek';
      case TransactionType.income:
        return 'Gelir';
    }
  }
}

/// Bir banka veya e-fatura işlemini temsil eder.
///
/// Örnek kullanım:
/// ```dart
/// final tx = Transaction(
///   id: 'uuid-1',
///   description: 'Migros Market',
///   amount: -150.0,
///   date: DateTime.now(),
///   category: TransactionCategory.market,
///   type: TransactionType.need,
///   isAnalyzed: true,
///   source: 'bank_mock',
/// );
/// ```
@immutable
class Transaction {
  /// Benzersiz işlem kimliği (UUID v4)
  final String id;

  /// İşlem açıklaması - banka veya fatura kaynağından
  final String description;

  /// TL cinsinden tutar (pozitif=gelir, negatif=gider)
  final double amount;

  /// İşlem tarihi
  final DateTime date;

  /// Gemini tarafından atanan kategori
  final TransactionCategory category;

  /// Gemini tarafından belirlenen tür (ihtiyaç/istek/gelir)
  final TransactionType type;

  /// Gemini'nin kategori atama gerekçesi
  final String? aiReason;

  /// Gemini analizi tamamlandı mı?
  final bool isAnalyzed;

  /// Veri kaynağı ('bank_mock' | 'invoice_parser')
  final String source;

  /// Kayıt oluşturulma zamanı
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    this.aiReason,
    required this.isAnalyzed,
    required this.source,
    required this.createdAt,
  });

  /// Gelir mi? (pozitif tutar)
  bool get isIncome => amount > 0;

  /// Mutlak tutar değeri
  double get absoluteAmount => amount.abs();

  Transaction copyWith({
    String? id,
    String? description,
    double? amount,
    DateTime? date,
    TransactionCategory? category,
    TransactionType? type,
    String? aiReason,
    bool? isAnalyzed,
    String? source,
    DateTime? createdAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
      aiReason: aiReason ?? this.aiReason,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category.name,
        'type': type.name,
        'aiReason': aiReason,
        'isAnalyzed': isAnalyzed ? 1 : 0,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        category: TransactionCategory.values.byName(
          json['category'] as String? ?? 'other',
        ),
        type: TransactionType.values.byName(
          json['type'] as String? ?? 'need',
        ),
        aiReason: json['aiReason'] as String?,
        isAnalyzed: (json['isAnalyzed'] as int? ?? 0) == 1,
        source: json['source'] as String? ?? 'bank_mock',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Transaction(id: $id, description: $description, amount: $amount, category: ${category.name})';
}
