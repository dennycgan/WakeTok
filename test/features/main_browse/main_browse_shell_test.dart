import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
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

  testWidgets('W-2 top chrome shows All/Photos/Videos and disabled Pools',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('mainBrowseSourceAll')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseSourcePhotos')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseSourceVideos')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseSourcePools')), findsOneWidget);
    expect(find.text(l10n.mainBrowsePoolsComingSoon), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('mainBrowseSourcePools')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    // Still on browse feed — Pools does not become a selected source.
    expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
  });

  testWidgets('W-3 bottom nav stubs switch destinations', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('mainBrowseNavigationBar')), findsOneWidget);

    await tester.tap(find.text(l10n.mainBrowseNavClips));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mainBrowseStubClipsBody), findsOneWidget);

    await tester.tap(find.text(l10n.mainBrowseNavAuto));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mainBrowseStubAutoBody), findsOneWidget);

    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mainBrowseStubSettingsBody), findsOneWidget);

    await tester.tap(find.text(l10n.mainBrowseNavBrowse));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
  });

  testWidgets('W-4 limited keeps banner on Main Browse', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsOneWidget);
  });

  testWidgets('W-5 top selected source uses dark accent (immersive)',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    TextStyle styleOf(String label) {
      return tester.widget<Text>(find.text(label)).style!;
    }

    // Browse is forced-dark — compare against dark accent, not light.
    expect(styleOf(l10n.libraryRowAll).color, darkTokens.accent);

    await tester.tap(find.byKey(const Key('mainBrowseSourcePhotos')));
    await tester.pumpAndSettle();
    expect(styleOf(l10n.libraryRowPhotos).color, darkTokens.accent);
    expect(
      styleOf(l10n.libraryRowAll).color,
      isNot(darkTokens.accent),
    );
  });

  testWidgets('W-7 selected bottom destination uses accent indicator tint',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, themeMode: ThemeMode.light),
    );
    await tester.pumpAndSettle();

    final indicator = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      return decoration is BoxDecoration &&
          decoration.color == darkTokens.accent.withValues(alpha: 0.20);
    });
    expect(indicator, isNotEmpty);
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
    expect(find.text(l10n.mainBrowseNavClips), findsOneWidget);
    expect(find.text(l10n.mainBrowseNavAuto), findsOneWidget);
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
    expect(find.byKey(const Key('mainBrowseSourceAll')), findsOneWidget);
  });

  testWidgets('W-6 debug Settings opens library_smoke', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();

    if (kDebugMode) {
      expect(
        find.byKey(const Key('mainBrowseOpenLibrarySmokeDebug')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('mainBrowseOpenLibrarySmokeDebug')));
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
