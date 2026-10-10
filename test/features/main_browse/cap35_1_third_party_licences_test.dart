import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/about_settings_section.dart';
import 'package:waketok/features/main_browse/open_privacy_policy.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

const _licencesRow = Key('aboutThirdPartyLicensesRow');
const _privacyRow = Key('aboutPrivacyPolicyRow');
const _chevron = Key('aboutThirdPartyLicensesChevronIcon');
const _externalIcon = Key('aboutPrivacyPolicyExternalIcon');

const Locale _zhHans = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hans',
);

/// [LicenseRegistry] is a process-wide static. The test binding registers no
/// collector, so [LicenseRegistry.reset] restores the default (empty) state;
/// each `flutter test` file runs in its own isolate.
void _registerFakeLicence() {
  LicenseRegistry.reset();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks([
      'fake_package',
    ], 'Fake licence text.');
  });
  addTearDown(LicenseRegistry.reset);
}

Widget _sectionHarness({
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
}) {
  return ProviderScope(
    overrides: [openPrivacyPolicyProvider.overrideWithValue(() async {})],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.light),
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const Scaffold(body: AboutSettingsSection()),
    ),
  );
}

Widget _shellHarness({ThemeMode themeMode = ThemeMode.system}) {
  return permissionUiHarness(
    repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
    themeMode: themeMode,
    assetSources: FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
        'a1',
      ]),
    ),
    cap30FirstLaunchGuidePreferences: FakeCap30FirstLaunchGuidePreferences()
      ..step = 3,
  );
}

Future<void> _openSettingsAbout(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavSettings));
  await tester.pumpAndSettle();
  await tester.dragUntilVisible(
    find.byKey(_licencesRow),
    find.byType(ListView),
    const Offset(0, -200),
  );
  await tester.pumpAndSettle();
}

/// Pumps the About section at [width] x 800 logical px with [scale], then
/// checks: no overflow, the chevron sits [kSettingsTitleInfoGap] after the
/// last title glyph on that glyph's line (scaled with the text, as the info
/// `i` is), the row keeps the 44 hit height, and a tap opens the licence page.
Future<void> _expectChevronHugsTitle(
  WidgetTester tester, {
  required Locale locale,
  required double scale,
  required double width,
  bool? expectWrap,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    _sectionHarness(locale: locale, textScaler: TextScaler.linear(scale)),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  final l10n = await AppLocalizations.delegate.load(locale);
  final title = l10n.settingsThirdPartyLicensesRow;
  final row = find.byKey(_licencesRow);
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().startsWith(title),
      ),
    ),
  );
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: title.length),
  );
  if (expectWrap != null) {
    final lineTops = boxes.map((b) => b.top.roundToDouble()).toSet();
    expect(
      lineTops.length > 1,
      expectWrap,
      reason: 'title line count ${lineTops.length} ($locale, x$scale)',
    );
  }

  final lastGlyph = boxes.last.toRect();
  final lastGlyphRight = paragraph.localToGlobal(Offset(lastGlyph.right, 0)).dx;
  final lineTop = paragraph.localToGlobal(Offset(0, lastGlyph.top)).dy;
  final lineBottom = paragraph.localToGlobal(Offset(0, lastGlyph.bottom)).dy;
  final chevron = tester.getRect(find.byKey(_chevron));
  expect(
    chevron.left - lastGlyphRight,
    moreOrLessEquals(kSettingsTitleInfoGap * scale, epsilon: 0.5),
    reason:
        'chevron left ${chevron.left} vs last glyph right $lastGlyphRight '
        '($locale, x$scale)',
  );
  expect(chevron.center.dy, inInclusiveRange(lineTop, lineBottom));

  expect(tester.getSize(row).height, greaterThanOrEqualTo(kSettingsInfoHit));
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(find.byType(LicensePage), findsOneWidget);
}

