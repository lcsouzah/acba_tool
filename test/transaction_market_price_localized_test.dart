import 'package:acba_tool/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('transactions market price localized parsing', () {
    testWidgets('market price field accepts comma decimals', (tester) async {
      Intl.defaultLocale = 'de_DE';
      addTearDown(() => Intl.defaultLocale = 'en_US');

      await tester.pumpWidget(const MaterialApp(home: TransactionsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);

      final quantityField =
      find.descendant(of: sheet, matching: find.byType(TextFormField)).at(0);
      final priceField =
      find.descendant(of: sheet, matching: find.byType(TextFormField)).at(1);

      await tester.enterText(quantityField, '1');
      await tester.enterText(priceField, '1');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('— set market —'), findsOneWidget);

      final marketField = find.widgetWithText(TextField, 'Market price');
      await tester.enterText(marketField, '1.234,56');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('— set market —'), findsNothing);
      expect(find.text('${String.fromCharCode(36)}1233.56'), findsOneWidget);
    });
  });
}