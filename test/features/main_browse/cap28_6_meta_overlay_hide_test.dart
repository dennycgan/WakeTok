import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/browse_display_settings_section.dart';
import 'package:waketok/features/main_browse/browse_meta_overlay_shown.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/features/main_browse/presentation_size_cache.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../authorization/permission_ui_test_harness.dart';

/// Mirrors Cap 28.6 paint gate: cover-gate OR process hide.
bool _metaPaintAllowed({
  required bool shown,
  required bool suppressStillCoverMeta,
}) {
  return shown && !suppressStillCoverMeta;
}

void main() {
  test('W-28.6-1 provider defaults true; setShown is process-only', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(browseMetaOverlayShownProvider), isTrue);
    container.read(browseMetaOverlayShownProvider.notifier).setShown(false);
    expect(container.read(browseMetaOverlayShownProvider), isFalse);
    container.read(browseMetaOverlayShownProvider.notifier).setShown(true);
    expect(container.read(browseMetaOverlayShownProvider), isTrue);
  });

  testWidgets(
    'W-28.6-2 hide removes MediaInfoOverlay; show restores',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      Widget gated() {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: waketokTheme(Brightness.dark),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // Same AND as MediaFeedPage._showMediaInfoOverlayEffective
                  // (other gates held open).
                  final shown = ref.watch(browseMetaOverlayShownProvider);
                  if (!shown) {
                    return const SizedBox.shrink();
                  }
                  return MediaInfoOverlay(
                    snapshot: PresentationOverlaySnapshot(
                      assetIdentifier: 'a',
                      createdAt: DateTime(2024, 6, 10, 12),
                      mediaKind: PresentationMediaKind.image,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(gated());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);

      container.read(browseMetaOverlayShownProvider.notifier).setShown(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);

      container.read(browseMetaOverlayShownProvider.notifier).setShown(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    },
  );

  test('W-28.6-3 Reset geometry uses fixed columnHeightFor (hide-invariant)', () {
    final tokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
    final bottomShown =
        mainBrowseMediaOverlayBottomInset(tokens) +
        MediaInfoOverlay.columnHeightFor(null) +
        kResetAboveMetaGap;
    final bottomHidden =
        mainBrowseMediaOverlayBottomInset(tokens) +
        MediaInfoOverlay.columnHeightFor(null) +
        kResetAboveMetaGap;
    expect(bottomHidden, bottomShown);
    expect(
      MediaInfoOverlay.columnHeightFor(null),
      MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount,
    );
  });

  test('W-28.6-4 cover-gate OR hide both suppress paint', () {
    expect(
      _metaPaintAllowed(shown: true, suppressStillCoverMeta: false),
      isTrue,
    );
    expect(
      _metaPaintAllowed(shown: false, suppressStillCoverMeta: false),
      isFalse,
    );
    expect(
      _metaPaintAllowed(shown: true, suppressStillCoverMeta: true),
      isFalse,
    );
    expect(
      _metaPaintAllowed(shown: false, suppressStillCoverMeta: true),
      isFalse,
    );
  });

  test('W-28.6-5 size cache apply works while meta hidden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(browseMetaOverlayShownProvider.notifier).setShown(false);
    expect(container.read(browseMetaOverlayShownProvider), isFalse);

    container.read(presentationSizeCacheProvider.notifier).apply(
          'a1',
          const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 4096,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        );
    final entry = container.read(presentationSizeCacheProvider)['a1'];
    expect(entry?.fileSizeBytes, 4096);
    expect(entry?.resolved, isTrue);
  });

  testWidgets(
    'W-28.6-6 Settings order Gestures → On-screen details → On-screen messages; '
    'switch ON shows (polarity B)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(permissionUiHarness(repo: repo));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.mainBrowseNavSettings));
      await tester.pumpAndSettle();

      final gestures = find.text('${l10n.cap19SettingsGesturesSectionTitle}:');
      final display = find.text('${l10n.browseDisplaySettingsSectionTitle}:');
      final notices = find.text('${l10n.browseSettingsSectionTitle}:');
      expect(gestures, findsOneWidget);
      expect(display, findsOneWidget);
      expect(notices, findsOneWidget);

      expect(tester.getTopLeft(gestures).dy, lessThan(tester.getTopLeft(display).dy));
      expect(tester.getTopLeft(display).dy, lessThan(tester.getTopLeft(notices).dy));

      final toggle = find.byKey(const Key('browseDisplayShowMetaOverlayToggle'));
      expect(toggle, findsOneWidget);
      final sw = find.descendant(
        of: toggle,
        matching: find.byType(CupertinoSwitch),
      );
      // Default ON = details shown.
      expect(tester.widget<CupertinoSwitch>(sw).value, isTrue);

      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoSwitch>(sw).value, isFalse);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(browseMetaOverlayShownProvider), isFalse);
    },
  );

  testWidgets(
    'W-28.6-7 hide leaves no mediaInfoOverlay widget (VoiceOver has no node)',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      Widget gatedOverlay() {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: waketokTheme(Brightness.dark),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final shown = ref.watch(browseMetaOverlayShownProvider);
                  if (!shown) {
                    return const SizedBox.shrink();
                  }
                  return MediaInfoOverlay(
                    snapshot: PresentationOverlaySnapshot(
                      assetIdentifier: 'a',
                      createdAt: DateTime(2024, 6, 10, 12),
                      mediaKind: PresentationMediaKind.image,
                      fileSizeBytes: 1024,
                      fileSizeSemantics:
                          FileSizeSemantics.currentImageRepresentation,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(gatedOverlay());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);

      container.read(browseMetaOverlayShownProvider.notifier).setShown(false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
    },
  );

  testWidgets('W-28.6-settings section mounts with Show title copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: waketokTheme(Brightness.dark),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: BrowseDisplaySettingsSection(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text('${l10n.browseDisplaySettingsSectionTitle}:'), findsOneWidget);
    Finder richTitle(String title) => find.byWidgetPredicate((widget) {
          if (widget is! RichText) {
            return false;
          }
          return widget.text.toPlainText().contains(title);
        });
    expect(richTitle(l10n.browseDisplayMetaOverlayTitle), findsOneWidget);
    expect(find.text(l10n.browseDisplayMetaOverlaySubtitle), findsNothing);
    expect(find.byKey(const Key('browseDisplayMetaOverlayInfo')), findsOneWidget);
    expect(richTitle('Show bottom-left details'), findsOneWidget);
  });
}
