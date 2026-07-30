import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/main.dart';

void main() {
  testWidgets('WakeTokApp smoke home shows l10n string', (tester) async {
    await tester.pumpWidget(const WakeTokApp());
    await tester.pumpAndSettle();
    expect(find.byType(L10nSmokePage), findsOneWidget);
    // Device test locale is typically en in flutter_test.
    expect(find.text('Localization OK'), findsWidgets);
  });
}
