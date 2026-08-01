import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/main.dart';

import '../../features/authorization/permission_ui_test_harness.dart';

void main() {
  test('T1 light and dark ThemeData carry WakeTokTokens', () {
    final light = waketokTheme(Brightness.light);
    final dark = waketokTheme(Brightness.dark);

    expect(light.extension<WakeTokTokens>(), isNotNull);
    expect(dark.extension<WakeTokTokens>(), isNotNull);
    expect(
      light.extension<WakeTokTokens>(),
      isNot(same(dark.extension<WakeTokTokens>())),
    );
  });

  test('T2 modes differ except feedBackground (same black)', () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.background, isNot(dark.background));
    expect(light.surface, isNot(dark.surface));
    expect(light.onSurface, isNot(dark.onSurface));
    expect(light.accentProvisional, isNot(dark.accentProvisional));
    expect(light.feedBackground, dark.feedBackground);
    expect(light.feedBackground, const Color(0xFF000000));
  });

  test('T3 ThemeData wiring uses tokens', () {
    final lightTheme = waketokTheme(Brightness.light);
    final darkTheme = waketokTheme(Brightness.dark);
    final light = lightTheme.extension<WakeTokTokens>()!;
    final dark = darkTheme.extension<WakeTokTokens>()!;

    expect(lightTheme.scaffoldBackgroundColor, light.background);
    expect(darkTheme.scaffoldBackgroundColor, dark.background);
    expect(lightTheme.colorScheme.primary, light.accentProvisional);
    expect(darkTheme.colorScheme.primary, dark.accentProvisional);
    expect(lightTheme.appBarTheme.backgroundColor, light.surface);
    expect(darkTheme.appBarTheme.backgroundColor, dark.surface);
  });

  testWidgets('T4 app resolves light tokens under light platform brightness',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosAuthorizationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const WakeTokApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    final expected = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    expect(theme.scaffoldBackgroundColor, expected.background);
    expect(theme.extension<WakeTokTokens>()!.surface, expected.surface);
  });

  testWidgets('T5 app resolves dark tokens under dark platform brightness',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosAuthorizationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const WakeTokApp(),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold));
    final theme = Theme.of(context);
    final expected = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
    expect(theme.scaffoldBackgroundColor, expected.background);
    expect(theme.extension<WakeTokTokens>()!.surface, expected.surface);
  });
}
