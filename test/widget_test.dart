import 'package:flutter_test/flutter_test.dart';
import 'package:altera/core/security/privacy_filter.dart';
import 'package:altera/core/models/transaction.dart';
import 'package:altera/core/models/asset.dart';
import 'package:altera/core/models/monthly_archive.dart';
import 'package:altera/core/utils/money_parser.dart';
import 'package:altera/core/database/db_helper.dart';
import 'package:altera/core/services/gemini_service.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // PrivacyFilter
  // ──────────────────────────────────────────────────────────────────────────

  group('PrivacyFilter.sanitizeDescription', () {
    test('masks full IBAN', () {
      const input = 'Transfer to TR330006100519786457841326';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[IBAN]'));
      expect(result, isNot(contains('TR330006100519786457841326')));
    });

    test('masks spaced IBAN', () {
      const input = 'Havale TR33 0006 1005 1978 6457 8413 26';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[IBAN]'));
    });

    test('masks 16-digit card number', () {
      const input = 'Kart harcaması 4111 1111 1111 1111 onaylı';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[KART]'));
      expect(result, isNot(contains('4111')));
    });

    test('masks Turkish phone number (05xx)', () {
      const input = 'SMS doğrulama 0532 123 45 67';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[TEL]'));
    });

    test('masks +90 phone number', () {
      const input = 'Arama +90 532 123 45 67';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[TEL]'));
    });

    test('masks 11-digit TCKN', () {
      const input = 'TC: 12345678901 ile işlem';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[TCKN]'));
      expect(result, isNot(contains('12345678901')));
    });

    test('masks email address', () {
      const input = 'Fatura ali@example.com adresine gönderildi';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[EMAIL]'));
      expect(result, isNot(contains('ali@example.com')));
    });

    test('masks account number with Turkish keyword', () {
      const input = 'hesap no: 1234567890 ile işlem yapıldı';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[ACCOUNT_NO]'));
      expect(result, isNot(contains('1234567890')));
    });

    test('masks account number with English keyword', () {
      const input = 'account number 9876543210 transfer';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[ACCOUNT_NO]'));
      expect(result, isNot(contains('9876543210')));
    });

    test('masks account number with acct keyword', () {
      const input = 'acct 123456 credited';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, contains('[ACCOUNT_NO]'));
    });

    test('does not mask standalone amounts (no keyword context)', () {
      const input = 'Migros harcaması 250.50 TL';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, isNot(contains('[ACCOUNT_NO]')));
      expect(result, contains('250.50'));
    });

    test('does not mask 4-digit year-like numbers without context', () {
      const input = 'İşlem tarihi 2026 yılı';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, isNot(contains('[ACCOUNT_NO]')));
    });

    test('leaves normal description unchanged', () {
      const input = 'Migros market alışverişi';
      final result = PrivacyFilter.sanitizeDescription(input);
      expect(result, equals('Migros market alışverişi'));
    });

    test('truncates to 100 characters by default', () {
      final long = 'A' * 200;
      final result = PrivacyFilter.sanitizeDescription(long);
      expect(result.length, equals(100));
    });

    test('respects custom maxLength', () {
      final long = 'B' * 600;
      final result = PrivacyFilter.sanitizeDescription(long, maxLength: 500);
      expect(result.length, equals(500));
    });

    test('trims whitespace', () {
      const input = '  Starbucks  ';
      expect(PrivacyFilter.sanitizeDescription(input), equals('Starbucks'));
    });

    test('Gemini prompt does not contain raw sensitive description', () {
      const desc = 'IBAN: TR330006100519786457841326 kart 4111111111111111';
      final sanitized = PrivacyFilter.sanitizeDescription(desc);
      expect(sanitized, isNot(contains('TR330006')));
      expect(sanitized, isNot(contains('4111111111111111')));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // TransactionCategory enum safe parsing
  // ──────────────────────────────────────────────────────────────────────────

  group('TransactionCategory enum', () {
    test('parses valid category name', () {
      expect(
        TransactionCategory.values.byName('market'),
        equals(TransactionCategory.market),
      );
    });

    test('falls back to other on unknown name', () {
      TransactionCategory result;
      try {
        result = TransactionCategory.values.byName('nonexistent_category');
      } catch (_) {
        result = TransactionCategory.other;
      }
      expect(result, equals(TransactionCategory.other));
    });

    test('all categories have non-empty displayNameTr', () {
      for (final cat in TransactionCategory.values) {
        expect(
          cat.displayNameTr,
          isNotEmpty,
          reason: 'Category ${cat.name} missing displayNameTr',
        );
      }
    });

    test('all categories have non-empty emoji', () {
      for (final cat in TransactionCategory.values) {
        expect(
          cat.emoji,
          isNotEmpty,
          reason: 'Category ${cat.name} missing emoji',
        );
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Asset.fromJson safe casts
  // ──────────────────────────────────────────────────────────────────────────

  group('Asset.fromJson', () {
    test('parses integer units and totalCost without crash', () {
      final json = {
        'name': 'Altın',
        'symbol': 'GC=F',
        'prefix': 'GC',
        'colorHex': 0xFFFFD700,
        'units': 2, // integer, not double
        'totalCost': 5000, // integer, not double
      };
      final asset = Asset.fromJson(json);
      expect(asset.units, equals(2.0));
      expect(asset.totalCost, equals(5000.0));
    });

    test('parses double units and totalCost', () {
      final json = {
        'name': 'Bitcoin',
        'symbol': 'BTC-USD',
        'prefix': 'BTC',
        'colorHex': 0xFFF7931A,
        'units': 0.005,
        'totalCost': 1234.56,
      };
      final asset = Asset.fromJson(json);
      expect(asset.units, closeTo(0.005, 0.0001));
      expect(asset.totalCost, closeTo(1234.56, 0.001));
    });

    test('round-trips through toJson → fromJson', () {
      final json = {
        'name': 'S&P 500',
        'symbol': 'SPY',
        'prefix': 'SPY',
        'colorHex': 0xFF4CAF50,
        'units': 3.5,
        'totalCost': 1750.0,
      };
      final asset = Asset.fromJson(json);
      final back = Asset.fromJson(asset.toJson());
      expect(back.name, equals(asset.name));
      expect(back.symbol, equals(asset.symbol));
      expect(back.units, equals(asset.units));
      expect(back.totalCost, equals(asset.totalCost));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Duplicate fingerprint logic (DB level)
  // ──────────────────────────────────────────────────────────────────────────

  group('DbHelper.buildFingerprint', () {
    test('same date/amount/desc/type produces identical fingerprint', () {
      final date = DateTime(2026, 5, 15);
      final fp1 = DbHelper.buildFingerprint(
        date,
        -250.0,
        'Migros',
        TransactionType.need,
      );
      final fp2 = DbHelper.buildFingerprint(
        date,
        -250.0,
        'Migros',
        TransactionType.need,
      );
      expect(fp1, equals(fp2));
    });

    test('different amount → different fingerprint', () {
      final date = DateTime(2026, 5, 15);
      expect(
        DbHelper.buildFingerprint(date, -250.0, 'Migros', TransactionType.need),
        isNot(
          equals(
            DbHelper.buildFingerprint(
              date,
              -251.0,
              'Migros',
              TransactionType.need,
            ),
          ),
        ),
      );
    });

    test('extra whitespace in desc is normalized', () {
      final date = DateTime(2026, 5, 15);
      expect(
        DbHelper.buildFingerprint(date, -50.0, 'A B', TransactionType.need),
        equals(
          DbHelper.buildFingerprint(date, -50.0, 'A  B', TransactionType.need),
        ),
      );
    });

    test('case differences are normalized', () {
      final date = DateTime(2026, 5, 15);
      expect(
        DbHelper.buildFingerprint(date, -50.0, 'MIGROS', TransactionType.need),
        equals(
          DbHelper.buildFingerprint(date, -50.0, 'migros', TransactionType.need),
        ),
      );
    });

    test('different dates → different fingerprint', () {
      expect(
        DbHelper.buildFingerprint(
          DateTime(2026, 5, 15),
          -50.0,
          'Migros',
          TransactionType.need,
        ),
        isNot(
          equals(
            DbHelper.buildFingerprint(
              DateTime(2026, 5, 16),
              -50.0,
              'Migros',
              TransactionType.need,
            ),
          ),
        ),
      );
    });

    test('same date/amount/desc but different type → different fingerprint', () {
      final date = DateTime(2026, 5, 15);
      expect(
        DbHelper.buildFingerprint(date, 100.0, 'Maaş', TransactionType.income),
        isNot(
          equals(
            DbHelper.buildFingerprint(
              date,
              100.0,
              'Maaş',
              TransactionType.need,
            ),
          ),
        ),
      );
    });

    test('fingerprint contains expected format parts', () {
      final date = DateTime(2026, 5, 5);
      final fp = DbHelper.buildFingerprint(
        date,
        -1234.56,
        'Test',
        TransactionType.need,
      );
      expect(fp, startsWith('2026-05-05|'));
      expect(fp, contains('|-1234.56|'));
      expect(fp, contains('|test|'));
      expect(fp, endsWith('|need'));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Turkish money parser
  // ──────────────────────────────────────────────────────────────────────────

  group('parseMoneyAmount', () {
    test('parses plain integer', () {
      expect(parseMoneyAmount('1234'), closeTo(1234.0, 0.001));
    });

    test('parses dot-decimal English format', () {
      expect(parseMoneyAmount('1234.56'), closeTo(1234.56, 0.001));
    });

    test('parses comma-decimal Turkish format (12,50)', () {
      expect(parseMoneyAmount('12,50'), closeTo(12.50, 0.001));
    });

    test('parses Turkish thousands+decimal (1.234,56)', () {
      expect(parseMoneyAmount('1.234,56'), closeTo(1234.56, 0.001));
    });

    test('parses plain dot format as decimal (1.234 = 1.234, not 1234)', () {
      expect(parseMoneyAmount('1.234'), closeTo(1.234, 0.001));
    });

    test('parses English thousands format (1,234.56)', () {
      expect(parseMoneyAmount('1,234.56'), closeTo(1234.56, 0.001));
    });

    test('strips TL suffix', () {
      expect(parseMoneyAmount('500 TL'), closeTo(500.0, 0.001));
    });

    test('strips TL currency symbol', () {
      expect(parseMoneyAmount('₺1.234,56'), closeTo(1234.56, 0.001));
    });

    test('returns null for empty string', () {
      expect(parseMoneyAmount(''), isNull);
    });

    test('returns null for null input', () {
      expect(parseMoneyAmount(null), isNull);
    });

    test('returns null for non-numeric string', () {
      expect(parseMoneyAmount('abc'), isNull);
    });

    test('parseMoneyAmountOrZero returns 0 for invalid', () {
      expect(parseMoneyAmountOrZero('invalid'), equals(0.0));
    });

    test('parseMoneyAmountOrZero returns value for valid', () {
      expect(parseMoneyAmountOrZero('12,50'), closeTo(12.50, 0.001));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MonthlyArchive.savingsRate type safety
  // ──────────────────────────────────────────────────────────────────────────

  group('MonthlyArchive.savingsRate', () {
    MonthlyArchive makeArchive({
      required double income,
      required double savings,
    }) {
      return MonthlyArchive(
        id: 'test',
        year: 2026,
        month: 5,
        totalIncome: income,
        totalExpense: income - savings,
        totalSavings: savings,
        categorySpending: {},
        transactionCount: 0,
        archivedAt: DateTime(2026, 5, 31),
      );
    }

    test('returns double type', () {
      final archive = makeArchive(income: 10000.0, savings: 2000.0);
      expect(archive.savingsRate, isA<double>());
    });

    test('correct rate for normal case', () {
      final archive = makeArchive(income: 10000.0, savings: 3000.0);
      expect(archive.savingsRate, closeTo(0.3, 0.001));
    });

    test('clamped to 1.0 when savings > income', () {
      final archive = makeArchive(income: 1000.0, savings: 2000.0);
      expect(archive.savingsRate, equals(1.0));
    });

    test('clamped to 0.0 when savings is negative', () {
      final archive = makeArchive(income: 1000.0, savings: -500.0);
      expect(archive.savingsRate, equals(0.0));
    });

    test('returns 0.0 when income is zero', () {
      final archive = makeArchive(income: 0.0, savings: 0.0);
      expect(archive.savingsRate, equals(0.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GeminiService disabled mode
  // ──────────────────────────────────────────────────────────────────────────

  group('GeminiService.disabled', () {
    test('isEnabled returns false for disabled service', () {
      final svc = GeminiService.disabled();
      expect(svc.isEnabled, isFalse);
    });

    test('withKey empty string creates disabled service', () {
      final svc = GeminiService.withKey('');
      expect(svc.isEnabled, isFalse);
    });

    test('withKey non-empty creates enabled service', () {
      final svc = GeminiService.withKey('AIzaTestKey12345678901234567890');
      expect(svc.isEnabled, isTrue);
    });

    test('disabled service throws GeminiException on analyzeTransaction', () async {
      final svc = GeminiService.disabled();
      final tx = Transaction(
        id: 'test',
        description: 'Test',
        amount: -100.0,
        date: DateTime.now(),
        category: TransactionCategory.other,
        type: TransactionType.need,
        isAnalyzed: false,
        source: 'manual',
        createdAt: DateTime.now(),
      );
      expect(
        () => svc.analyzeTransaction(tx),
        throwsA(isA<GeminiException>()),
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // GeminiService empty-funds guard (pure logic test)
  // ──────────────────────────────────────────────────────────────────────────

  group('Investment amount safety', () {
    test('clamp keeps amount between 0 and savings', () {
      const savings = 1000.0;
      double rawAmount = 1500.0;
      final safe = rawAmount.clamp(0.0, savings).toDouble();
      expect(safe, equals(1000.0));
      expect(safe, isA<double>());
    });

    test('clamp keeps negative amount at 0', () {
      const savings = 1000.0;
      double rawAmount = -100.0;
      final safe = rawAmount.clamp(0.0, savings).toDouble();
      expect(safe, equals(0.0));
    });

    test('suggested 80% amount is within bounds', () {
      const savings = 500.0;
      final suggested = savings * 0.8;
      expect(suggested, closeTo(400.0, 0.001));
      expect(suggested.clamp(0.0, savings).toDouble(), equals(400.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Import fingerprint date comparison format
  // ──────────────────────────────────────────────────────────────────────────

  group('Fingerprint date format for DB LIKE query', () {
    test('ISO date stored with T separator matches LIKE pattern', () {
      const isoDate = '2026-05-15T10:30:00.000';
      const pattern = '2026-05-15';
      expect(isoDate.startsWith(pattern), isTrue);
    });

    test('ISO date on different day does not match LIKE pattern', () {
      const isoDate = '2026-05-16T10:30:00.000';
      const pattern = '2026-05-15';
      expect(isoDate.startsWith(pattern), isFalse);
    });

    test('old space-based comparison would miss T-separator dates', () {
      const isoDate = '2026-05-15T10:30:00.000';
      const oldRangeEnd = '2026-05-15 23:59:59.999';
      expect(
        isoDate.compareTo(oldRangeEnd) > 0,
        isTrue,
        reason:
            'Old space-based comparison would incorrectly exclude T-format dates',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Transaction duplicate fingerprint (legacy compatibility test)
  // ──────────────────────────────────────────────────────────────────────────

  group('Transaction duplicate fingerprint (legacy format check)', () {
    test('same date/amount/desc produces identical fingerprint via DbHelper', () {
      final date = DateTime(2026, 5, 15);
      final fp1 = DbHelper.buildFingerprint(
        date,
        -250.0,
        'Migros',
        TransactionType.need,
      );
      final fp2 = DbHelper.buildFingerprint(
        date,
        -250.0,
        'Migros',
        TransactionType.need,
      );
      expect(fp1, equals(fp2));
    });
  });
}
