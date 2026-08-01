import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../features/authorization/permission_ui_test_harness.dart';

void main() {
  testWidgets('T7 forced zh_Hans shows permission request copy', (tester) async {
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
    expect(find.byType(PermissionRequestPage), findsOneWidget);
    expect(find.text(l10n.permissionRequestTitle), findsOneWidget);
    expect(find.text(l10n.permissionRequestContinue), findsOneWidget);
  });

  testWidgets('T8 forced en shows permission request copy', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.permissionRequestTitle), findsOneWidget);
    expect(find.text(l10n.permissionRequestContinue), findsOneWidget);
  });

  testWidgets('WakeTokApp builds through ProviderScope harness', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionRequestPage), findsOneWidget);
  });
}
