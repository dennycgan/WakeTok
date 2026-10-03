import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/config/app_links.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/about_settings_section.dart';
import 'package:waketok/features/main_browse/open_privacy_policy.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Widget _sectionHarness({
  required OpenPrivacyPolicy openPrivacyPolicy,
  Locale locale = const Locale('en'),
  TextScaler? textScaler,
}) {
  return ProviderScope(
    overrides: [openPrivacyPolicyProvider.overrideWithValue(openPrivacyPolicy)],
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

const Locale _zhHans = Locale.fromSubtags(
  languageCode: 'zh',
  scriptCode: 'Hans',
);

/// Pumps the About section at [width] x 800 logical px with [scale], then
/// checks: no overflow, the row still opens the link, and the external icon
/// sits twice [kSettingsTitleInfoGap] after the last title glyph on that
/// glyph's line. WidgetSpan children scale with the text (as the info `i` does), so
/// the gap is measured in scaled units. When [expectWrap] is set, the title
/// must wrap (true) or stay on one line (false).
Future<void> _expectIconHugsTitle(
  WidgetTester tester, {
  required Locale locale,
  required double scale,
  required double width,
  bool? expectWrap,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  var opens = 0;
  await tester.pumpWidget(
    _sectionHarness(
      openPrivacyPolicy: () async => opens += 1,
      locale: locale,
      textScaler: TextScaler.linear(scale),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  final l10n = await AppLocalizations.delegate.load(locale);
  final title = l10n.settingsPrivacyPolicyRow;
  final row = find.byKey(const Key('aboutPrivacyPolicyRow'));
  final paragraphFinder = find.descendant(
    of: row,
    matching: find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().startsWith(title),
    ),
  );
  final paragraph = tester.renderObject<RenderParagraph>(paragraphFinder);
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: title.length),
  );
  final lineTops = boxes.map((b) => b.top.roundToDouble()).toSet();
  if (expectWrap != null) {
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
  final icon = tester.getRect(
    find.byKey(const Key('aboutPrivacyPolicyExternalIcon')),
  );
  expect(
    icon.left - lastGlyphRight,
    moreOrLessEquals(2 * kSettingsTitleInfoGap * scale, epsilon: 0.5),
    reason:
        'icon left ${icon.left} vs last glyph right $lastGlyphRight '
        '($locale, x$scale)',
  );
  expect(icon.center.dy, inInclusiveRange(lineTop, lineBottom));

  expect(tester.getSize(row).height, greaterThanOrEqualTo(kSettingsInfoHit));
  await tester.tap(row);
  await tester.pumpAndSettle();
  expect(opens, 1);
}

void main() {
  test(
    'T-32-About-1 privacy policy URL is the published waketok-site page',
    () {
      expect(
        kPrivacyPolicyUrl,
        'https://dennycgan.github.io/waketok-site/privacy/',
      );
    },
  );

  testWidgets('W-32-About-1 row shows title and external icon; tap opens', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      _sectionHarness(openPrivacyPolicy: () async => opens += 1),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('${l10n.settingsAboutSectionTitle}:'), findsOneWidget);
    expect(find.textContaining(l10n.settingsPrivacyPolicyRow), findsOneWidget);
    expect(
      find.byKey(const Key('aboutPrivacyPolicyExternalIcon')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('aboutPrivacyPolicyRow')));
    await tester.pumpAndSettle();
    expect(opens, 1);
  });

  testWidgets('W-32-About-2 row is one link semantics node without the icon', (
    tester,
  ) async {
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
    expect(find.textContaining(l10n.settingsPrivacyPolicyRow), findsOneWidget);
  });

  testWidgets('W-32-About-4 Settings pane mounts About below Notifications', (
    tester,
  ) async {
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
    final notifications = find.byKey(
      const Key('browseNotificationsSettingsSection'),
    );
    expect(
      tester.getTopLeft(about).dy,
      greaterThan(tester.getTopLeft(notifications).dy),
    );
  });

  // 342 = iPhone 13 Pro width minus the Settings pane's 24 padding per side.
  testWidgets('W-32-About-7 icon hugs the title at text scale 2.0 (en)', (
    tester,
  ) async {
    await _expectIconHugsTitle(
      tester,
      locale: const Locale('en'),
      scale: 2.0,
      width: 342,
    );
  });

  testWidgets('W-32-About-8 icon hugs the title at text scale 2.0 (zh-Hans)', (
    tester,
  ) async {
    await _expectIconHugsTitle(tester, locale: _zhHans, scale: 2.0, width: 342);
  });

  testWidgets(
    'W-32-About-9 icon follows the last glyph of a wrapped title at text '
    'scale 3.1 (en)',
    (tester) async {
      await _expectIconHugsTitle(
        tester,
        locale: const Locale('en'),
        scale: 3.1,
        width: 342,
        expectWrap: true,
      );
    },
  );

  testWidgets(
    'W-32-About-10 icon follows the last glyph of a wrapped title at text '
    'scale 3.1 (zh-Hans)',
    (tester) async {
      await _expectIconHugsTitle(
        tester,
        locale: _zhHans,
        scale: 3.1,
        width: 160,
        expectWrap: true,
      );
    },
  );
}
