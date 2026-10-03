import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/config/app_links.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/about_settings_section.dart';
import 'package:waketok/features/main_browse/open_privacy_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Widget _sectionHarness({
  required OpenPrivacyPolicy openPrivacyPolicy,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      openPrivacyPolicyProvider.overrideWithValue(openPrivacyPolicy),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.light),
      home: const Scaffold(body: AboutSettingsSection()),
    ),
  );
}

void main() {
  test('T-32-About-1 privacy policy URL is the published waketok-site page',
      () {
    expect(
      kPrivacyPolicyUrl,
      'https://dennycgan.github.io/waketok-site/privacy/',
    );
  });

  testWidgets('W-32-About-1 row shows title and external icon; tap opens',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(
      _sectionHarness(openPrivacyPolicy: () async => opens += 1),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('${l10n.settingsAboutSectionTitle}:'), findsOneWidget);
    expect(find.text(l10n.settingsPrivacyPolicyRow), findsOneWidget);
    expect(
      find.byKey(const Key('aboutPrivacyPolicyExternalIcon')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aboutPrivacyPolicyRow')));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('W-32-About-2 row is one link semantics node without the icon',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_sectionHarness(openPrivacyPolicy: () async {}));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final row = find.bySemanticsLabel(l10n.settingsPrivacyPolicyRow);
    expect(row, findsOneWidget);
    expect(
      tester.getSemantics(row),
      isSemantics(
        label: l10n.settingsPrivacyPolicyRow,
        isLink: true,
        hasTapAction: true,
      ),
    );
    expect(tester.getSemantics(row).childrenCount, 0);
    handle.dispose();
  });

  testWidgets('W-32-About-3 zh-Hans copy', (tester) async {
    await tester.pumpWidget(
      _sectionHarness(
        openPrivacyPolicy: () async {},
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    expect(find.text('${l10n.settingsAboutSectionTitle}：'), findsOneWidget);
    expect(find.text(l10n.settingsPrivacyPolicyRow), findsOneWidget);
  });

  testWidgets('W-32-About-4 Settings pane mounts About below Notifications',
      (tester) async {
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: FakeAssetSourceRepository(allIds: const ['a', 'b']),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();

    final about = find.byKey(const Key('aboutSettingsSection'));
    await tester.dragUntilVisible(
      about,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(about, findsOneWidget);
    final notifications =
        find.byKey(const Key('browseNotificationsSettingsSection'));
    expect(
      tester.getTopLeft(about).dy,
      greaterThan(tester.getTopLeft(notifications).dy),
    );
  });
}
