import 'package:acba_tool/screens/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('invalid BUY keeps sheet open and shows validation error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TransactionsScreen()));
    await tester.pumpAndSettle();

    // Seed with a valid BUY so that future BUYs require validation.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final initialSheet = find.byType(BottomSheet);
    final initialQtyField =
    find.descendant(of: initialSheet, matching: find.byType(TextFormField)).at(0);
    final initialPriceField =
    find.descendant(of: initialSheet, matching: find.byType(TextFormField)).at(1);

    await tester.enterText(initialQtyField, '1');
    await tester.enterText(initialPriceField, '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);

    // Attempt an invalid BUY (price above ACBA threshold) and ensure error is shown.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    final qtyField = find.descendant(of: sheet, matching: find.byType(TextFormField)).at(0);
    final priceField = find.descendant(of: sheet, matching: find.byType(TextFormField)).at(1);

    await tester.enterText(qtyField, '1');
    await tester.enterText(priceField, '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pump();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('Price too high for discipline'), findsOneWidget);

    final qtyWidget = tester.widget<TextFormField>(qtyField);
    final priceWidget = tester.widget<TextFormField>(priceField);

    expect(qtyWidget.controller?.text, '1');
    expect(priceWidget.controller?.text, '100');
  });
}