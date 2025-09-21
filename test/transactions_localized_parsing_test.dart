import 'package:acba_tool/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('transactions localized parsing', () {
    testWidgets('add transaction accepts comma decimals', (tester) async {
      Intl.defaultLocale = 'de_DE';
      addTearDown(() => Intl.defaultLocale = 'en_US');

      await tester.pumpWidget(const MaterialApp(home: TransactionsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);

      final quantityField = find.descendant(of: sheet, matching: find.byType(TextFormField)).at(0);
      final priceField = find.descendant(of: sheet, matching: find.byType(TextFormField)).at(1);
      final feeField = find.descendant(of: sheet, matching: find.byType(TextFormField)).at(2);

      await tester.enterText(quantityField, '1.234,56');
      await tester.enterText(priceField, '0,98');
      await tester.enterText(feeField, '');

      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1234.5600'), findsOneWidget);
      expect(find.textContaining(r'@ $0.98'), findsOneWidget);
    });

    testWidgets('rules sheet accepts comma decimals', (tester) async {
      Intl.defaultLocale = 'de_DE';
      addTearDown(() => Intl.defaultLocale = 'en_US');

      await tester.pumpWidget(const MaterialApp(home: TransactionsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.rule));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);

      final thresholdField = find.descendant(of: sheet, matching: find.byType(TextField)).at(0);
      final cooldownField = find.descendant(of: sheet, matching: find.byType(TextField)).at(1);
      final dailyField = find.descendant(of: sheet, matching: find.byType(TextField)).at(2);

      await tester.enterText(thresholdField, '0,98');
      await tester.enterText(cooldownField, '2');
      await tester.enterText(dailyField, '1.234,56');

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.byIcon(Icons.rule));
      await tester.pumpAndSettle();

      final reopenedSheet = find.byType(BottomSheet);
      expect(reopenedSheet, findsOneWidget);

      final reopenedFields = find.descendant(of: reopenedSheet, matching: find.byType(TextField));
      final reopenedThreshold = tester.widget<TextField>(reopenedFields.at(0));
      final reopenedDaily = tester.widget<TextField>(reopenedFields.at(2));

      expect(reopenedThreshold.controller?.text, '0.98');
      expect(reopenedDaily.controller?.text, '1234.56');
    });
  });
}