import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:acba_tool/screens/home_screen.dart';
import 'test_utils.dart';

Future<void> _pumpApp(
    WidgetTester tester, {
      required String avgPrice,
      required String tokenQty,
      required String tokenPrice,
      required String targetAvg,
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
  group('localized number parsing', () {
    testWidgets('parses en_US formatted numbers', (tester) async {
      Intl.defaultLocale = 'en_US';
      final storage = InMemorySecureStorage();
      await _pumpApp(
        tester,
        avgPrice: '2,000.5',
        tokenQty: '1,000',
        tokenPrice: '1,500.5',
        targetAvg: '1,800.5',
        storage: storage,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('✅ ACBA Buy Approved'), findsOneWidget);
    });

    testWidgets('parses de_DE formatted numbers', (tester) async {
      Intl.defaultLocale = 'de_DE';
      final storage = InMemorySecureStorage();
      await _pumpApp(
        tester,
        avgPrice: '5,00',
        tokenQty: '1.000',
        tokenPrice: '3,00',
        targetAvg: '4,50',
        storage: storage,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('✅ ACBA Buy Approved'), findsOneWidget);
    });

    testWidgets('parses fr_FR formatted numbers with spaces', (tester) async {
      Intl.defaultLocale = 'fr_FR';
      final storage = InMemorySecureStorage();
      await _pumpApp(
        tester,
        avgPrice: '5,00',
        tokenQty: '1 000',
        tokenPrice: '3,00',
        targetAvg: '4,50',
        storage: storage,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
      await tester.pumpAndSettle();
      expect(find.textContaining('✅ ACBA Buy Approved'), findsOneWidget);
    });
  });

  testWidgets('shows friendly error on invalid format', (tester) async {
    Intl.defaultLocale = 'en_US';
    final storage = InMemorySecureStorage();
    await _pumpApp(
      tester,
      avgPrice: 'abc',
      tokenQty: '10',
      tokenPrice: '5',
      targetAvg: '4',
      storage: storage,
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
    await tester.pumpAndSettle();
    expect(find.text('❌ Invalid number format.'), findsOneWidget);
  });
}