import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:acba_tool/screens/home_screen.dart';

Future<void> _pumpApp(
    WidgetTester tester, {
      String avgPrice = '100',
      String tokenQty = '10',
      String tokenPrice = '90',
      String targetAvg = '95',
    }) async {
  await tester.pumpWidget(const MaterialApp(home: AcbaHomeScreen()));
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(0), avgPrice);
  await tester.enterText(find.byType(TextField).at(1), tokenQty);
  await tester.enterText(find.byType(TextField).at(2), tokenPrice);
  await tester.enterText(find.byType(TextField).at(3), targetAvg);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('input validation', () {
    testWidgets('shows error when any value is zero', (tester) async {
      await _pumpApp(tester, tokenQty: '0');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pump();
      expect(find.text('❌ Please enter numbers greater than zero.'), findsOneWidget);
    });

    testWidgets('shows error when any value is negative', (tester) async {
      await _pumpApp(tester, tokenQty: '-5');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pump();
      expect(find.text('❌ Please enter numbers greater than zero.'), findsOneWidget);
    });
  });
}