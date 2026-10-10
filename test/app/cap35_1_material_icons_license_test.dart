import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/third_party_licenses.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/about_settings_section.dart';
import 'package:waketok/features/main_browse/open_privacy_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

const _copyright = 'Copyright 2019 Google LLC. All Rights Reserved.';
const _attribution =
    'Material Icons by Google, licensed under the Creative Commons '
    'Attribution 4.0 International Public License (CC BY 4.0): '
    'https://creativecommons.org/licenses/by/4.0/legalcode';
const _disclaimer =
    'Provided as is, without warranties; see section 5 of the licence for '
    'the full disclaimer.';
const _modified =
    'Modified: WakeTok includes a subset of the font that keeps only the '
    'icons the app uses.';

/// [LicenseRegistry] is a process-wide static; the test binding registers no
/// collector, so [LicenseRegistry.reset] restores the empty default.
void _registerAppLicenses() {
  LicenseRegistry.reset();
  registerThirdPartyLicenses();
  addTearDown(LicenseRegistry.reset);
}

void main() {
  test('T-35.1-MI-1 registers one Material Icons entry with the CC BY 4.0 '
      'notice', () async {
    _registerAppLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    expect(entries, hasLength(1));
    expect(entries.single.packages, ['Material Icons']);
    expect(entries.single.paragraphs.map((p) => p.text).toList(), [
      _copyright,
      _attribution,
      _disclaimer,
      _modified,
    ]);
  });

  testWidgets('T-35.1-MI-2 licence page lists Material Icons and shows the '
      'notice (en)', (tester) async {
    _registerAppLicenses();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [openPrivacyPolicyProvider.overrideWithValue(() async {})],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: waketokTheme(Brightness.light),
          home: const Scaffold(body: AboutSettingsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('aboutThirdPartyLicensesRow')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Material Icons'), findsOneWidget);
    expect(find.text('1 licence'), findsOneWidget);

    await tester.tap(find.text('Material Icons'));
    await tester.pumpAndSettle();
    for (final paragraph in [
      _copyright,
      _attribution,
      _disclaimer,
      _modified,
    ]) {
      expect(find.text(paragraph), findsOneWidget, reason: paragraph);
    }
  });

  test('T-35.1-MI-3 main() registers the licences once, after binding '
      'init', () {
    final source = File('lib/main.dart').readAsStringSync();
    const call = 'registerThirdPartyLicenses();';
    expect(call.allMatches(source), hasLength(1));
    expect(
      source.indexOf(call),
      greaterThan(source.indexOf('WidgetsFlutterBinding.ensureInitialized();')),
    );
    expect(source.indexOf(call), lessThan(source.indexOf('runApp(')));
  });
}
