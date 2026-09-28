import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/features/main_browse/build_pool_scaffold_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

const _regionKey = Key('mainBrowseStatusBarStyle');

/// First status query never completes, so the gate stays on its loading
/// scaffold (no AppBar, no shell).
class _PendingAuthorizationRepository implements PhotosAuthorizationRepository {
  final _status = Completer<PhotosAccess>();

  @override
  Future<PhotosAccess> currentStatus() => _status.future;

  @override
  Future<PhotosAccess> requestAccess() => _status.future;

  @override
  Future<void> presentLimitedLibraryPicker() async {}
}

Widget _harness(
  ThemeMode themeMode, {
  PhotosAuthorizationRepository? repo,
}) {
  return permissionUiHarness(
    repo: repo ?? ControllablePhotosAuthorizationRepository(PhotosAccess.full),
    themeMode: themeMode,
    assetSources: FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById:
          FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
    ),
    cap30FirstLaunchGuidePreferences: FakeCap30FirstLaunchGuidePreferences()
      ..step = 3,
  );
}

SystemUiOverlayStyle _declared(WidgetTester tester) {
  return tester
      .widget<AnnotatedRegion<SystemUiOverlayStyle>>(find.byKey(_regionKey))
      .value;
}

Future<void> _openSettings(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavSettings));
  await tester.pumpAndSettle();
}

Future<void> _openBrowse(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavBrowse));
  await tester.pumpAndSettle();
}

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('W-31.4-statusbar-browse light icons under ${mode.name}',
        (tester) async {
      await tester.pumpWidget(_harness(mode));
      await tester.pumpAndSettle();

      expect(_declared(tester), SystemUiOverlayStyle.light);
      expect(SystemChrome.latestStyle, SystemUiOverlayStyle.light);
    });
  }

  for (final (mode, expected) in [
    (ThemeMode.light, SystemUiOverlayStyle.dark),
    (ThemeMode.dark, SystemUiOverlayStyle.light),
  ]) {
    testWidgets('W-31.4-statusbar-settings follows Appearance (${mode.name})',
        (tester) async {
      await tester.pumpWidget(_harness(mode));
      await tester.pumpAndSettle();
      await _openSettings(tester);

      expect(_declared(tester), expected);
      expect(SystemChrome.latestStyle, expected);
    });
  }

  for (final (mode, expected, stale) in [
    (ThemeMode.light, SystemUiOverlayStyle.dark, SystemUiOverlayStyle.light),
    (ThemeMode.dark, SystemUiOverlayStyle.light, SystemUiOverlayStyle.dark),
  ]) {
    testWidgets(
        'W-31.4-statusbar-loading baseline replaces a leftover style '
        '(${mode.name})', (tester) async {
      // Guards the mechanism only: the root baseline must replace a style
      // left behind by an earlier surface on a route that declares none. No
      // user path reaches this: the gate loading page shows only at cold
      // start, before any other surface. MaterialApp re-sends its theme
      // default only when the theme changes, so the leftover is injected
      // after the app has built.
      await tester.pumpWidget(
        _harness(mode, repo: _PendingAuthorizationRepository()),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(_regionKey), findsNothing);

      SystemChrome.setSystemUIOverlayStyle(stale);
      await tester.pump();
      await tester.pump();

      expect(SystemChrome.latestStyle, expected);
    });
  }

  testWidgets('W-31.4-statusbar-nested shell region overrides root baseline',
      (tester) async {
    await tester.pumpWidget(_harness(ThemeMode.light));
    await tester.pumpAndSettle();

    final regions = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .map((r) => r.value)
        .toList();
    // Root baseline (Light → dark icons) sits above the shell (Browse → light).
    expect(regions.first, SystemUiOverlayStyle.dark);
    expect(_declared(tester), SystemUiOverlayStyle.light);
    expect(SystemChrome.latestStyle, SystemUiOverlayStyle.light);
  });

  testWidgets(
      'W-31.4-statusbar-sticky Build Pool style does not stick after pop '
      '(Light)', (tester) async {
    await tester.pumpWidget(_harness(ThemeMode.light));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mainBrowseCreatePool')));
    await tester.pumpAndSettle();
    expect(find.byKey(BuildPoolScaffoldPage.pageKey), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle, SystemUiOverlayStyle.light);

    await _openSettings(tester);
    expect(SystemChrome.latestStyle, SystemUiOverlayStyle.dark);

    await _openBrowse(tester);
    expect(SystemChrome.latestStyle, SystemUiOverlayStyle.light);
  });
}
