import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/anchored_info_bubble.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../library_smoke/fake_new_round_toast_preferences.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

TextStyle? _styleOf(WidgetTester tester, Finder finder) {
  return tester.widget<Text>(finder).style;
}

Future<void> _openSettings(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavSettings));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('W-31.1-bubble-core open / barrier dismiss / body swallow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: waketokTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('probeOpen'),
                  onPressed: () {
                    showAnchoredInfoBubble(
                      context: context,
                      message: 'Probe note',
                      anchorOverlayRect: const Rect.fromLTWH(160, 400, 44, 44),
                      bubbleKey: const Key('probeBubble'),
                      barrierKey: const Key('probeBarrier'),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('probeOpen')));
    await tester.pump();
    expect(find.byKey(const Key('probeBubble')), findsOneWidget);
    expect(find.byKey(const Key('probeBarrier')), findsOneWidget);

    // Tap bubble body — must not dismiss.
    await tester.tap(find.byKey(const Key('probeBubble')));
    await tester.pump();
    expect(find.byKey(const Key('probeBubble')), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    expect(find.byKey(const Key('probeBubble')), findsNothing);
  });

  testWidgets('W-31.1-bubble-place prefers above when space allows',
      (tester) async {
    late AnchoredInfoBubbleHandle handle;
    await tester.pumpWidget(
      MaterialApp(
        theme: waketokTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('probePlace'),
                  onPressed: () {
                    handle = showAnchoredInfoBubble(
                      context: context,
                      message: 'Above preferred',
                      // Low on screen → lots of space above.
                      anchorOverlayRect:
                          const Rect.fromLTWH(160, 520, 44, 44),
                      bubbleKey: const Key('placeBubble'),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('probePlace')));
    await tester.pump();

    final bubble = tester.getRect(find.byKey(const Key('placeBubble')));
    // Anchor top at 520; bubble bottom should sit above it.
    expect(bubble.bottom, lessThan(520));
    handle.dismiss();
    await tester.pump();
  });

  testWidgets('W-31.1-settings-info left-swipe safety only in bubble',
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
    await _openSettings(tester);

    final addToggle = find.byKey(const Key('cap19SettingsLeftSwipeAddToggle'));
    expect(addToggle, findsOneWidget);
    expect(
      find.descendant(
        of: addToggle,
        matching: find.text(l10n.cap19SettingsLeftSwipeAddSubtitle),
      ),
      findsNothing,
    );
    expect(find.byKey(const Key('cap19SettingsLeftSwipeAddInfo')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('cap19SettingsLeftSwipeAddInfo')));
    await tester.tap(find.byKey(const Key('cap19SettingsLeftSwipeAddInfo')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('cap19SettingsLeftSwipeAddInfoBubble')),
      findsOneWidget,
    );
    expect(find.text(l10n.cap19SettingsLeftSwipeAddSubtitle), findsOneWidget);
  });

  testWidgets('W-31.1-settings-info starting-over full copy only in bubble',
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
        newRoundToastPreferences: FakeNewRoundToastPreferences(),
        cap30FirstLaunchGuidePreferences:
            FakeCap30FirstLaunchGuidePreferences()..step = 3,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);

    final toggle = find.byKey(const Key('browseSettingsNewRoundToastToggle'));
    await tester.ensureVisible(toggle);
    expect(
      find.descendant(
        of: toggle,
        matching: find.text(l10n.browseSettingsNewRoundToastSubtitle),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: toggle,
        matching: find.text(l10n.browseSettingsNewRoundToastInfo),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('browseSettingsNewRoundToastInfo')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('browseSettingsNewRoundToastInfoBubble')),
      findsOneWidget,
    );
    expect(find.text(l10n.browseSettingsNewRoundToastInfo), findsOneWidget);
  });

  testWidgets('W-31.1-settings-info guide + meta copy only in bubble',
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
    await _openSettings(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('cap19SettingsLeftSwipeGuideToggle')),
        matching: find.text(l10n.cap19SettingsLeftSwipeGuideSubtitle),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('browseDisplayShowMetaOverlayToggle')),
        matching: find.text(l10n.browseDisplayMetaOverlaySubtitle),
      ),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(const Key('cap19SettingsLeftSwipeGuideInfo')),
    );
    await tester.tap(find.byKey(const Key('cap19SettingsLeftSwipeGuideInfo')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.cap19SettingsLeftSwipeGuideSubtitle), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('browseDisplayMetaOverlayInfo')),
    );
    await tester.tap(find.byKey(const Key('browseDisplayMetaOverlayInfo')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.browseDisplayMetaOverlaySubtitle), findsOneWidget);
  });

  testWidgets('W-31.1-info-hug title→i gap is constant across rows',
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
        newRoundToastPreferences: FakeNewRoundToastPreferences(),
        cap30FirstLaunchGuidePreferences:
            FakeCap30FirstLaunchGuidePreferences()..step = 3,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);

    double gapAfterTitle(Key rowKey, String title, Key infoKey) {
      final textFinder = find.descendant(
        of: find.byKey(rowKey),
        matching: find.byType(Text),
      );
      final paragraph =
          tester.renderObject<RenderParagraph>(textFinder.first);
      // Boxes for the title TextSpan only (exclude WidgetSpan replacement).
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: title.length),
      );
      expect(boxes, isNotEmpty);
      final origin = paragraph.localToGlobal(Offset.zero);
      final titleRight = origin.dx + boxes.last.right;
      final infoLeft = tester.getTopLeft(find.byKey(infoKey)).dx;
      return infoLeft - titleRight;
    }

    final gaps = <double>[
      gapAfterTitle(
        const Key('cap19SettingsLeftSwipeAddToggle'),
        l10n.cap19SettingsLeftSwipeAddTitle,
        const Key('cap19SettingsLeftSwipeAddInfo'),
      ),
      gapAfterTitle(
        const Key('cap19SettingsLeftSwipeGuideToggle'),
        l10n.cap19SettingsLeftSwipeGuideTitle,
        const Key('cap19SettingsLeftSwipeGuideInfo'),
      ),
      gapAfterTitle(
        const Key('browseDisplayShowMetaOverlayToggle'),
        l10n.browseDisplayMetaOverlayTitle,
        const Key('browseDisplayMetaOverlayInfo'),
      ),
      gapAfterTitle(
        const Key('browseSettingsNewRoundToastToggle'),
        l10n.browseSettingsNewRoundToastTitle,
        const Key('browseSettingsNewRoundToastInfo'),
      ),
    ];

    // WidgetSpan padding = kSettingsTitleInfoGap; allow 1px raster slack.
    for (final g in gaps) {
      expect(g, closeTo(kSettingsTitleInfoGap, 1.0));
    }
    // All rows share the same gap (not “short title close / long title far”).
    final spread = gaps.reduce((a, b) => a > b ? a : b) -
        gaps.reduce((a, b) => a < b ? a : b);
    expect(spread, lessThan(1.0));
  });

  testWidgets('W-31.1-hierarchy same size; row bold, section regular',
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
    await _openSettings(tester);

    final sectionStyle = _styleOf(
      tester,
      find.text('${l10n.cap19SettingsGesturesSectionTitle}:'),
    );
    final rowText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
        matching: find.byType(Text),
      ).first,
    );
    final rowStyle = rowText.style ??
        rowText.textSpan?.style ??
        settingsRowTitleStyle(
          Theme.of(
            tester.element(
              find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
            ),
          ).extension<WakeTokTokens>()!,
        );
    expect(sectionStyle!.fontSize, kSettingsChromeTitleFontSize);
    expect(rowStyle!.fontSize, kSettingsChromeTitleFontSize);
    expect(sectionStyle.fontWeight, FontWeight.w400);
    expect(rowStyle.fontWeight, FontWeight.w600);
    expect(sectionStyle.color, isNot(waketokTheme(Brightness.light)
        .extension<WakeTokTokens>()!
        .accent));
  });

  testWidgets('W-31.1-gestures row layout gap tracks kSettingsRowGap',
      (tester) async {
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
    await _openSettings(tester);

    final add = tester.getRect(
      find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
    );
    final guide = tester.getRect(
      find.byKey(const Key('cap19SettingsLeftSwipeGuideToggle')),
    );
    // Layout gap between row boxes; switch keeps intrinsic ~31 height.
    expect(guide.top - add.bottom, closeTo(kSettingsRowGap, 1.0));
    expect(add.height, greaterThanOrEqualTo(30));
    expect(guide.height, greaterThanOrEqualTo(30));
    // Switches must not overlap (figure-8 regression).
    expect(guide.top, greaterThanOrEqualTo(add.bottom));
  });

  testWidgets('W-31.1-photos Access uses row chrome for label and status',
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
        cap30FirstLaunchGuidePreferences:
            FakeCap30FirstLaunchGuidePreferences()..step = 3,
      ),
    );
    await tester.pumpAndSettle();
    await _openSettings(tester);

    final label = tester.widget<Text>(
      find.text(l10n.photosAccessSettingsSectionTitle),
    );
    final status = tester.widget<Text>(
      find.text(l10n.photosAccessFullStatusMessage),
    );
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(label.style!.fontSize, kSettingsChromeTitleFontSize);
    expect(status.style!.fontWeight, FontWeight.w600);
    expect(status.style!.fontSize, kSettingsChromeTitleFontSize);
    expect(status.style!.color!.a, closeTo(1.0, 0.01));
  });

  testWidgets('W-31.1-theme-tokens bubble colors follow Brightness',
      (tester) async {
    Future<Color?> pumpBubble(Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: waketokTheme(brightness),
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    key: const Key('themeProbe'),
                    onPressed: () {
                      showAnchoredInfoBubble(
                        context: context,
                        message: 'Theme probe',
                        anchorOverlayRect:
                            const Rect.fromLTWH(120, 300, 44, 44),
                        bubbleKey: const Key('themeBubble'),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('themeProbe')));
      await tester.pump();
      final material = tester.widget<Material>(
        find.byKey(const Key('themeBubble')),
      );
      final color = material.color;
      // Dismiss for next brightness.
      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      return color;
    }

    final light = await pumpBubble(Brightness.light);
    final dark = await pumpBubble(Brightness.dark);
    final lightTokens = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final darkTokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
    expect(
      light,
      lightTokens.surface.withValues(alpha: kAnchoredInfoBubbleSurfaceAlpha),
    );
    expect(
      dark,
      darkTokens.surface.withValues(alpha: kAnchoredInfoBubbleSurfaceAlpha),
    );
    expect(light, isNot(dark));
  });
}
