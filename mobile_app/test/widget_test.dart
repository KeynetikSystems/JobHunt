import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jobhunt_mobile/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App launches to the Dashboard tab', (WidgetTester tester) async {
    await tester.pumpWidget(const JobHuntApp());
    await tester.pumpAndSettle();

    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.text('Your entries'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('Tapping Settings switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const JobHuntApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Backend URL'), findsOneWidget);
  });
}
