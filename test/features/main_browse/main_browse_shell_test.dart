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

    await tester.tap(find.byKey(const Key('mainBrowseSourcePools')));
    await tester.pumpAndSettle();
    // Still on browse placeholder — Pools does not become a selected source.
    expect(find.byKey(const Key('mainBrowseFeedPlaceholder')), findsOneWidget);
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
    expect(find.byKey(const Key('mainBrowseFeedPlaceholder')), findsOneWidget);
  });

  testWidgets('W-4 limited keeps banner on Main Browse', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsOneWidget);
  });

  testWidgets('W-5 top selected source uses accentProvisional token color',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final tokens =
        waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    TextStyle styleOf(String label) {
      return tester.widget<Text>(find.text(label)).style!;
    }

    expect(styleOf(l10n.libraryRowAll).color, tokens.accentProvisional);

    await tester.tap(find.byKey(const Key('mainBrowseSourcePhotos')));
    await tester.pumpAndSettle();
    expect(styleOf(l10n.libraryRowPhotos).color, tokens.accentProvisional);
    expect(
      styleOf(l10n.libraryRowAll).color,
      isNot(tokens.accentProvisional),
    );
  });

  testWidgets('W-7 NavigationBar indicatorColor is explicit token tint',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final tokens =
        waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final bar = tester.widget<NavigationBar>(
      find.byKey(const Key('mainBrowseNavigationBar')),
    );
    expect(
      bar.indicatorColor,
      tokens.accentProvisional.withValues(alpha: 0.20),
    );
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
