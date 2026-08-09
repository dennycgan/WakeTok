import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/main.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';

import '../../features/authorization/permission_ui_test_harness.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_library_catalog_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';

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

  test('T2 modes differ except feedBackground / on-media scrim family', () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.background, isNot(dark.background));
    expect(light.surface, isNot(dark.surface));
    expect(light.onSurface, isNot(dark.onSurface));
    expect(light.accent, isNot(dark.accent));
    expect(light.brandGold, dark.brandGold);
    expect(light.feedBackground, dark.feedBackground);
    expect(light.feedBackground, const Color(0xFF000000));
    expect(light.mediaScrim, dark.mediaScrim);
    expect(light.onMedia, dark.onMedia);
    expect(light.onMediaMuted, dark.onMediaMuted);
  });

  test('T3 ThemeData wiring uses tokens', () {
    final lightTheme = waketokTheme(Brightness.light);
    final darkTheme = waketokTheme(Brightness.dark);
    final light = lightTheme.extension<WakeTokTokens>()!;
    final dark = darkTheme.extension<WakeTokTokens>()!;

    expect(lightTheme.scaffoldBackgroundColor, light.background);
    expect(darkTheme.scaffoldBackgroundColor, dark.background);
    expect(lightTheme.colorScheme.primary, light.accent);
    expect(darkTheme.colorScheme.primary, dark.accent);
    expect(lightTheme.appBarTheme.backgroundColor, light.surface);
    expect(darkTheme.appBarTheme.backgroundColor, dark.surface);
  });

  test('T-typo-1 L/D typography sizes match; chrome colors follow onSurface',
      () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.titleChrome.fontSize, dark.titleChrome.fontSize);
    expect(light.labelChrome.fontSize, dark.labelChrome.fontSize);
    expect(light.bodyChrome.fontSize, dark.bodyChrome.fontSize);
    expect(light.labelOnMedia.fontSize, dark.labelOnMedia.fontSize);
    expect(light.bodyOnMedia.fontSize, dark.bodyOnMedia.fontSize);

    expect(light.titleChrome.color, light.onSurface);
    expect(dark.titleChrome.color, dark.onSurface);
    expect(light.labelOnMedia.color, light.onMedia);
    expect(dark.labelOnMedia.color, dark.onMedia);
  });

  test('T-typo-2 textTheme slots map from chrome / on-media tokens', () {
    final theme = waketokTheme(Brightness.light);
    final tokens = theme.extension<WakeTokTokens>()!;

    // ThemeData merges TextTheme onto Material defaults (family/debugLabel),
    // so assert semantic fields — not full TextStyle equality.
    void expectMaps(TextStyle? actual, TextStyle expected) {
      expect(actual?.color, expected.color);
      expect(actual?.fontSize, expected.fontSize);
      expect(actual?.fontWeight, expected.fontWeight);
      expect(actual?.height, expected.height);
    }

    expectMaps(theme.textTheme.titleMedium, tokens.titleChrome);
    expectMaps(theme.textTheme.labelLarge, tokens.labelChrome);
    expectMaps(theme.textTheme.bodyMedium, tokens.bodyChrome);
    expectMaps(theme.textTheme.labelSmall, tokens.labelOnMedia);
    expectMaps(theme.textTheme.bodySmall, tokens.bodyOnMedia);
    expectMaps(theme.appBarTheme.titleTextStyle, tokens.titleChrome);
  });

  test('T-scrim-1 mediaScrim and onMedia tokens present (L==D)', () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.mediaScrim.a, greaterThan(0));
    expect(light.onMedia, const Color(0xFFFFFFFF));
    expect(light.mediaScrim, dark.mediaScrim);
    expect(light.onMedia, dark.onMedia);
    expect(light.onMediaMuted, dark.onMediaMuted);
  });

  test('T-adr016 onMediaLabelShadows and bar height (L==D)', () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.immersiveBottomBarHeight, 48);
    expect(dark.immersiveBottomBarHeight, 48);
    expect(light.onMediaLabelShadows, dark.onMediaLabelShadows);
    expect(light.onMediaLabelShadows, hasLength(1));
    expect(
      light.onMediaLabelShadows.single.color,
      const Color(0x8A000000),
    );
    expect(light.onMediaLabelShadows.single.blurRadius, 6);
    expect(light.onMediaLabelShadows.single.offset, const Offset(0, 1));
  });

  test('T-accent frozen hex Light #FC2555 Dark #FF6B8A', () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.accent, const Color(0xFFFC2555));
    expect(dark.accent, const Color(0xFFFF6B8A));
    expect(light.accent, isNot(dark.accent));
  });

  test('T-brandGold Light equals Dark #E0C590', () {
    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;

    expect(light.brandGold, const Color(0xFFE0C590));
    expect(dark.brandGold, const Color(0xFFE0C590));
    expect(light.brandGold, dark.brandGold);
  });

  testWidgets(
      'T4 light ambient: Browse content dark; Settings pane light; bar always dark',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosAuthorizationRepositoryProvider.overrideWithValue(repo),
          libraryCatalogRepositoryProvider.overrideWithValue(
            FakeLibraryCatalogRepository(),
          ),
          assetSourceRepositoryProvider.overrideWithValue(
            FakeAssetSourceRepository(),
          ),
          mediaDisplayRepositoryProvider.overrideWithValue(
            FakeMediaDisplayRepository(),
          ),
          playbackRepositoryProvider.overrideWithValue(FakePlaybackRepository()),
          presentationMetadataRepositoryProvider.overrideWithValue(
            FakePresentationMetadataRepository(),
          ),
        ],
        child: const WakeTokApp(),
      ),
    );
    await tester.pumpAndSettle();

    final light = waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    final dark = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    Scaffold scaffoldOf() => tester.widget<Scaffold>(
          find.descendant(
            of: find.byType(MainBrowseShellPage),
            matching: find.byType(Scaffold),
          ),
        );
    Material barOf() => tester.widget<Material>(
          find.byKey(const Key('mainBrowseNavigationBar')),
        );

    // Browse: scaffold dark; bar dark.
    expect(scaffoldOf().backgroundColor, dark.background);
    expect(barOf().color, dark.surface);

    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();

    // Settings pane follows Light; bottom bar stays dark.
    expect(scaffoldOf().backgroundColor, light.background);
    expect(barOf().color, dark.surface);
    final settingsContext = tester.element(find.text(l10n.mainBrowseStubSettingsBody));
    expect(
      Theme.of(settingsContext).extension<WakeTokTokens>()!.surface,
      light.surface,
    );
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
          libraryCatalogRepositoryProvider.overrideWithValue(
            FakeLibraryCatalogRepository(),
          ),
          assetSourceRepositoryProvider.overrideWithValue(
            FakeAssetSourceRepository(),
          ),
          mediaDisplayRepositoryProvider.overrideWithValue(
            FakeMediaDisplayRepository(),
          ),
          playbackRepositoryProvider.overrideWithValue(FakePlaybackRepository()),
          presentationMetadataRepositoryProvider.overrideWithValue(
            FakePresentationMetadataRepository(),
          ),
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
    expect(theme.textTheme.titleMedium?.fontSize, expected.titleChrome.fontSize);
  });
}
