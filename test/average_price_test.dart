import 'package:flutter_test/flutter_test.dart';
import 'package:acba_tool/screens/transactions_screen.dart';

void main() {
  group('Average price calculations', () {
    test('Sequential buys update average price', () {
      final now = DateTime.now();
      final tx = [
        TransactionModel(
          id: 'b2',
          type: TxType.buy,
          quantity: 1,
          price: 120,
          ts: now.subtract(const Duration(days: 1)),
        ),
        TransactionModel(
          id: 'b1',
          type: TxType.buy,
          quantity: 1,
          price: 100,
          ts: now.subtract(const Duration(days: 2)),
        ),
      ];

      final stats = computeStats(tx);
      expect(stats.qty, 2);
      expect(stats.avg, closeTo(110, 0.0001));
    });

    test('Sells reduce quantity and adjust cost basis', () {
      final now = DateTime.now();
      final tx = [
        TransactionModel(
          id: 's1',
          type: TxType.sell,
          quantity: 1,
          price: 250,
          ts: now,
        ),
        TransactionModel(
          id: 'b2',
          type: TxType.buy,
          quantity: 2,
          price: 200,
          ts: now.subtract(const Duration(days: 1)),
        ),
        TransactionModel(
          id: 'b1',
          type: TxType.buy,
          quantity: 2,
          price: 100,
          ts: now.subtract(const Duration(days: 2)),
        ),
      ];

      final stats = computeStats(tx);
      expect(stats.qty, 3);
      expect(stats.avg, closeTo(150, 0.0001));
      expect(stats.qty * stats.avg, closeTo(450, 0.0001));
    });

    test('Fees increase cost basis', () {
      final now = DateTime.now();
      final tx = [
        TransactionModel(
          id: 'f1',
          type: TxType.fee,
          quantity: 0,
          price: 0,
          fee: 10,
          ts: now,
        ),
        TransactionModel(
          id: 'b1',
          type: TxType.buy,
          quantity: 2,
          price: 100,
          ts: now.subtract(const Duration(days: 1)),
        ),
      ];

      final stats = computeStats(tx);
      expect(stats.qty, 2);
      expect(stats.avg, closeTo(105, 0.0001));
    });
  });
}