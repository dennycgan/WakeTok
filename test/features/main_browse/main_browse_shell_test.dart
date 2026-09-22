import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/features/main_browse/bottom_tab_layout.dart';
import 'package:waketok/features/main_browse/browse_card_stack_icon.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../authorization/permission_ui_test_harness.dart';

void main() {
  final darkTokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
  final lightTokens = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;

  testWidgets('W-1 full lands on MainBrowseShellPage not library_smoke',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    expect(find.byType(LibraryTotalsShellPage), findsNothing);
  });

  testWidgets('W-2 top chrome shows Built-in/Saved/Create', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseBuiltInMenu')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseSavedPoolsMenu')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseCreatePool')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);
    expect(find.byKey(const Key('mainBrowseSourcePools')), findsNothing);
    expect(find.byKey(const Key('mainBrowseChromeCenterPair')), findsOneWidget);
  });

  testWidgets('W-3 bottom nav: Browse | Order | Settings; order opens sheet',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('mainBrowseNavigationBar')), findsOneWidget);
    expect(find.text('Clips'), findsNothing);
    expect(find.text('Auto'), findsNothing);
    expect(find.byKey(const Key('mainBrowseOrderActionSlot')), findsOneWidget);
    expect(find.text(l10n.mainBrowseOrderShuffle), findsOneWidget);

    await tester.tap(find.byKey(const Key('mainBrowseOrderActionSlot')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orderControlHalfSheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('orderControlCancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orderControlHalfSheet')), findsNothing);

    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();
    expect(find.text(l10n.cap19SettingsGesturesSectionTitle), findsOneWidget);

    await tester.tap(find.text(l10n.mainBrowseNavBrowse));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
  });

  testWidgets('W-4 limited has no banner on any main destination',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byType(MainBrowseShellPage), findsOneWidget);

    Future<void> expectNoBannerOn(String navLabel) async {
      await tester.tap(find.text(navLabel));
      await tester.pumpAndSettle();
      expect(find.byType(LimitedAccessBanner), findsNothing);
    }

    // Default destination is Browse — assert before switching.
    expect(find.byType(LimitedAccessBanner), findsNothing);
    await expectNoBannerOn(l10n.mainBrowseNavSettings);
    await expectNoBannerOn(l10n.mainBrowseNavBrowse);
  });

  testWidgets('W-5 top selected built-in uses dark accent (immersive)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    TextStyle styleOf(Finder finder) {
      return tester.widget<Text>(finder).style!;
    }

    final builtInLabel = find.descendant(
      of: find.byKey(const Key('mainBrowseBuiltInMenu')),
      matching: find.byType(Text),
    );
    // Browse is forced-dark — compare against dark accent, not light.
    expect(styleOf(builtInLabel).color, darkTokens.accent);
    expect(styleOf(builtInLabel).color, isNot(lightTokens.accent));

    await tester.tap(find.byKey(const Key('mainBrowseBuiltInMenu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mainBrowseBuiltInOptionPhotos')));
    await tester.pumpAndSettle();
    expect(styleOf(builtInLabel).color, darkTokens.accent);
    expect(find.text(l10n.libraryRowPhotos), findsWidgets);
  });

  testWidgets('W-7 selected bottom destination uses accent color only (no fill)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final browseGlyph = tester.widget<BrowseCardStackIcon>(
      find.byKey(const Key('mainBrowseNavBrowseGlyph')),
    );
    expect(browseGlyph.filled, isTrue);
    expect(browseGlyph.color, darkTokens.accent);

    final browseLabel = tester.widget<Text>(find.text(l10n.mainBrowseNavBrowse));
    expect(browseLabel.style?.color, darkTokens.accent);

    // No destination selected fill capsule (re-lock 2026-09-20).
    final fillCapsules = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration &&
          decoration.color ==
              darkTokens.accent.withValues(alpha: 0.20);
    });
    expect(fillCapsules, isEmpty);
  });

  testWidgets(
      'W-27.6-nav: §11.4 — Browse B peek+front, Action no shell, color-only selected',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.byKey(const Key('mainBrowseNavBrowseGlyph')), findsOneWidget);
    expect(find.byType(BrowseCardStackIcon), findsOneWidget);
    expect(find.byType(OrderSwapIcon), findsOneWidget);
    final nav = find.byKey(const Key('mainBrowseNavigationBar'));
    expect(
      find.descendant(of: nav, matching: find.byIcon(Icons.home)),
      findsNothing,
    );
    expect(
      find.descendant(of: nav, matching: find.byIcon(Icons.home_outlined)),
      findsNothing,
    );
    expect(
      find.descendant(of: nav, matching: find.byIcon(Icons.swap_vert)),
      findsNothing,
    );

    // Slots share 32 geometry; Action has no DecoratedBox shell.
    expect(find.byKey(const Key('mainBrowseOrderActionShell')), findsNothing);
    Size slotSize(Key key) => tester.getSize(find.byKey(key));
    expect(
      slotSize(const Key('mainBrowseNavBrowseSlot')),
      const Size(kBottomTabIconSlot, kBottomTabIconSlot),
    );
    expect(
      slotSize(const Key('mainBrowseOrderActionIconSlot')),
      const Size(kBottomTabIconSlot, kBottomTabIconSlot),
    );
    expect(
      slotSize(const Key('mainBrowseNavSettingsSlot')),
      const Size(kBottomTabIconSlot, kBottomTabIconSlot),
    );

    // Selected Browse: filled + accent (color only).
    final browseSelected = tester.widget<BrowseCardStackIcon>(
      find.byKey(const Key('mainBrowseNavBrowseGlyph')),
    );
    expect(browseSelected.filled, isTrue);
    expect(browseSelected.color, darkTokens.accent);

    // Switch to Settings — Browse outlined muted; Settings accent; Order unchanged.
    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();

    final browseAfter = tester.widget<BrowseCardStackIcon>(
      find.byKey(const Key('mainBrowseNavBrowseGlyph')),
    );
    expect(browseAfter.filled, isFalse);
    expect(browseAfter.color, darkTokens.onMediaMuted);

    final settingsIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('mainBrowseNavSettingsSlot')),
        matching: find.byIcon(Icons.settings),
      ),
    );
    expect(settingsIcon.color, darkTokens.accent);
    expect(settingsIcon.size, kBottomTabIconSize);

    expect(find.byType(OrderSwapIcon), findsOneWidget);
    expect(
      tester.widget<OrderSwapIcon>(find.byType(OrderSwapIcon)).color,
      darkTokens.onMediaMuted,
    );

    // Stroke constants: Action thinner than Browse outlined (§11.4.4 / R-GLYPH).
    expect(kBottomTabActionSwapStroke, lessThan(kBottomTabBrowseOutlinedStroke));
  });

  testWidgets(
      'W-27.6-nav-label: Order/Browse label band — no vertical FittedBox scale',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    // SE width — long order copy + chevron (COPY-1 class).
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final orderSlot = find.byKey(const Key('mainBrowseOrderActionSlot'));
    final orderFitted = find.descendant(
      of: orderSlot,
      matching: find.byType(FittedBox),
    );
    expect(orderFitted, findsOneWidget);

    final fitted = tester.renderObject(orderFitted) as RenderFittedBox;
    final childSize = fitted.child!.size;
    final parentSize = fitted.size;
    // Width-only scaleDown: height must stay 1.0 (no 12/14 vertical squash).
    final sy = parentSize.height / childSize.height;
    final sx = parentSize.width / childSize.width;
    final fitScale = () {
      final s = sx < sy ? sx : sy;
      return s > 1 ? 1.0 : s;
    }();
    expect(
      fitScale,
      closeTo(1.0, 0.001),
      reason:
          'Order FittedBox must not vertically squash the label row '
          '(was ~0.857 when Row+chevron shared one FittedBox). '
          'parent=$parentSize child=$childSize',
    );
    expect(childSize.height, closeTo(kBottomTabLabelBandHeight, 0.5));
    expect(parentSize.height, closeTo(kBottomTabLabelBandHeight, 0.5));

    final expand = find.descendant(
      of: orderSlot,
      matching: find.byIcon(Icons.expand_less),
    );
    expect(tester.getSize(expand).height, kBottomTabExpandIconSize);

    final browseLabel = tester.getSize(find.text('Browse'));
    final settingsLabel = tester.getSize(find.text('Settings'));
    final orderLabel = tester.getSize(
      find
          .descendant(of: orderSlot, matching: find.byType(Text))
          .first,
    );
    expect(browseLabel.height, closeTo(kBottomTabLabelBandHeight, 0.5));
    expect(settingsLabel.height, closeTo(kBottomTabLabelBandHeight, 0.5));
    expect(orderLabel.height, closeTo(browseLabel.height, 0.5));
    expect(orderLabel.height, closeTo(settingsLabel.height, 0.5));
  });

  testWidgets(
      'W-8 bottom bar always dark; Settings pane follows light ambient',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    Material barOf() => tester.widget<Material>(
          find.byKey(const Key('mainBrowseNavigationBar')),
        );
    Scaffold scaffoldOf() => tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(MainBrowseShellPage),
            matching: find.byType(Scaffold),
          ),
        );

    expect(barOf().color, darkTokens.surface);
    expect(scaffoldOf().backgroundColor, darkTokens.background);

    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();
    // Bar stays dark; Settings content follows Light Appearance.
    expect(barOf().color, darkTokens.surface);
    expect(scaffoldOf().backgroundColor, lightTokens.background);
    // Unselected destinations must remain visible (not onMediaMuted-on-white).
    expect(find.text(l10n.mainBrowseNavBrowse), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseOrderActionSlot')), findsOneWidget);
    expect(find.text(l10n.mainBrowseNavSettings), findsWidgets);

    await tester.tap(find.text(l10n.mainBrowseNavBrowse));
    await tester.pumpAndSettle();
    expect(barOf().color, darkTokens.surface);
    expect(scaffoldOf().backgroundColor, darkTokens.background);
  });

  testWidgets('W-9 top chrome Material is transparent (no scrim band)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find.byKey(const Key('mainBrowseTopSourceChrome')),
    );
    expect(material.color, Colors.transparent);
    expect(material.color, isNot(darkTokens.mediaScrim));
    expect(material.color, isNot(darkTokens.surface));
    expect(material.color, isNot(lightTokens.surface));
  });

  testWidgets('W-11 bottom bar content height matches immersiveBottomBarHeight',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final content = tester.widget<SizedBox>(
      find.byKey(const Key('mainBrowseNavigationBarContent')),
    );
    expect(content.height, darkTokens.immersiveBottomBarHeight);
    expect(content.height, 48);
  });

  testWidgets(
      'W-27.6-pad: zero safe-area adds 6pt under content; notched keeps 0',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);

    Future<void> pumpWithBottomInset(double bottom) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: EdgeInsets.only(bottom: bottom),
            viewPadding: EdgeInsets.only(bottom: bottom),
          ),
          child: permissionUiHarness(repo: repo),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpWithBottomInset(0);
    expect(
      find.byKey(const Key('mainBrowseNavigationBarContentBottomPad')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(const Key('mainBrowseNavigationBarContentBottomPad')),
          )
          .height,
      kBottomTabContentBottomPadWhenNoSafeArea,
    );
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(const Key('mainBrowseNavigationBarContent')),
          )
          .height,
      48,
    );

    await pumpWithBottomInset(34);
    expect(
      find.byKey(const Key('mainBrowseNavigationBarContentBottomPad')),
      findsNothing,
    );
    expect(
      tester
          .widget<SizedBox>(
            find.byKey(const Key('mainBrowseNavigationBarContent')),
          )
          .height,
      48,
    );
  });

  testWidgets('W-10 Browse pane is Stack with feed and top chrome',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseBrowsePane')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('mainBrowseBrowsePane'))),
      isA<Stack>(),
    );
    expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseTopSourceChrome')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseBuiltInMenu')), findsOneWidget);
  });

  testWidgets('W-6 debug Settings opens library_smoke', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();

    if (kDebugMode) {
      final smokeDebug = find.byKey(const Key('mainBrowseOpenLibrarySmokeDebug'));
      await tester.dragUntilVisible(
        smokeDebug,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(smokeDebug, findsOneWidget);
      await tester.tap(smokeDebug);
      await tester.pumpAndSettle();
      expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    } else {
      expect(
        find.byKey(const Key('mainBrowseOpenLibrarySmokeDebug')),
        findsNothing,
      );
    }
  });
}
