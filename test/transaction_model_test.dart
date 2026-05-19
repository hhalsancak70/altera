import 'package:flutter_test/flutter_test.dart';
import 'package:altera/core/models/transaction.dart';

void main() {
  group('Transaction model', () {
    final base = Transaction(
      id: 'test-id-1',
      description: 'Migros Market',
      amount: -250.0,
      date: DateTime(2026, 5, 15),
      category: TransactionCategory.market,
      type: TransactionType.need,
      aiReason: 'Market alışverişi',
      isAnalyzed: true,
      source: 'bank_mock',
      createdAt: DateTime(2026, 5, 15, 10, 0),
    );

    test('toJson → fromJson round-trip', () {
      final json = base.toJson();
      final restored = Transaction.fromJson(json);

      expect(restored.id, equals(base.id));
      expect(restored.description, equals(base.description));
      expect(restored.amount, equals(base.amount));
      expect(restored.category, equals(base.category));
      expect(restored.type, equals(base.type));
      expect(restored.aiReason, equals(base.aiReason));
      expect(restored.isAnalyzed, equals(base.isAnalyzed));
      expect(restored.source, equals(base.source));
    });

    test('isIncome — negatif tutar için false', () {
      expect(base.isIncome, isFalse);
    });

    test('isIncome — pozitif tutar için true', () {
      final income = base.copyWith(amount: 5000.0);
      expect(income.isIncome, isTrue);
    });

    test('absoluteAmount — her zaman pozitif', () {
      expect(base.absoluteAmount, equals(250.0));
      final income = base.copyWith(amount: 3000.0);
      expect(income.absoluteAmount, equals(3000.0));
    });

    test('toJson isAnalyzed int olarak serialize edilir', () {
      final json = base.toJson();
      expect(json['isAnalyzed'], isA<int>());
      expect(json['isAnalyzed'], equals(1));

      final notAnalyzed = base.copyWith(isAnalyzed: false).toJson();
      expect(notAnalyzed['isAnalyzed'], equals(0));
    });

    test('fromJson — eksik opsiyonel alanlar için güvenli default', () {
      final minimalJson = {
        'id': 'min-id',
        'description': 'Test',
        'amount': 100.0,
        'date': '2026-05-01T00:00:00.000',
        'category': 'other',
        'type': 'need',
        'isAnalyzed': 0,
        'source': 'manual',
        'createdAt': '2026-05-01T00:00:00.000',
      };
      final tx = Transaction.fromJson(minimalJson);
      expect(tx.aiReason, isNull);
      expect(tx.category, equals(TransactionCategory.other));
    });
  });
}
