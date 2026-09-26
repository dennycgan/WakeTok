import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_new_round_toast_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

Future<void> _openSettings(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavSettings));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('browseNotificationsSettingsSection')),
    findsOneWidget,
  );
}

void main() {
  testWidgets('W-22.5-BrowseSettings-1 Browse section toggle writes prefs',
      (tester) async {
    final prefs = FakeNewRoundToastPreferences();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']),
        newRoundToastPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final section = find.byKey(const Key('browseNotificationsSettingsSection'));
    expect(section, findsOneWidget);
    expect(
      find.descendant(
        of: section,
        matching: find.text(l10n.browseSettingsSectionTitle),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.browseSettingsNewRoundToastTitle), findsOneWidget);
    expect(find.text(l10n.browseSettingsNewRoundToastSubtitle), findsNothing);
    expect(find.byKey(const Key('browseSettingsNewRoundToastInfo')), findsOneWidget);

    final toggle = find.byKey(const Key('browseSettingsNewRoundToastToggle'));
    expect(tester.widget<CupertinoSwitch>(find.descendant(
      of: toggle,
      matching: find.byType(CupertinoSwitch),
    )).value, isTrue);

    // Cap 30.6 D7 lengthened Gestures master subtitle; Browse tip toggle can
    // sit below the default test viewport — scroll before tap.
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: toggle,
      matching: find.byType(CupertinoSwitch),
    ));
    await tester.pumpAndSettle();
    expect(prefs.newRoundToastEnabled, isFalse);
  });
}
