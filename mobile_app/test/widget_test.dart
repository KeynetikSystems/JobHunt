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
    expect(find.text("Today's entries"), findsOneWidget);
    expect(find.text('Run scan now'), findsOneWidget);
  });

  testWidgets('Tapping Settings switches tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const JobHuntApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Backend URL'), findsOneWidget);
  });
}
