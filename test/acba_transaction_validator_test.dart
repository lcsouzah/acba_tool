import 'package:flutter_test/flutter_test.dart';
import 'package:acba_tool/screens/transactions_screen.dart'; // adjust path as needed

void main() {
  group('ACBA Transaction Validator', () {
    final rules = AcbaRules(buyThreshold: 0.98, cooldownDays: 3, maxDailySpend: 500);

    test('allows first buy regardless of price', () {
      final tx = TransactionModel(
        id: '1',
        type: TxType.buy,
        quantity: 10,
        price: 100,
        ts: DateTime.now(),
      );
      final validator = _TestValidator([], rules);
      expect(validator.validateBuy(tx), isNull);
    });

    test('blocks buy above threshold price', () {
      final now = DateTime.now();
      final existing = [
        TransactionModel(id: '1', type: TxType.buy, quantity: 10, price: 100, ts: now.subtract(const Duration(days: 10)))
      ];
      final tx = TransactionModel(id: '2', type: TxType.buy, quantity: 1, price: 99, ts: now);
      final validator = _TestValidator(existing, rules);
      final result = validator.validateBuy(tx);
      expect(result, contains('Price too high'));
    });

    test('blocks buy during cooldown', () {
      final now = DateTime.now();
      final existing = [
        TransactionModel(id: '1', type: TxType.buy, quantity: 10, price: 90, ts: now.subtract(const Duration(days: 1)))
      ];
      final tx = TransactionModel(id: '2', type: TxType.buy, quantity: 5, price: 80, ts: now);
      final validator = _TestValidator(existing, rules);
      final result = validator.validateBuy(tx);
      expect(result, contains('Cooldown active'));
    });

    test('blocks buy when daily spend exceeded', () {
      final now = DateTime.now();
      final existing = [
        TransactionModel(id: '1', type: TxType.buy, quantity: 10, price: 40, ts: now)
      ];
      final tx = TransactionModel(id: '2', type: TxType.buy, quantity: 20, price: 30, ts: now);
      final validator = _TestValidator(existing, rules);
      final result = validator.validateBuy(tx);
      expect(result, contains('Daily spend limit'));
    });

    test('allows buy if within threshold, cooldown, and spend rules', () {
      final now = DateTime.now();
      final existing = [
        TransactionModel(id: '1', type: TxType.buy, quantity: 10, price: 100, ts: now.subtract(const Duration(days: 5)))
      ];
      final tx = TransactionModel(id: '2', type: TxType.buy, quantity: 5, price: 95, ts: now);
      final validator = _TestValidator(existing, rules);
      expect(validator.validateBuy(tx), isNull);
    });
  });
}

// Helper class to expose validation without widget context
class _TestValidator {
  final List<TransactionModel> tx;
  final AcbaRules rules;
  _TestValidator(this.tx, this.rules);

  String? validateBuy(TransactionModel buy) {
    double qty = 0;
    double cost = 0;
    for (final t in tx.reversed) {
      if (t.type == TxType.buy) {
        cost += t.quantity * t.price + t.fee;
        qty += t.quantity;
      }
    }
    final avg = qty == 0 ? 0.0 : cost / qty;
    if (qty == 0) return null;

    final thresholdPrice = avg * rules.buyThreshold;
    if (buy.price > thresholdPrice) return 'Price too high';

    final lastBuy = tx.firstWhere((t) => t.type == TxType.buy, orElse: () => buy);
    final days = buy.ts.difference(lastBuy.ts).inDays;
    if (days < rules.cooldownDays) return 'Cooldown active';

    final todaySpend = tx.where((t) =>
    t.type == TxType.buy &&
        t.ts.year == buy.ts.year &&
        t.ts.month == buy.ts.month &&
        t.ts.day == buy.ts.day)
        .fold(0.0, (s, t) => s + t.quantity * t.price + t.fee);
    final thisSpend = buy.quantity * buy.price + buy.fee;
    if (todaySpend + thisSpend > rules.maxDailySpend) return 'Daily spend limit';

    return null;
  }
}
