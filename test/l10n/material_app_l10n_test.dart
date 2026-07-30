import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/main.dart';

void main() {
  testWidgets('T7 forced zh_Hans shows 本地化正常', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: L10nSmokePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('本地化正常'), findsWidgets);
  });

  testWidgets('T8 forced en shows Localization OK', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: L10nSmokePage(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Localization OK'), findsWidgets);
  });

  testWidgets('WakeTokApp builds with l10n delegates', (tester) async {
    await tester.pumpWidget(const WakeTokApp());
    await tester.pumpAndSettle();
    expect(find.byType(L10nSmokePage), findsOneWidget);
  });
}
