import 'package:flutter_test/flutter_test.dart';
import 'package:altera/core/security/privacy_filter.dart';
import 'package:altera/core/models/transaction.dart';

void main() {
  group('PrivacyFilter.sanitizeDescription', () {
    test('IBAN maskeler', () {
      const input = 'Havale TR330006100519786457841326';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[IBAN]'));
      expect(result, isNot(contains('TR330006100519786457841326')));
    });

    test('Boşluklu IBAN maskeler', () {
      const input = 'IBAN: TR33 0006 1005 1978 6457 8413 26';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[IBAN]'));
    });

    test('16 haneli kart numarası maskeler', () {
      const input = 'Kart ödemesi 4111 1111 1111 1111';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[KART]'));
      expect(result, isNot(contains('4111')));
    });

    test('Tire ile ayrılmış kart numarası maskeler', () {
      const input = 'Pos işlemi 5500-0000-0000-0004';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[KART]'));
    });

    test('Türk telefon numarası maskeler (05xx)', () {
      const input = 'Para transferi 0532 123 45 67';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[TEL]'));
      expect(result, isNot(contains('0532')));
    });

    test('Türk telefon numarası maskeler (+90)', () {
      const input = 'İletişim: +90 555 444 33 22';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[TEL]'));
    });

    test('11 haneli TCKN maskeler', () {
      const input = 'Müşteri 12345678901 için işlem';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[TCKN]'));
      expect(result, isNot(contains('12345678901')));
    });

    test('100 karakterden uzun açıklamayı kırpar', () {
      final longDesc = 'A' * 150;
      final result = PrivacyFilter.sanitizeDescription(longDesc);
      expect(result.length, lessThanOrEqualTo(100));
    });

    test('Normal açıklama değişmez', () {
      const input = 'Migros Market';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, equals('Migros Market'));
    });

    test('Boş string güvenli döner', () {
      final result = PrivacyFilter.sanitizeDescription('');
      expect(result, isEmpty);
    });
  });

  group('PrivacyFilter.prepareForGemini', () {
    test('Yalnızca açıklama ve mutlak tutar döner', () {
      final tx = Transaction(
        id: '1',
        description: 'Migros Market 0532 111 22 33',
        amount: -150.0,
        date: DateTime(2026, 5, 1),
        category: TransactionCategory.market,
        type: TransactionType.need,
        isAnalyzed: false,
        source: 'test',
        createdAt: DateTime(2026, 5, 1),
      );

      final result = PrivacyFilter.prepareForGemini(tx);

      expect(result.containsKey('description'), isTrue);
      expect(result.containsKey('amount'), isTrue);
      expect(result['amount'], equals(150.0)); // mutlak değer
      expect(result['description'], contains('[TEL]'));
      expect(result['description'], isNot(contains('0532')));
      // Tarih, id gibi kişisel alanlar olmamalı
      expect(result.containsKey('date'), isFalse);
      expect(result.containsKey('id'), isFalse);
    });
  });
}
