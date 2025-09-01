import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:acba_tool/screens/home_screen.dart';
import 'test_utils.dart';

Future<void> _enterValidInputs(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '100');
  await tester.enterText(find.byType(TextField).at(1), '10');
  await tester.enterText(find.byType(TextField).at(2), '90');
  await tester.enterText(find.byType(TextField).at(3), '95');
}

void main() {
  testWidgets('save, load, and clear history with secure storage', (tester) async {
    final storage = InMemorySecureStorage();

    // Initial run saves to storage
    await tester.pumpWidget(MaterialApp(home: AcbaHomeScreen(storage: storage)));
    await tester.pump();
    await _enterValidInputs(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Calculate'));
    await tester.pumpAndSettle();
    expect(find.byType(Dismissible), findsOneWidget);

    // Recreate widget to load from storage
    await tester.pumpWidget(Container());
    await tester.pumpWidget(MaterialApp(home: AcbaHomeScreen(storage: storage)));
    await tester.pump();
    expect(find.byType(Dismissible), findsOneWidget);

    // Clear history
    await tester.tap(find.text('Clear History'));
    await tester.pumpAndSettle();
    expect(find.text('No history yet.'), findsOneWidget);

    // Ensure storage cleared
    await tester.pumpWidget(Container());
    await tester.pumpWidget(MaterialApp(home: AcbaHomeScreen(storage: storage)));
    await tester.pump();
    expect(find.text('No history yet.'), findsOneWidget);
  });
}
