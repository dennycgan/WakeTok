import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/authorization/photos_access_settings_section.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../authorization/permission_ui_test_harness.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();
  }

  testWidgets('W-29.2-1 Limited Settings: Photos Access + Manage + Open Settings',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    var openSettingsCalls = 0;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        openSettings: () async {
          openSettingsCalls += 1;
        },
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('photosAccessSettingsSection')), findsOneWidget);
    expect(find.text(l10n.photosAccessSettingsSectionTitle), findsOneWidget);
    expect(find.text(l10n.limitedAccessBannerMessage), findsOneWidget);
    expect(find.byKey(const Key('photosAccessManageSelection')), findsOneWidget);
    expect(find.byKey(const Key('photosAccessOpenSettings')), findsOneWidget);
    // Product Settings must not mount LimitedAccessBanner type
    // (shell W-4 / permission_ui W2·W6 — not permission_ui W4).
    expect(find.byType(LimitedAccessBanner), findsNothing);

    await tester.tap(find.byKey(const Key('photosAccessManageSelection')));
    await tester.pumpAndSettle();
    expect(repo.presentCalls, 1);

    await tester.tap(find.byKey(const Key('photosAccessOpenSettings')));
    await tester.pumpAndSettle();
    expect(openSettingsCalls, 1);
  });

  testWidgets('W-29.2-2 Full Settings: status + Open Settings; no Manage',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    var openSettingsCalls = 0;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        openSettings: () async {
          openSettingsCalls += 1;
        },
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byKey(const Key('photosAccessSettingsSection')), findsOneWidget);
    expect(find.text(l10n.photosAccessFullStatusMessage), findsOneWidget);
    expect(find.byKey(const Key('photosAccessManageSelection')), findsNothing);
    expect(find.text(l10n.limitedAccessManageSelection), findsNothing);

    await tester.tap(find.byKey(const Key('photosAccessOpenSettings')));
    await tester.pumpAndSettle();
    expect(openSettingsCalls, 1);
    expect(repo.presentCalls, 0);
  });

  testWidgets('W-29.2-3 Photos Access precedes Gestures in Settings ListView',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();
    await openSettings(tester);

    final photos = tester.getTopLeft(
      find.byKey(const Key('photosAccessSettingsSection')),
    );
    final gestures = tester.getTopLeft(
      find.byKey(const Key('cap19GesturesSettingsSection')),
    );
    expect(photos.dy, lessThan(gestures.dy));
  });

  testWidgets('W-29.2-4 Browse destination has no Photos Access section painted',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    // IndexedStack offstage Settings — default finders skip offstage.
    expect(find.byKey(const Key('photosAccessSettingsSection')), findsNothing);
    expect(find.byKey(const Key('photosAccessManageSelection')), findsNothing);
  });
}
