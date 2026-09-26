import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

TextStyle? _styleOf(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  return text.style;
}

/// P4 layer C: guidance copy must not use labelOnMedia (12), even if a
/// positive token match would still pass after a bad token drift.
void _expectNotLabelOnMedia(double? fontSize, WakeTokTokens tokens) {
  expect(fontSize, isNot(tokens.labelOnMedia.fontSize));
}

void main() {
  setUp(Cap19LeftSwipeGuideSession.resetForTest);
  tearDown(Cap19LeftSwipeGuideSession.resetForTest);

  testWidgets(
    'T-30.6-C1 Browse <3> subtitle is Settings redirect (EN)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: FakeCap19LeftSwipePreferences()
            ..leftSwipeAddEnabled = true
            ..leftSwipeGuideEnabled = true,
          // disk=3 so Cap 30 chain does not block Cap 19 tip.
          cap30FirstLaunchGuidePreferences:
              FakeCap30FirstLaunchGuidePreferences()..step = 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19LeftSwipeGuideSubtitle')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('cap19LeftSwipeGuideSubtitle'))).data,
        l10n.cap19LeftSwipeGuideSubtitle,
      );
      expect(
        l10n.cap19LeftSwipeGuideSubtitle,
        'You can turn this feature and tip off in Settings',
      );
      expect(
        find.textContaining('bookmark for later in Photos'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'T-30.6-C2 Settings master add safety copy lives in info bubble (EN)',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: FakeCap19LeftSwipePreferences(),
          cap30FirstLaunchGuidePreferences:
              FakeCap30FirstLaunchGuidePreferences()..step = 3,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.mainBrowseNavSettings));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19GesturesSettingsSection')), findsOneWidget);
      // Cap 31.1 D2 A: safety copy is not a list subtitle.
      expect(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
          matching: find.text(l10n.cap19SettingsLeftSwipeAddSubtitle),
        ),
        findsNothing,
      );
      expect(
        l10n.cap19SettingsLeftSwipeAddSubtitle,
        'Saves it to your WakeTok album as a bookmark for later in Photos — '
        'nothing is moved or deleted',
      );
      await tester.tap(find.byKey(const Key('cap19SettingsLeftSwipeAddInfo')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cap19SettingsLeftSwipeAddInfoBubble')),
        findsOneWidget,
      );
      expect(find.text(l10n.cap19SettingsLeftSwipeAddSubtitle), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeGuideToggle')),
          matching: find.text(l10n.cap19SettingsLeftSwipeGuideSubtitle),
        ),
        findsNothing,
      );
      // Dismiss add bubble before opening guide info (opaque barrier blocks taps).
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cap19SettingsLeftSwipeGuideInfo')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.cap19SettingsLeftSwipeGuideSubtitle), findsOneWidget);
    },
  );

  testWidgets(
    'T-30.6-C4a <3> title/body use titleChrome / bodyOnMedia sizes',
    (tester) async {
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: FakeCap19LeftSwipePreferences()
            ..leftSwipeAddEnabled = true
            ..leftSwipeGuideEnabled = true,
          cap30FirstLaunchGuidePreferences:
              FakeCap30FirstLaunchGuidePreferences()..step = 3,
        ),
      );
      await tester.pumpAndSettle();

      final tokens = Theme.of(
        tester.element(find.byKey(const Key('cap19LeftSwipeGuide'))),
      ).extension<WakeTokTokens>()!;
      expect(tokens.titleChrome.fontSize, 24);
      expect(tokens.bodyOnMedia.fontSize, 13);

      final title3 = _styleOf(
        tester,
        find.byKey(const Key('cap19LeftSwipeGuideTitle')),
      )?.fontSize;
      final body3 = _styleOf(
        tester,
        find.byKey(const Key('cap19LeftSwipeGuideSubtitle')),
      )?.fontSize;
      expect(title3, tokens.titleChrome.fontSize);
      expect(body3, tokens.bodyOnMedia.fontSize);
      _expectNotLabelOnMedia(title3, tokens);
      _expectNotLabelOnMedia(body3, tokens);
    },
  );

  testWidgets(
    'T-30.6-C4b <1> title and <2> body use titleChrome / bodyOnMedia sizes',
    (tester) async {
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap30FirstLaunchGuidePreferences:
              FakeCap30FirstLaunchGuidePreferences()..step = 0,
        ),
      );
      await tester.pumpAndSettle();

      final tokens = Theme.of(
        tester.element(find.byKey(const Key('cap30VerticalHintGuide'))),
      ).extension<WakeTokTokens>()!;

      final title1 = _styleOf(
        tester,
        find.byKey(const Key('cap30VerticalHintGuideTitle')),
      )?.fontSize;
      expect(title1, tokens.titleChrome.fontSize);
      _expectNotLabelOnMedia(title1, tokens);

      await tester.pump(kCap30VerticalHintGuideDuration);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap30CreatePoolTipMessage')), findsOneWidget);
      final tipSize = _styleOf(
        tester,
        find.byKey(const Key('cap30CreatePoolTipMessage')),
      )?.fontSize;
      expect(tipSize, tokens.bodyOnMedia.fontSize);
      _expectNotLabelOnMedia(tipSize, tokens);
    },
  );

  testWidgets(
    'T-30.6-C6 zh Browse redirect + Settings safety on master',
    (tester) async {
      const zh = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
      final l10n = await AppLocalizations.delegate.load(zh);
      await tester.pumpWidget(
        permissionUiHarness(
          locale: zh,
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: FakeCap19LeftSwipePreferences()
            ..leftSwipeAddEnabled = true
            ..leftSwipeGuideEnabled = true,
          cap30FirstLaunchGuidePreferences:
              FakeCap30FirstLaunchGuidePreferences()..step = 3,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('cap19LeftSwipeGuideSubtitle'))).data,
        '可在设置中关闭此功能和提示',
      );

      await tester.tap(find.text(l10n.mainBrowseNavSettings));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
          matching: find.text(l10n.cap19SettingsLeftSwipeAddSubtitle),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('cap19SettingsLeftSwipeAddInfo')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.cap19SettingsLeftSwipeAddSubtitle), findsOneWidget);
      expect(
        l10n.cap19SettingsLeftSwipeAddSubtitle,
        '保存到 WakeTok 相册，当作稍后在「照片」里查找或操作的标记 — 不会移动或删除原文件',
      );
    },
  );
}
