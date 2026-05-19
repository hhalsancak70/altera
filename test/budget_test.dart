import 'package:flutter_test/flutter_test.dart';
import 'package:altera/core/models/budget.dart';
import 'package:altera/core/models/transaction.dart';

void main() {
  group('Budget model', () {
    Budget make({double limit = 1000.0, double spent = 0.0}) => Budget(
      id: 'b-1',
      category: TransactionCategory.restaurant,
      limitAmount: limit,
      spentAmount: spent,
      month: DateTime(2026, 5),
    );

    test('status — %0 harcama → safe', () {
      expect(make().status, equals(BudgetStatus.safe));
    });

    test('status — %79 harcama → safe', () {
      expect(make(spent: 790).status, equals(BudgetStatus.safe));
    });

    test('status — %80 harcama → warning', () {
      expect(make(spent: 800).status, equals(BudgetStatus.warning));
    });

    test('status — %99 harcama → warning', () {
      expect(make(spent: 990).status, equals(BudgetStatus.warning));
    });

    test('status — %100 harcama → danger', () {
      expect(make(spent: 1000).status, equals(BudgetStatus.danger));
    });

    test('status — %120 harcama → danger', () {
      expect(make(spent: 1200).status, equals(BudgetStatus.danger));
    });

    test('usagePercentage hesabı doğru', () {
      expect(make(limit: 1000, spent: 500).usagePercentage, equals(0.5));
      expect(make(limit: 1000, spent: 1500).usagePercentage, equals(1.5));
    });

    test('remainingAmount — negatif olabilir', () {
      expect(make(limit: 1000, spent: 1200).remainingAmount, equals(-200.0));
    });

    test('overspentAmount — limit aşılmadıysa 0', () {
      expect(make(limit: 1000, spent: 800).overspentAmount, equals(0.0));
    });

    test('overspentAmount — limit aşıldıysa pozitif', () {
      expect(make(limit: 1000, spent: 1300).overspentAmount, equals(300.0));
    });

    test('limitAmount sıfır olduğunda usagePercentage 0 döner', () {
      expect(make(limit: 0, spent: 500).usagePercentage, equals(0.0));
    });

    test('toJson → fromJson round-trip', () {
      final b = make(limit: 1500, spent: 900);
      final json = b.toJson();
      final restored = Budget.fromJson(json);

      expect(restored.id, equals(b.id));
      expect(restored.limitAmount, equals(b.limitAmount));
      expect(restored.spentAmount, equals(b.spentAmount));
      expect(restored.category, equals(b.category));
    });
  });
}
