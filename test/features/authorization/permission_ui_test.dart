import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/authorization/permission_blocked_page.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

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
    await tester.pumpAndSettle();

    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);
    expect(find.byType(LimitedAccessBanner), findsOneWidget);
    expect(find.byType(PermissionRequestPage), findsNothing);
    expect(find.byType(PermissionBlockedPage), findsNothing);
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

  testWidgets('W8 shell uses countsPending not fake zeros', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.countsPending), findsNWidgets(3));
    expect(find.text('0'), findsNothing);
  });

  testWidgets('W9 resume refresh can move shell to blocked', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();
    expect(find.byType(LibraryTotalsShellPage), findsOneWidget);

    repo.status = PhotosAccess.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(PermissionBlockedPage), findsOneWidget);
    expect(find.byType(LibraryTotalsShellPage), findsNothing);
  });
}
