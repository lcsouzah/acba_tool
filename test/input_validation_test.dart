import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acba_tool/screens/home_screen.dart';
import 'test_utils.dart';

Future<void> _pumpApp(
    WidgetTester tester, {
      String avgPrice = '100',
      String tokenQty = '10',
      String tokenPrice = '90',
      String targetAvg = '95',
      required InMemorySecureStorage storage,
    }) async {
  await tester.pumpWidget(MaterialApp(home: AcbaHomeScreen(storage: storage)));
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(0), avgPrice);
  await tester.enterText(find.byType(TextField).at(1), tokenQty);
  await tester.enterText(find.byType(TextField).at(2), tokenPrice);
  await tester.enterText(find.byType(TextField).at(3), targetAvg);
}

void main() {
  group('input validation', () {
    testWidgets('shows error when any value is zero', (tester) async {
      final storage = InMemorySecureStorage();
      await _pumpApp(tester, tokenQty: '0', storage: storage);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pump();
      expect(find.text('❌ Please enter numbers greater than zero.'), findsOneWidget);
    });

    testWidgets('shows error when any value is negative', (tester) async {
      final storage = InMemorySecureStorage();
      await _pumpApp(tester, tokenQty: '-5', storage: storage);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pump();
      expect(find.text('❌ Please enter numbers greater than zero.'), findsOneWidget);
    });
  });
}