import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/authorization/permission_blocked_page.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_library_catalog_repository.dart';
import 'permission_ui_test_harness.dart';

void main() {
  testWidgets('W1 notDetermined shows request page', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionRequestPage), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.permissionRequestContinue), findsOneWidget);
  });

  testWidgets('W2 Continue calls requestAccess and lands on shell',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.permissionRequestContinue));
    await tester.pumpAndSettle();

    expect(repo.requestCalls, 1);
    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsNothing);
  });

  testWidgets('W3 denied shows blocked page with Open Settings', (tester) async {
    var opened = false;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.denied);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        openSettings: () async {
          opened = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PermissionBlockedPage), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.permissionBlockedTitleDenied), findsOneWidget);
    await tester.tap(find.text(l10n.permissionOpenSettings));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('W4 restricted uses restricted title on same blocked page',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.restricted);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionBlockedPage), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.permissionBlockedTitleRestricted), findsOneWidget);
  });

  testWidgets(
      'W5 limited shell + banner; picker then resume stays on shell',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsOneWidget);
    expect(find.byType(PermissionRequestPage), findsNothing);
    expect(find.byType(PermissionBlockedPage), findsNothing);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.limitedAccessManageSelection));
    await tester.pumpAndSettle();
    expect(repo.presentCalls, 1);

    // Simulate return from system picker / foregrounding.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsOneWidget);
    expect(find.byType(PermissionRequestPage), findsNothing);
    expect(find.byType(PermissionBlockedPage), findsNothing);
  });

  testWidgets(
      'W5b manage selection dismissal refreshes library totals',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 3, photos: 2, videos: 1),
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, catalog: catalog),
    );
    await tester.pumpAndSettle();
    expect(catalog.totalsCalls, greaterThanOrEqualTo(1));
    final callsAfterOpen = catalog.totalsCalls;

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    catalog.totalsValue = const LibraryTotals(all: 5, photos: 4, videos: 1);
    await tester.tap(find.text(l10n.limitedAccessManageSelection));
    await tester.pumpAndSettle();

    expect(catalog.totalsCalls, greaterThan(callsAfterOpen));
    expect(find.text('5'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('W6 full shows shell without banner', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsNothing);
  });

  testWidgets('W7 zh_Hans shows request copy', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    );
    expect(find.text(l10n.permissionRequestTitle), findsOneWidget);
    expect(find.text(l10n.permissionRequestContinue), findsOneWidget);
  });

  testWidgets('W8 shell shows library totals from catalog', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 12, photos: 10, videos: 2),
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, catalog: catalog),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.countsPending), findsNothing);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('W8b empty library may show real zeros', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 0, photos: 0, videos: 0),
    );
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, catalog: catalog),
    );
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(3));
  });

  testWidgets('W9 resume refresh can move shell to blocked', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);

    repo.status = PhotosAccess.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(PermissionBlockedPage), findsOneWidget);
    expect(find.byType(LibraryTotalsShellPage), findsNothing);
  });

  testWidgets('W9b resume from Settings can leave blocked for full',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.denied);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionBlockedPage), findsOneWidget);

    repo.status = PhotosAccess.full;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    expect(find.byType(PermissionBlockedPage), findsNothing);
  });
}