void main() {
  testWidgets('W-35.1-1 About lists Privacy Policy, then Third-party '
      'licences (en)', (tester) async {
    await tester.pumpWidget(_sectionHarness());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('${l10n.settingsAboutSectionTitle}:'), findsOneWidget);
    expect(
      find.textContaining(l10n.settingsThirdPartyLicensesRow),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(_licencesRow)).dy,
      greaterThan(tester.getTopLeft(find.byKey(_privacyRow)).dy),
    );
  });

  testWidgets('W-35.1-2 chevron sits only in the licences row and matches '
      'the external icon box and colour', (tester) async {
    await tester.pumpWidget(_sectionHarness());
    await tester.pumpAndSettle();

    Finder inRow(Key row, Key glyph) =>
        find.descendant(of: find.byKey(row), matching: find.byKey(glyph));

    expect(find.byKey(_chevron), findsOneWidget);
    expect(find.byKey(_externalIcon), findsOneWidget);
    expect(inRow(_licencesRow, _chevron), findsOneWidget);
    expect(inRow(_licencesRow, _externalIcon), findsNothing);
    expect(inRow(_privacyRow, _externalIcon), findsOneWidget);
    expect(inRow(_privacyRow, _chevron), findsNothing);

    final chevron = tester.widget<Icon>(find.byKey(_chevron));
    final external = tester.widget<Icon>(find.byKey(_externalIcon));
    expect(chevron.icon, Icons.arrow_forward_ios);
    expect(chevron.size, kSettingsInfoIconSize);
    expect(chevron.size, external.size);
    expect(chevron.color, external.color);
  });

  testWidgets('W-35.1-3 licences row is one button semantics node, not a '
      'link', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_sectionHarness());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final row = find.bySemanticsLabel(l10n.settingsThirdPartyLicensesRow);
    expect(row, findsOneWidget);
    expect(
      tester.getSemantics(row),
      isSemantics(
        label: l10n.settingsThirdPartyLicensesRow,
        isButton: true,
        isLink: false,
        hasTapAction: true,
      ),
    );
    expect(tester.getSemantics(row).childrenCount, 0);
    handle.dispose();
  });

  // 342 = iPhone 13 Pro width minus the Settings pane's 24 padding per side.
  testWidgets('W-35.1-4 chevron hugs the title at text scale 2.0 (en)', (
    tester,
  ) async {
    await _expectChevronHugsTitle(
      tester,
      locale: const Locale('en'),
      scale: 2.0,
      width: 342,
    );
  });

  testWidgets('W-35.1-5 chevron hugs the title at text scale 2.0 '
      '(zh-Hans)', (tester) async {
    await _expectChevronHugsTitle(
      tester,
      locale: _zhHans,
      scale: 2.0,
      width: 342,
    );
  });

  testWidgets('W-35.1-6 chevron follows the last glyph of a wrapped title '
      'at text scale 3.1 (en)', (tester) async {
    await _expectChevronHugsTitle(
      tester,
      locale: const Locale('en'),
      scale: 3.1,
      width: 342,
      expectWrap: true,
    );
  });

  testWidgets('W-35.1-7 chevron follows the last glyph of a wrapped title '
      'at text scale 3.1 (zh-Hans)', (tester) async {
    await _expectChevronHugsTitle(
      tester,
      locale: _zhHans,
      scale: 3.1,
      width: 160,
      expectWrap: true,
    );
  });

  testWidgets('W-35.1-8 en opens the licence page in British spelling; the '
      'override stays on that route', (tester) async {
    _registerFakeLicence();
    await tester.pumpWidget(_sectionHarness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_licencesRow));
    await tester.pumpAndSettle();

    final licensePage = find.byType(LicensePage);
    expect(licensePage, findsOneWidget);
    expect(
      Localizations.localeOf(tester.element(licensePage)),
      const Locale('en', 'GB'),
    );
    expect(find.text('Licences'), findsOneWidget);
    expect(find.text('WakeTok'), findsOneWidget);
    expect(find.text('1 licence'), findsOneWidget);
    expect(
      find.textContaining(RegExp('license', caseSensitive: false)),
      findsNothing,
    );

    await tester.tap(find.text('fake_package'));
    await tester.pumpAndSettle();
    expect(find.text('1 licence'), findsOneWidget);
    expect(find.text('Fake licence text.'), findsOneWidget);
    expect(
      find.textContaining(RegExp('license', caseSensitive: false)),
      findsNothing,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(licensePage, findsNothing);
    expect(
      Localizations.localeOf(tester.element(find.byKey(_licencesRow))),
      const Locale('en'),
    );
  });

  testWidgets('W-35.1-9 zh-Hans copy and licence page', (tester) async {
    _registerFakeLicence();
    await tester.pumpWidget(_sectionHarness(locale: _zhHans));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(_zhHans);
    expect(
      find.textContaining(l10n.settingsThirdPartyLicensesRow),
      findsOneWidget,
    );

    await tester.tap(find.byKey(_licencesRow));
    await tester.pumpAndSettle();
    expect(
      Localizations.localeOf(tester.element(find.byType(LicensePage))),
      _zhHans,
    );
    expect(find.text('许可'), findsOneWidget);
    expect(find.text('1 份许可'), findsOneWidget);
  });

  testWidgets('W-35.1-10 Settings pane opens the licence page and back '
      'returns to Settings', (tester) async {
    _registerFakeLicence();
    await tester.pumpWidget(_shellHarness());
    await tester.pumpAndSettle();
    await _openSettingsAbout(tester);

    await tester.tap(find.byKey(_licencesRow));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsNothing);
    expect(find.byKey(_licencesRow), findsOneWidget);
    expect(find.byKey(const Key('aboutSettingsSection')), findsOneWidget);
  });

  for (final (mode, iconBrightness, settingsStyle) in [
    (ThemeMode.light, Brightness.dark, SystemUiOverlayStyle.dark),
    (ThemeMode.dark, Brightness.light, SystemUiOverlayStyle.light),
  ]) {
    testWidgets('W-35.1-11 licence page status bar follows Appearance; '
        'Settings style returns after back (${mode.name})', (tester) async {
      _registerFakeLicence();
      await tester.pumpWidget(_shellHarness(themeMode: mode));
      await tester.pumpAndSettle();
      await _openSettingsAbout(tester);
      expect(SystemChrome.latestStyle, settingsStyle);

      await tester.tap(find.byKey(_licencesRow));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      expect(SystemChrome.latestStyle?.statusBarIconBrightness, iconBrightness);
      expect(
        SystemChrome.latestStyle?.statusBarBrightness,
        settingsStyle.statusBarBrightness,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, settingsStyle);
    });
  }
}
