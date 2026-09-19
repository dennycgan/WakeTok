import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/features/main_browse/magnification_surface.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

import 'package:waketok/features/library_smoke/playback_providers.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_new_round_toast_preferences.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

const _feedZeroEmptyRetries = [Duration.zero, Duration.zero, Duration.zero];

/// Advances async work without waiting for indeterminate preparing spinners.
Future<void> pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Finder _mediaFeedPage(String assetIdentifier) {
  return find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.assetIdentifier == assetIdentifier,
    skipOffstage: false,
  );
}

MediaFeedPageState _mediaFeedPageState(
  WidgetTester tester,
  String assetIdentifier,
) {
  return tester.state<MediaFeedPageState>(_mediaFeedPage(assetIdentifier));
}

/// Sync elapsed past ADR-034 G still-a2 suppress-below-T in widget tests.
///
/// [tester.pump(duration)] advances FakeAsync Timers but not [DateTime.now],
/// which production G uses for in-flight elapsed. Mirror device wall clock
/// via the page test seam (same pattern as W-14.6b-L2).
Future<void> revealLayer2WaitChromeForTest(
  WidgetTester tester,
  String assetIdentifier, {
  Duration elapsed = kDefaultA4SuppressBelow,
}) async {
  final page = _mediaFeedPageState(tester, assetIdentifier);
  page.debugInFlightElapsedOverride = elapsed;
  tester.element(_mediaFeedPage(assetIdentifier)).markNeedsBuild();
  await tester.pump();
}

/// ADR-034 F1 Live-prepare suppress-below-T uses a reveal Timer (fake-async safe).
Future<void> pumpPastLivePreparingSuppress(WidgetTester tester) async {
  await tester.pump(kDefaultA4SuppressBelow);
  await tester.pump();
}

/// Cap 21.3: Built-in sources live in a dropdown — open menu then pick.
Future<void> selectBuiltInSource(
  WidgetTester tester,
  SourceReference source,
) async {
  final Key optionKey;
  if (source == SourceReference.all) {
    optionKey = const Key('mainBrowseBuiltInOptionAll');
  } else if (source == SourceReference.photos) {
    optionKey = const Key('mainBrowseBuiltInOptionPhotos');
  } else if (source == SourceReference.videos) {
    optionKey = const Key('mainBrowseBuiltInOptionVideos');
  } else {
    throw ArgumentError('not a built-in: $source');
  }
  await tester.tap(find.byKey(const Key('mainBrowseBuiltInMenu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(optionKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('W-F1 full lands on VerticalMediaFeed not placeholder', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MainBrowseShellPage), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeed')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPlaceholder')), findsNothing);
    expect(find.byType(VerticalMediaFeed), findsOneWidget);
  });

  testWidgets('W-F2 PageView builds for resolved ids', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    expect(sources.resolveCalls, greaterThan(0));
    expect(find.byType(PageView), findsOneWidget);
    // Random(0) Shuffle on [a,b,c] → [c,b,a] (Cap 13.4 product default).
    expect(find.byKey(const Key('mainBrowseFeedStill_c')), findsOneWidget);
  });

  testWidgets(
    'W-14.6c still letterbox shell + Image.fill fitted box (not viewport stretch)',
    (tester) async {
      // Cap 20: StillFittedMagnificationShell sizes a contain-formula box from
      // DisplayAsset pixel dims; Image uses BoxFit.fill only to fill that box.
      // Asserting Image.fit==contain alone is the wrong layer (debt 451).
      //
      // Production Host always writes pixelWidth/Height on DisplayAssetDto
      // (PHAsset dims on L2; decoded UIImage on preview). Dart fields stay
      // nullable (Pigeon optional). Shell treats null OR <=0 as
      // fitted=viewport — then fill WOULD stretch. PHAsset can report 0 /
      // wrong dims (iCloud / incomplete metadata); that path is debt **452**
      // (Open at Cap 20.6 docs) — not “impossible”. This test pins the
      // healthy path (positive dims → letterbox aspect) so removing the
      // shell or feeding viewport-sized fill fails red.
      const assetW = 200;
      const assetH = 100;
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displaysById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_14_6c.jpg',
        pixelWidth: assetW,
        pixelHeight: assetH,
      );
      display.previewsById['a1'] = display.displaysById['a1']!;

      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();

      final boxFinder = find.byKey(const Key('stillMagnificationContentBox'));
      expect(boxFinder, findsOneWidget);
      final boxSize = tester.getSize(boxFinder);
      expect(boxSize.width, greaterThan(0));
      expect(boxSize.height, greaterThan(0));
      expect(
        boxSize.width / boxSize.height,
        closeTo(assetW / assetH, 0.02),
        reason: 'content box must match asset aspect (outer contain math)',
      );

      final viewport = tester.getSize(find.byType(PageView));
      expect(
        boxSize.width < viewport.width - 1 ||
            boxSize.height < viewport.height - 1,
        isTrue,
        reason:
            'letterbox: fitted box must be smaller than viewport on an axis',
      );

      final images = tester.widgetList<Image>(
        find.descendant(of: boxFinder, matching: find.byType(Image)),
      );
      expect(images, isNotEmpty);
      for (final image in images) {
        expect(
          image.fit,
          BoxFit.fill,
          reason: 'Image fills the already-letterboxed SizedBox only',
        );
      }
    },
  );

  testWidgets(
    'W-15.5a L1→L2 reuses Image State with gaplessPlayback and no path key',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.previewsById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_15_5_l1.jpg',
      );
      display.displaysById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_15_5_l2.jpg',
      );
      display.displayGates['a1'] = Completer<void>();

      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);

      final still = find.byKey(const Key('mainBrowseFeedStill_a1'));
      expect(still, findsOneWidget);
      final imageFinder = find.descendant(
        of: still,
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);

      final imageL1 = tester.widget<Image>(imageFinder);
      expect(imageL1.gaplessPlayback, isTrue);
      expect(imageL1.key, isNull);
      expect(imageL1.image, isA<ResizeImage>());
      final resizeL1 = imageL1.image! as ResizeImage;
      expect(resizeL1.width, isNotNull);
      expect(resizeL1.height, isNotNull);
      expect(resizeL1.policy, ResizeImagePolicy.fit);
      expect(resizeL1.allowUpscaling, isFalse);
      final stateL1 = (tester.element(imageFinder) as StatefulElement).state;

      display.displayGates['a1']!.complete();
      await pumpAsyncWork(tester);

      expect(imageFinder, findsOneWidget);
      final imageL2 = tester.widget<Image>(imageFinder);
      expect(imageL2.gaplessPlayback, isTrue);
      expect(imageL2.key, isNull);
      expect(imageL2.image, isA<ResizeImage>());
      final resizeL2 = imageL2.image! as ResizeImage;
      expect(resizeL2.width, isNotNull);
      expect(resizeL2.height, isNotNull);
      expect(resizeL2.policy, ResizeImagePolicy.fit);
      expect(resizeL2.allowUpscaling, isFalse);
      expect(resizeL2.imageProvider, isA<FileImage>());
      expect(
        (resizeL2.imageProvider as FileImage).file.path,
        '/tmp/waketok_15_5_l2.jpg',
      );
      final stateL2 = (tester.element(imageFinder) as StatefulElement).state;
      expect(
        identical(stateL1, stateL2),
        isTrue,
        reason: 'L1→L2 path swap must reuse Image State (gapless)',
      );
    },
  );

  testWidgets('W-15.5b broken JPEG hits errorBuilder after gapless change', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    // Path need not resolve: invoke Image.errorBuilder directly (FileImage
    // decode is unreliable under widget tests). Same closure as production.
    const broken = DisplayAsset(
      assetIdentifier: 'a1',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/waketok_15_5b_unused.jpg',
    );
    display.previewsById['a1'] = broken;
    display.displaysById['a1'] = broken;
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
      ),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);

    final imageFinder = find.descendant(
      of: find.byKey(const Key('mainBrowseFeedStill_a1')),
      matching: find.byType(Image),
    );
    expect(imageFinder, findsOneWidget);
    final image = tester.widget<Image>(imageFinder);
    expect(image.gaplessPlayback, isTrue);
    expect(image.key, isNull);
    expect(image.errorBuilder, isNotNull);
    expect(image.image, isA<ResizeImage>());
    expect((image.image! as ResizeImage).policy, ResizeImagePolicy.fit);

    final placeholder = image.errorBuilder!(
      tester.element(imageFinder),
      Exception('forced decode failure'),
      StackTrace.current,
    );
    expect(
      placeholder,
      isA<ColoredBox>(),
      reason: 'errorBuilder must return the broken-file placeholder',
    );
    expect(
      (placeholder as ColoredBox).key,
      const Key('mainBrowseFeedStillBrokenPlaceholder'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'W-15.5c still Image cache size matches LayoutBuilder box × DPR',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.previewsById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_15_5c.jpg',
      );
      display.displaysById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_15_5c.jpg',
      );

      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);

      final imageFinder = find.descendant(
        of: find.byKey(const Key('mainBrowseFeedStill_a1')),
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final image = tester.widget<Image>(imageFinder);
      expect(image.image, isA<ResizeImage>());
      final resize = image.image! as ResizeImage;

      // Pin fit policy: Image.file cache* defaults to exact and stretches.
      expect(resize.policy, ResizeImagePolicy.fit);
      expect(resize.allowUpscaling, isFalse);

      final box = tester.renderObject<RenderBox>(imageFinder);
      final dpr = tester.view.devicePixelRatio;
      expect(resize.width, (box.size.width * dpr).round());
      expect(resize.height, (box.size.height * dpr).round());
      expect(resize.width, greaterThan(0));
      expect(resize.height, greaterThan(0));
    },
  );

  testWidgets('W-F3 empty resolve shows empty ARB', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedEmpty), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
  });

  testWidgets(
    'W-14.6a successful empty stays on loading until a later resolve has ids',
    (tester) async {
      final firstHold = Completer<void>();
      final secondHold = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(
        allIdsForCall: (i) => i == 0 ? const <String>[] : const ['a', 'b', 'c'],
        beforeEachResolve: (i) async {
          if (i == 0) {
            await firstHold.future;
          } else if (i == 1) {
            await secondHold.future;
          }
        },
      );
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: sources,
          browseEmptyRetryDelays: _feedZeroEmptyRetries,
        ),
      );
      await pumpAsyncWork(tester);
      expect(find.byKey(const Key('mainBrowseFeedLoading')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsNothing);

      firstHold.complete();
      await pumpAsyncWork(tester);
      expect(find.byKey(const Key('mainBrowseFeedLoading')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsNothing);

      secondHold.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_c')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsNothing);
    },
  );

  testWidgets('W-14.6b four empty resolves then empty copy, not failed panel', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseEmptyRetryDelays: _feedZeroEmptyRetries,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedEmpty), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedResolveFailed')), findsNothing);
    expect(sources.resolveCalls, 4);
  });

  testWidgets('W-F4 resolve failure shows error ARB and retry', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = _ThrowingResolveRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedResolveFailed), findsOneWidget);
    expect(
      find.byKey(const Key('mainBrowseFeedResolveFailed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mainBrowseFeedRetry')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
  });

  testWidgets('W-F4b unauthorized mapped failure shows retry, not empty copy', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      resolveException: PlatformException(code: AppError.unauthorized.name),
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedResolveFailed), findsOneWidget);
    expect(
      find.byKey(const Key('mainBrowseFeedResolveFailed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mainBrowseFeedRetry')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsNothing);
    expect(find.text(l10n.mainBrowseFeedEmpty), findsNothing);
  });

  testWidgets('W-F5 page change updates feed index via PageController', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();

    expect(container.read(mainBrowseFeedIndexProvider), 1);
    expect(find.byKey(const Key('mainBrowseFeedStill_b')), findsOneWidget);
  });

  testWidgets('W-F6 switching Photos calls resolve for photos and resets', (
    tester,
  ) async {
    // First visit to Photos — always a host resolve (cache miss).
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['all-1', 'all-2'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final callsBefore = sources.resolveCalls;
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await selectBuiltInSource(tester, SourceReference.photos);
    await tester.pumpAndSettle();

    expect(sources.resolveCalls, greaterThan(callsBefore));
    expect(sources.lastResolve, SourceReference.photos);
    expect(find.byKey(const Key('mainBrowseFeedStill_ph-1')), findsOneWidget);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    expect(container.read(mainBrowseFeedIndexProvider), 0);
  });

  testWidgets('W-S1 All→Photos→All resolves each source once (session cache)', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['all-1'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await selectBuiltInSource(tester, SourceReference.photos);
    await tester.pumpAndSettle();
    await selectBuiltInSource(tester, SourceReference.all);
    await tester.pumpAndSettle();

    expect(
      sources.resolveHistory.where((r) => r == SourceReference.all).length,
      1,
    );
    expect(
      sources.resolveHistory.where((r) => r == SourceReference.photos).length,
      1,
    );
    expect(sources.resolveCalls, 2);
    expect(find.byKey(const Key('mainBrowseFeedStill_all-1')), findsOneWidget);
  });

  testWidgets(
    'W-S1b empty All is not cached; Photos then All re-resolves ids',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(
        allIds: const [],
        photosIds: const ['ph-1'],
      );
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: sources,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsOneWidget);

      sources.allIds = const ['all-1'];
      await selectBuiltInSource(tester, SourceReference.photos);
      await tester.pumpAndSettle();
      await selectBuiltInSource(tester, SourceReference.all);
      await tester.pumpAndSettle();

      expect(
        sources.resolveHistory.where((r) => r == SourceReference.all).length,
        2,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedStill_all-1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseFeedEmpty')), findsNothing);
    },
  );

  testWidgets('W-S2 cache-hit source switch still resets feed index to 0', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
    await tester.pumpAndSettle();
    expect(container.read(mainBrowseFeedIndexProvider), 2);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await selectBuiltInSource(tester, SourceReference.photos);
    await tester.pumpAndSettle();
    expect(container.read(mainBrowseFeedIndexProvider), 0);

    await selectBuiltInSource(tester, SourceReference.all);
    await tester.pumpAndSettle();
    expect(container.read(mainBrowseFeedIndexProvider), 0);
    // New Session on revisit; Random(0) again → head is still 'c'.
    expect(find.byKey(const Key('mainBrowseFeedStill_c')), findsOneWidget);
    expect(
      sources.resolveHistory.where((r) => r == SourceReference.all).length,
      1,
    );
  });

  testWidgets('W-S3 Photos resolve is independent of All (not Dart filter)', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['shared', 'all-only'],
      photosIds: const ['ph-only'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await selectBuiltInSource(tester, SourceReference.photos);
    await tester.pumpAndSettle();

    expect(sources.lastResolve, SourceReference.photos);
    expect(
      find.byKey(const Key('mainBrowseFeedStill_ph-only')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_all-only')), findsNothing);
    expect(find.byKey(const Key('mainBrowseFeedStill_shared')), findsNothing);
  });

  testWidgets('W-S4 retry after failure resolves again then caches success', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = _FailThenSucceedRepository(
      allIds: const ['a1'],
      failTimes: 1,
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.mainBrowseFeedResolveFailed), findsOneWidget);
    expect(sources.resolveCalls, 1);

    await tester.tap(find.byKey(const Key('mainBrowseFeedRetry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(sources.resolveCalls, 2);

    await selectBuiltInSource(tester, SourceReference.photos);
    await tester.pumpAndSettle();
    await selectBuiltInSource(tester, SourceReference.all);
    await tester.pumpAndSettle();

    // All success was cached — no third resolve for All.
    expect(
      sources.resolveHistory.where((r) => r == SourceReference.all).length,
      2,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
  });

  testWidgets('W-F7 stale display for index N discarded after jump toward N+2', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    // Random(0) Shuffle on [n, mid, n2] → [n2, mid, n]. Gate the head (n2);
    // jump to index 2 (image n); completing the head gate must not paint Live.
    final gateHead = Completer<void>();
    display.displayGates['n2'] = gateHead;
    display.displaysById['n'] = const DisplayAsset(
      assetIdentifier: 'n',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/n.jpg',
    );
    display.displaysById['mid'] = const DisplayAsset(
      assetIdentifier: 'mid',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/mid.jpg',
    );
    display.displaysById['n2'] = const DisplayAsset(
      assetIdentifier: 'n2',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/n2.jpg',
    );

    final sources = FakeAssetSourceRepository(allIds: const ['n', 'mid', 'n2']);

    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        mediaDisplay: display,
      ),
    );
    // Resolve + start gated display for current page (shuffled head = n2).
    await tester.pump();
    await tester.pump();
    expect(display.displayCalls, contains('n2'));

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
    await tester.pump();
    await tester.pump();

    gateHead.complete();
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedStill_n')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsNothing);
    expect(container.read(mainBrowseFeedIndexProvider), 2);
  });

  testWidgets('W-F8 switching source pauses playback (no audio leak)', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final playback = FakePlaybackRepository();
    final sources = FakeAssetSourceRepository(
      allIds: const ['all-1'],
      photosIds: const ['ph-1'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();

    playback.calls.clear();
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await selectBuiltInSource(tester, SourceReference.photos);
    await tester.pumpAndSettle();

    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
  });

  testWidgets('W-F8b leave video for still pauses playback (no audio leak)', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    // All: unsupportedMedia → video path for v1; still is a normal image.
    display.displayErrorById['v1'] = 'unsupportedMedia';
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'still']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);

    playback.calls.clear();
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mainBrowseFeedStill_still')), findsOneWidget);
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
    expect(
      playback.calls.where((c) => c == 'cancelInFlightPrepare:v1'),
      isNotEmpty,
    );
  });

  testWidgets(
    'W-F8c leave video for iCloud-only pauses playback (no audio leak)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final playback = FakePlaybackRepository();
      final display = FakeMediaDisplayRepository();
      display.displayErrorById['v1'] = 'unsupportedMedia';
      display.displayErrorById['cloud'] = 'iCloudDownloadFailed';
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['v1', 'cloud'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['v1', 'cloud'],
            ),
          ),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);

      playback.calls.clear();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('mainBrowseFeedStill_cloud')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedLayer2Retry')),
        findsOneWidget,
      );
      expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
      expect(
        playback.calls.where((c) => c == 'cancelInFlightPrepare:v1'),
        isNotEmpty,
      );
    },
  );

  testWidgets('W-16.2 leave Browse (Settings) cancels in-flight prepare', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['v1'] = 'unsupportedMedia';
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);

    playback.calls.clear();
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container
        .read(mainBrowseDestinationProvider.notifier)
        .select(MainBrowseDestination.settings);
    await tester.pump();

    expect(
      playback.calls.where((c) => c == 'cancelInFlightPrepare:v1'),
      isNotEmpty,
    );
  });

  test('U-1 Videos source skips display and goes playable', () async {
    final display = FakeMediaDisplayRepository();
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();

    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.displayCalls, isEmpty);
    expect(display.playableCalls, isEmpty);
    expect(playback.calls, ['setPlaybackPlan:feed-v1-0', 'load:v1']);
    expect(media?.kind, FeedPageMediaKind.video);
  });

  test('U-1-pending off-current Videos does not touch playable', () async {
    final display = FakeMediaDisplayRepository();
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();

    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 1,
      isCurrent: false,
      layer1: null,
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.playableCalls, isEmpty);
    expect(playback.calls, isEmpty);
    expect(media?.kind, FeedPageMediaKind.pendingVideo);
  });

  test('U-1b All unsupportedMedia falls through to video', () async {
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['vid'] = 'unsupportedMedia';
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();

    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.entireLibrary,
      assetIdentifier: 'vid',
      feedIndex: 1,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.displayCalls, ['vid']);
    expect(display.playableCalls, isEmpty);
    expect(playback.calls, ['setPlaybackPlan:feed-vid-1', 'load:vid']);
    expect(media?.kind, FeedPageMediaKind.video);
  });

  test('U-1c All Layer1 video poster skips requestDisplayAsset', () async {
    final display = FakeMediaDisplayRepository();
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();
    final playback = FakePlaybackRepository();
    const poster = DisplayAsset(
      assetIdentifier: 'vid',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: '/tmp/fake_preview_vid.jpg',
    );

    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: generation,
      sourceKind: AssetSourceKind.entireLibrary,
      assetIdentifier: 'vid',
      feedIndex: 1,
      isCurrent: true,
      layer1: FeedPageMedia.still(poster, layer: FeedDisplayLayer.preview),
      displayRepository: display,
      playbackRepository: playback,
    );

    expect(display.displayCalls, isEmpty);
    expect(display.playableCalls, isEmpty);
    expect(playback.calls, ['setPlaybackPlan:feed-vid-1', 'load:vid']);
    expect(media?.kind, FeedPageMediaKind.video);
    expect(media?.display, poster);
  });

  test('U-16.3a load iCloudDownloadFailed maps to download fail', () async {
    final playback = FakePlaybackRepository();
    playback.loadErrorById['v1'] = 'iCloudDownloadFailed';
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: gate.begin(),
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: FakeMediaDisplayRepository(),
      playbackRepository: playback,
    );
    expect(media?.kind, FeedPageMediaKind.failed);
    expect(media?.failureReason, FeedFailureReason.download);
  });

  test('U-16.3b load operationCancelled is null not failed', () async {
    final playback = FakePlaybackRepository();
    playback.loadErrorById['v1'] = 'operationCancelled';
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: gate.begin(),
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: FakeMediaDisplayRepository(),
      playbackRepository: playback,
    );
    expect(media, isNull);
  });

  test('U-16.3c load assetUnavailable maps to assetUnavailable fail', () async {
    final playback = FakePlaybackRepository();
    playback.loadErrorById['v1'] = 'assetUnavailable';
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: gate.begin(),
      sourceKind: AssetSourceKind.mediaTypeVideos,
      assetIdentifier: 'v1',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: FakeMediaDisplayRepository(),
      playbackRepository: playback,
    );
    expect(media?.kind, FeedPageMediaKind.failed);
    expect(media?.failureReason, FeedFailureReason.assetUnavailable);
  });

  test('U-16.3d clearPlaybackPool completes in-flight load', () async {
    final playback = FakePlaybackRepository();
    playback.loadGates['v1'] = Completer<void>();
    final item = PlaybackItem(
      assetIdentifier: 'v1',
      feedIndex: 0,
      mediaKind: PlaybackMediaKind.video,
    );
    final pending = playback.load(item);
    final completed = expectLater(
      pending,
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'operationCancelled',
        ),
      ),
    );
    await playback.clearPlaybackPool();
    await completed;
  });

  testWidgets('W-16.4a still Layer 2 waits 300 ms dwell', (tester) async {
    final display = FakeMediaDisplayRepository();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
        browseLayer2Dwell: const Duration(milliseconds: 300),
      ),
    );
    final ids = await pumpUntilFeedIds(tester);
    expect(display.displayCalls, isEmpty);
    await tester.pump(const Duration(milliseconds: 299));
    expect(display.displayCalls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(display.displayCalls, [ids[0]]);
  });

  testWidgets('W-16.4b video load waits 300 ms dwell', (tester) async {
    final display = FakeMediaDisplayRepository();
    display.previewsById['v1'] = const DisplayAsset(
      assetIdentifier: 'v1',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: '/tmp/fake_preview_v1.jpg',
    );
    final playback = FakePlaybackRepository();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1']),
        mediaDisplay: display,
        playback: playback,
        browseLayer2Dwell: const Duration(milliseconds: 300),
      ),
    );
    await pumpUntilFeedIds(tester);
    expect(playback.calls.where((c) => c.startsWith('load:')), isEmpty);
    await tester.pump(const Duration(milliseconds: 299));
    expect(playback.calls.where((c) => c.startsWith('load:')), isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(playback.calls, contains('load:v1'));
  });

  testWidgets('W-16.4c leave during dwell never starts Layer 2', (
    tester,
  ) async {
    final display = FakeMediaDisplayRepository();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
        browseLayer2Dwell: const Duration(milliseconds: 300),
      ),
    );
    final ids = await pumpUntilFeedIds(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(display.displayCalls, isEmpty);
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(display.displayCalls, isNot(contains(ids[0])));
  });

  // Leave mid-dwell then immediately re-enter the same asset: the cancelled
  // dwell completer must not ride the restored isCurrent=true and skip N.
  // Defense is FeedMediaRequestGate generation (not isCurrent alone).
  testWidgets(
    'W-16.4h leave mid-dwell then immediate re-enter same asset still waits full N',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
          browseLayer2Dwell: const Duration(milliseconds: 300),
        ),
      );
      final ids = await pumpUntilFeedIds(tester);
      final first = ids[0];
      await tester.pump(const Duration(milliseconds: 100));
      expect(display.displayCalls, isNot(contains(first)));

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pump();
      // Immediate return to the same asset (no dwell time on peek).
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pump();

      expect(
        display.displayCalls,
        isNot(contains(first)),
        reason: 'stale leave-cancelled dwell must not release L2 on re-enter',
      );
      await tester.pump(const Duration(milliseconds: 299));
      expect(
        display.displayCalls,
        isNot(contains(first)),
        reason: 'second visit must arm a fresh full N, not residual time',
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(display.displayCalls, contains(first));
    },
  );

  testWidgets('W-16.4d Retry bypasses dwell', (tester) async {
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['a1'] = 'iCloudDownloadFailed';
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'a1',
          ]),
        ),
        mediaDisplay: display,
        browseLayer2Dwell: const Duration(milliseconds: 300),
      ),
    );
    await pumpUntilFeedIds(tester);
    await tester.pump(const Duration(milliseconds: 300));
    // Cap 15.12: deviceLocal L2 fail → full L1→L2 fallback (W-15.12d) —
    // two sequential display calls before the user taps Retry.
    expect(display.displayCalls, ['a1', 'a1']);
    expect(find.byKey(const Key('mainBrowseFeedLayer2Retry')), findsOneWidget);
    final beforeRetry = display.displayCalls.length;
    display.displayErrorById.remove('a1');
    await tester.tap(find.byKey(const Key('mainBrowseFeedLayer2Retry')));
    // One frame only — Retry must use bypassDwell (no production N wait).
    await tester.pump();
    expect(
      display.displayCalls.length,
      beforeRetry + 1,
      reason: 'Retry must issue requestDisplayAsset immediately (bypassDwell)',
    );
  });

  testWidgets('W-16.4e spinner stays up during dwell', (tester) async {
    final display = FakeMediaDisplayRepository();
    // Full L1→L2 path (not deviceLocal fast-path): All-tab deviceLocal
    // skips still L1, so a hung L2 would never paint mainBrowseFeedStill_*.
    // iCloudNotDownloaded stays in-library for Cap 23 and keeps L1 cover.
    seedDecodableStillPaths(display, const ['a1']);
    display.displayGates['a1'] = Completer<void>();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById: const {'a1': AssetAvailability.iCloudNotDownloaded},
        ),
        mediaDisplay: display,
        browseLayer2Dwell: const Duration(milliseconds: 300),
      ),
    );
    await pumpUntilFeedIds(tester);
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    await pumpUntilStillCoverReadyForAsset(tester, 'a1');
    expect(
      find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
      findsNothing,
      reason:
          'ADR-034 G suppresses still a2 corner chrome below T at dwell start',
    );
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
    await revealLayer2WaitChromeForTest(tester, 'a1');
    expect(
      find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
      findsOneWidget,
      reason: 'still a2 chrome paints at elapsed ≥ T while dwell + L2 hang',
    );
    await tester.pump(const Duration(milliseconds: 139));
    expect(
      find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
      findsOneWidget,
      reason: 'spinner stays through dwell while Layer 2 fetch is hung',
    );
    expect(display.displayCalls, isEmpty);
  });

  testWidgets('W-16.4f neighbour promote still dwells', (tester) async {
    final display = FakeMediaDisplayRepository();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
        browseLayer2Dwell: const Duration(milliseconds: 300),
      ),
    );
    final ids = await pumpUntilFeedIds(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(display.displayCalls, [ids[0]]);
    final neighbor = ids[1];
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    expect(display.displayCalls, isNot(contains(neighbor)));
    await tester.pump(const Duration(milliseconds: 299));
    expect(display.displayCalls, isNot(contains(neighbor)));
    await tester.pump(const Duration(milliseconds: 1));
    expect(display.displayCalls, contains(neighbor));
  });

  testWidgets(
    'W-16.4g Endless round change cancels in-flight dwell on old current',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a', 'b', 'c', 'd', 'e'],
          ),
          mediaDisplay: display,
          browseShuffleSeed: 0,
          browseLayer2Dwell: const Duration(milliseconds: 300),
        ),
      );
      final ids = await pumpUntilFeedIds(tester);
      expect(ids, ['e', 'c', 'd', 'b', 'a']);
      final lastId = ids.last;
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(4);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        if (display.previewCalls.contains(lastId)) {
          break;
        }
        await tester.pump();
      }
      expect(display.previewCalls, contains(lastId));
      expect(display.displayCalls, isNot(contains(lastId)));
      await tester.pump(const Duration(milliseconds: 150));
      expect(display.displayCalls, isNot(contains(lastId)));
      container.read(browseSessionProvider.notifier).advanceToNextRound();
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pump();
      final after = container.read(browseSessionProvider).requireValue;
      expect(after.orderedAssetIds.first, isNot(lastId));
      // Old current had ~150 ms of dwell left. That timer must not fire Layer 2
      // after the round rebuild (new PageView key, old State disposed).
      await tester.pump(const Duration(milliseconds: 200));
      expect(display.displayCalls, isNot(contains(lastId)));
    },
  );

  test(
    'U-14.4b Layer 2 maps assetUnavailable to assetUnavailable fail',
    () async {
      final display = FakeMediaDisplayRepository();
      display.displayErrorById['a1'] = 'assetUnavailable';
      final gate = FeedMediaRequestGate();
      final media = await loadFeedPageLayer2(
        gate: gate,
        generation: gate.begin(),
        sourceKind: AssetSourceKind.entireLibrary,
        assetIdentifier: 'a1',
        feedIndex: 0,
        isCurrent: true,
        layer1: null,
        displayRepository: display,
        playbackRepository: FakePlaybackRepository(),
      );
      expect(media?.kind, FeedPageMediaKind.failed);
      expect(media?.failureReason, FeedFailureReason.assetUnavailable);
    },
  );

  test('U-14.4b Layer 2 maps iCloudDownloadFailed to download fail', () async {
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['a1'] = 'iCloudDownloadFailed';
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: gate.begin(),
      sourceKind: AssetSourceKind.entireLibrary,
      assetIdentifier: 'a1',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: FakePlaybackRepository(),
    );
    expect(media?.kind, FeedPageMediaKind.failed);
    expect(media?.failureReason, FeedFailureReason.download);
  });

  test('W-F7-unit stale generation discards late display', () async {
    final display = FakeMediaDisplayRepository();
    final gateN = Completer<void>();
    display.displayGates['n'] = gateN;
    display.displaysById['n'] = const DisplayAsset(
      assetIdentifier: 'n',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/n.jpg',
    );
    display.displaysById['n2'] = const DisplayAsset(
      assetIdentifier: 'n2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/n2.jpg',
    );

    final gate = FeedMediaRequestGate();
    final playback = FakePlaybackRepository();

    final genN = gate.begin();
    final futureN = loadFeedPageLayer2(
      gate: gate,
      generation: genN,
      sourceKind: AssetSourceKind.mediaTypePhotos,
      assetIdentifier: 'n',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: playback,
    );

    final genN2 = gate.begin();
    final mediaN2 = await loadFeedPageLayer2(
      gate: gate,
      generation: genN2,
      sourceKind: AssetSourceKind.mediaTypePhotos,
      assetIdentifier: 'n2',
      feedIndex: 2,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: playback,
    );
    gateN.complete();
    final mediaN = await futureN;

    expect(mediaN, isNull);
    expect(mediaN2?.display?.assetIdentifier, 'n2');
  });

  testWidgets('W-O-display metadata delay does not block still display', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const ['a1']);
    final presentation = FakePresentationMetadataRepository(
      basicsGate: Completer<void>(),
      sizeGate: Completer<void>(),
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'a1',
          ]),
        ),
        mediaDisplay: display,
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();
    await pumpUntilStillCoverReadyForAsset(tester, 'a1');
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
    expect(presentation.basicsCalls, greaterThan(0));
  });

  testWidgets(
    'W-O-cache returning to seen asset shows cached Overlay without blank',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final a1Created = DateTime(2024, 1, 15, 10, 30);
      final a2Created = DateTime(2023, 5, 20, 8, 0);
      final a1Exact = formatOverlayExactDateTime(
        l10n: l10n,
        createdAt: a1Created,
      );
      final a2Exact = formatOverlayExactDateTime(
        l10n: l10n,
        createdAt: a2Created,
      );
      final a1Size = formatOverlayFileSize(
        l10n: l10n,
        fileSizeBytes: 2_886_627,
      );

      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'a1': PresentationMetadata(
            assetIdentifier: 'a1',
            mediaKind: PresentationMediaKind.image,
            createdAt: a1Created,
          ),
          'a2': PresentationMetadata(
            assetIdentifier: 'a2',
            mediaKind: PresentationMediaKind.image,
            createdAt: a2Created,
          ),
        },
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 2_886_627,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
          'a2': const PresentationFileSize(
            assetIdentifier: 'a2',
            fileSizeBytes: 11_260_685,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );

      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['a1', 'a2']);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['a1', 'a2'],
            ),
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await tester.pumpAndSettle();
      await pumpUntilStillCoverReadyForAsset(tester, 'a1');
      expect(find.text(a1Exact), findsOneWidget);
      expect(find.text(a1Size), findsOneWidget);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      await pumpUntilStillCoverReadyForAsset(tester, 'a2');
      expect(find.text(a2Exact), findsOneWidget);
      expect(find.text(a1Exact), findsNothing);

      // Hang subsequent metadata refresh so only the session cache can paint.
      presentation.basicsGate = Completer<void>();
      presentation.sizeGate = Completer<void>();
      final callsBeforeReturn = presentation.basicsCalls;

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pump(); // one frame — do not settle / wait for hung refresh

      expect(find.text(a1Exact), findsOneWidget);
      expect(find.text(a1Size), findsOneWidget);
      expect(find.text(a2Exact), findsNothing);
      expect(presentation.basicsCalls, greaterThan(callsBeforeReturn));

      // Unblock hung refresh so the test does not leak pending futures.
      presentation.basicsGate!.complete();
      presentation.sizeGate!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('W-L1 resolve loading shows Key and copy; no Overlay', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = _HangingResolveRepository(allIds: const ['a1']);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseFeedLoading')), findsOneWidget);
    expect(find.text(l10n.mainBrowseFeedLoading), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
    expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsNothing);
    expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);

    sources.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
  });

  testWidgets(
    'W-L2 per-page loading Key; Overlay paints when metadata arrives',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final created = DateTime(2024, 7, 1, 9, 0);
      final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'a1': PresentationMetadata(
            assetIdentifier: 'a1',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
        },
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      // Hung L2 needs an L1 still; All-tab deviceLocal skips still L1.
      seedDecodableStillPaths(display, const ['a1']);
      display.displayGates['a1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: const {
              'a1': AssetAvailability.iCloudNotDownloaded,
            },
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await pumpAsyncWork(tester);
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      await pumpUntilStillCoverReadyForAsset(tester, 'a1');
      await revealLayer2WaitChromeForTest(tester, 'a1');
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );

      // Metadata can finish while display is still hung — Overlay stays up.
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text(exact).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseFeedLayer2Retry')), findsNothing);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(find.text(exact), findsOneWidget);

      display.displayGates['a1']!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-L3 Layer 1 shown; Layer 2 fail keeps still and Retry overlay',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayErrorById['a1'] = 'iCloudDownloadFailed';
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['a1'],
            ),
          ),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer2Retry')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsNothing);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseFeedDownloadFailed), findsOneWidget);
    },
  );

  testWidgets('W-L4 Layer 1 miss and Layer 2 fail shows panel + retry', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.previewErrorById['a1'] = 'iCloudDownloadRequired';
    display.displayErrorById['a1'] = 'assetUnavailable';
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
    expect(find.text(l10n.mainBrowseFeedUnavailable), findsOneWidget);
    expect(find.text(l10n.mainBrowseFeedNetworkFailed), findsNothing);
    expect(find.byKey(const Key('mainBrowseFeedPageRetry')), findsNothing);
  });

  testWidgets('W-L5 resolve loading hides Overlay', (tester) async {
    // Empty / resolve-failed Overlay absence covered by W-F3 / W-F4.
    // Separate testWidgets — re-pumping ProviderScope in one test can
    // retain a cached resolve and falsely keep a non-empty feed.
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final hanging = _HangingResolveRepository(allIds: const ['a1']);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: hanging,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseFeedLoading')), findsOneWidget);
    expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
    hanging.gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'W-L6 iCloud download fail keeps Overlay; assetUnavailable hides it',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final created = DateTime(2024, 3, 10, 14, 5);
      final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'cloud': PresentationMetadata(
            assetIdentifier: 'cloud',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
          'bad': PresentationMetadata(
            assetIdentifier: 'bad',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
        },
      );
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['cloud']);
      display.displayErrorById['cloud'] = 'iCloudDownloadFailed';
      display.previewErrorById['bad'] = 'iCloudDownloadRequired';
      display.displayErrorById['bad'] = 'assetUnavailable';

      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['cloud', 'bad'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['cloud'],
            ),
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await tester.pumpAndSettle();
      await pumpUntilStillCoverReadyForAsset(tester, 'cloud');
      expect(
        find.byKey(const Key('mainBrowseFeedStill_cloud')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedLayer2Retry')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mediaInfoOverlay')), findsOneWidget);
      expect(find.text(exact), findsOneWidget);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
      expect(find.byKey(const Key('mediaInfoOverlay')), findsNothing);
      expect(find.text(exact), findsNothing);
    },
  );

  testWidgets(
    'W-Loc2 feed metadata lands Row2+Row3; production path has no Row4',
    (tester) async {
      // Hard gates: exact date (Row2) + formatted size (Row3) from this
      // fixture prove metadata landed — not an empty Overlay shell. Row1
      // relative date is optional (clock-dependent). No Row4 = Location
      // specifically unset on the production feed path.
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final created = DateTime(2023, 11, 15, 8, 30);
      const sizeBytes = 2_886_627;
      final exact = formatOverlayExactDateTime(l10n: l10n, createdAt: created);
      final sizeCopy = formatOverlayFileSize(
        l10n: l10n,
        fileSizeBytes: sizeBytes,
      );
      expect(exact, isNotEmpty);
      expect(sizeCopy, isNotEmpty);

      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'loc1': PresentationMetadata(
            assetIdentifier: 'loc1',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
        },
        sizeById: {
          'loc1': const PresentationFileSize(
            assetIdentifier: 'loc1',
            fileSizeBytes: sizeBytes,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['loc1']);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['loc1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['loc1'],
            ),
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await tester.pumpAndSettle();
      await pumpUntilStillCoverReadyForAsset(tester, 'loc1');

      expect(find.text(exact), findsOneWidget);
      expect(find.text(sizeCopy), findsOneWidget);
      expect(find.byKey(const Key('mediaInfoOverlayRow4')), findsNothing);
    },
  );

  testWidgets('L-F1 Live current: clearPlaybackPool before requestLivePhoto', (
    tester,
  ) async {
    final lifecycleLog = <String>[];
    final live = FakeLivePhotoRepository()..lifecycleLog = lifecycleLog;
    final playback = FakePlaybackRepository()..lifecycleLog = lifecycleLog;
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        playback: playback,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(lifecycleLog, contains('clearPlaybackPool'));
    expect(lifecycleLog, contains('requestLivePhoto:live-1'));
    final clearAt = lifecycleLog.indexOf('clearPlaybackPool');
    final requestAt = lifecycleLog.indexOf('requestLivePhoto:live-1');
    expect(requestAt, greaterThan(clearAt));
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsOneWidget,
    );
  });

  testWidgets('L-F2 leave current Live cancels and stops', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1', 'still-2'],
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(live.calls, contains('requestLivePhoto:live-1'));
    live.calls.clear();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(live.calls, contains('cancel:live-1'));
    expect(live.calls, contains('stopPlayback'));
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
  });

  testWidgets('L-F3 playbackEnded unloads Live motion surface (Q7)', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsOneWidget,
    );
    expect(live.calls, contains('startPlayback'));
    // iOS Photos parity: LIVE stays visible during motion play.
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);

    live.endedController.add(
      const LivePhotoPlaybackEndedEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(live.calls.where((c) => c == 'startPlayback').length, 1);
  });

  testWidgets(
    'W-26.4b-live-mag: LIVE badge hides while still magnified, returns on force-fit',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const [
        'live-1',
      ], mediaKind: PlaybackMediaKind.livePhoto);
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['live-1'],
            ),
          ),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
      await pumpPastLivePreparingSuppress(tester);

      expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      container
          .read(browseMagnificationProvider.notifier)
          .setStillMagnified(true);
      await tester.pump();
      expect(
        find.byKey(const Key('mainBrowseLiveBadge')),
        findsNothing,
        reason: 'LIVE must hide for the whole magnified session',
      );

      container.read(browseMagnificationProvider.notifier).forceFit();
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    },
  );

  testWidgets(
    'L-lifecycle leave inactive unloads Live PV + restores Host still',
    (tester) async {
      final live = FakeLivePhotoRepository(autoReady: true);
      final display = FakeMediaDisplayRepository();
      display.displaysById['live-1'] = const DisplayAsset(
        assetIdentifier: 'live-1',
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: '/tmp/live-1.jpg',
      );
      display.previewsById['live-1'] = display.displaysById['live-1']!;
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsOneWidget,
      );
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.none,
      );

      live.calls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpAsyncWork(tester);

      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedStill_live-1')),
        findsOneWidget,
      );
      expect(live.calls.where((c) => c == 'stopPlayback').length, 1);
      expect(
        _mediaFeedPageState(tester, 'live-1').debugLiveMotionMounted,
        isFalse,
      );
      await tester.pump();
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
      );
    },
  );

  testWidgets(
    'L-lifecycle inactive→hidden→paused is idempotent (one stopPlayback)',
    (tester) async {
      final live = FakeLivePhotoRepository(autoReady: true);
      final display = FakeMediaDisplayRepository();
      display.displaysById['live-1'] = const DisplayAsset(
        assetIdentifier: 'live-1',
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: '/tmp/live-1.jpg',
      );
      display.previewsById['live-1'] = display.displaysById['live-1']!;
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsOneWidget,
      );

      live.calls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await pumpAsyncWork(tester);

      expect(live.calls.where((c) => c == 'stopPlayback').length, 1);
      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsNothing,
      );
      expect(
        _mediaFeedPageState(tester, 'live-1').debugLiveMotionMounted,
        isFalse,
      );
    },
  );

  testWidgets(
    'L-lifecycle resume heal unloads remounted Live after missed leave',
    (tester) async {
      final live = FakeLivePhotoRepository(autoReady: true);
      final display = FakeMediaDisplayRepository();
      display.displaysById['live-1'] = const DisplayAsset(
        assetIdentifier: 'live-1',
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: '/tmp/live-1.jpg',
      );
      display.previewsById['live-1'] = display.displaysById['live-1']!;
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsOneWidget,
      );

      // Leave to inactive only (frames stay enabled — paused/hidden disable
      // scheduler frames and block remount painting in widget tests).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpAsyncWork(tester);
      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsNothing,
      );

      // Remount while still inactive (simulates leave never owning the final
      // motion window — resume must heal).
      live.calls.clear();
      await _mediaFeedPageState(tester, 'live-1').debugPrepareLiveMotion();
      await pumpAsyncWork(tester);
      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsOneWidget,
      );
      expect(
        _mediaFeedPageState(tester, 'live-1').debugLiveMotionMounted,
        isTrue,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpAsyncWork(tester);

      expect(
        find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
        findsNothing,
      );
      expect(live.calls.where((c) => c == 'stopPlayback').length, 1);
      expect(
        _mediaFeedPageState(tester, 'live-1').debugLiveMotionMounted,
        isFalse,
      );
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      await tester.pump();
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
      );
    },
  );

  testWidgets('L-F4 sync request failure keeps still + badge (no skip)', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository(
      throwOnRequestCode: 'unsupportedMedia',
    );
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
  });

  testWidgets('L-F5 failedEvents unloads motion; still remains', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsOneWidget,
    );

    live.failedController.add(
      const LivePhotoFailedEvent(
        assetIdentifier: 'live-1',
        error: AppError.iCloudDownloadFailed,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
  });

  testWidgets(
    'L-F6 stale ready after leave does not startPlayback on re-enter race',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      display.displaysById['live-1'] = const DisplayAsset(
        assetIdentifier: 'live-1',
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: '/tmp/live-1.jpg',
      );
      display.displaysById['still-2'] = const DisplayAsset(
        assetIdentifier: 'still-2',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/still-2.jpg',
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1', 'still-2'],
          ),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      // Stale ready from first activation — must be ignored (F4 token).
      live.readyController.add(
        const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
      );
      await pumpAsyncWork(tester);
      expect(live.calls.where((c) => c == 'startPlayback'), isEmpty);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await pumpAsyncWork(tester);
      final startsBefore = live.calls.where((c) => c == 'startPlayback').length;

      live.readyController.add(
        const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
      );
      await pumpAsyncWork(tester);
      expect(
        live.calls.where((c) => c == 'startPlayback').length,
        greaterThan(startsBefore),
      );
    },
  );

  testWidgets('L-F7 re-enter Live requests again (Q6 play-once)', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    display.displaysById['still-2'] = const DisplayAsset(
      assetIdentifier: 'still-2',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/still-2.jpg',
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1', 'still-2'],
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(live.calls.where((c) => c == 'requestLivePhoto:live-1').length, 1);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await pumpAsyncWork(tester);

    expect(live.calls.where((c) => c == 'requestLivePhoto:live-1').length, 2);
  });

  testWidgets(
    'L-F8 leave→return while cancel held: second request after cancel/stop',
    (tester) async {
      // F4 lock: if feed-scoped `LiveHostOpSerial.enqueue` is bypassed and
      // cancel/request race freely, the mid-hold assertion (no request while
      // cancel held) fails.
      // Note: still-2 may cancel/stop interleaved in the shared call log;
      // assertions use a mid-hold snapshot so that noise is excluded.
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      display.displaysById['live-1'] = const DisplayAsset(
        assetIdentifier: 'live-1',
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: '/tmp/live-1.jpg',
      );
      display.displaysById['still-2'] = const DisplayAsset(
        assetIdentifier: 'still-2',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/still-2.jpg',
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1', 'still-2'],
          ),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      expect(live.calls.where((c) => c == 'requestLivePhoto:live-1').length, 1);

      live.calls.clear();
      final cancelHold = Completer<void>();
      live.cancelHold = cancelHold;
      live.cancelHoldAssetId = 'live-1';

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pump();
      await tester.idle();
      await tester.pump();
      expect(
        live.calls,
        contains('cancel:live-1'),
        reason: 'leave must invoke cancel(live-1); calls=${live.calls}',
      );

      // Return while cancel still held — live-1 chain must not request yet.
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pump();
      await tester.idle();
      await tester.pump();
      final midHoldCalls = List<String>.from(live.calls);
      expect(
        midHoldCalls.where((c) => c == 'requestLivePhoto:live-1'),
        isEmpty,
        reason:
            're-enter request must wait for leave cancel/stop '
            '(LiveHostOpSerial); mid=$midHoldCalls',
      );

      cancelHold.complete();
      await pumpAsyncWork(tester);

      final afterHold = live.calls.skip(midHoldCalls.length).toList();
      expect(
        afterHold,
        contains('stopPlayback'),
        reason:
            'leave stop must run after cancelHold; after=$afterHold '
            'full=${live.calls}',
      );
      expect(
        afterHold,
        contains('requestLivePhoto:live-1'),
        reason:
            're-enter request must run after cancelHold; after=$afterHold '
            'full=${live.calls}',
      );
      expect(
        afterHold.indexOf('stopPlayback'),
        lessThan(afterHold.indexOf('requestLivePhoto:live-1')),
        reason: 'stop before request in post-hold suffix; after=$afterHold',
      );
    },
  );

  testWidgets('L-S1 preparing Key while waiting for ready', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const [
      'live-1',
    ], mediaKind: PlaybackMediaKind.livePhoto);
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'live-1',
          ]),
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
    await pumpPastLivePreparingSuppress(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(find.bySemanticsLabel('Loading Live Photo'), findsOneWidget);
  });

  testWidgets('L-S2 ready clears preparing Key', (tester) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const [
      'live-1',
    ], mediaKind: PlaybackMediaKind.livePhoto);
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'live-1',
          ]),
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
    await pumpPastLivePreparingSuppress(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(live.calls, contains('startPlayback'));
  });

  testWidgets('L-S3 sync request failure clears preparing; still remains', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository(
      throwOnRequestCode: 'unsupportedMedia',
    );
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseLiveBadge')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsNothing);
  });

  testWidgets('L-S4 failedEvents clears preparing; still remains', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const [
      'live-1',
    ], mediaKind: PlaybackMediaKind.livePhoto);
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'live-1',
          ]),
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
    await pumpPastLivePreparingSuppress(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    live.failedController.add(
      const LivePhotoFailedEvent(
        assetIdentifier: 'live-1',
        error: AppError.iCloudDownloadFailed,
      ),
    );
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(find.byKey(const Key('mainBrowseFeedStill_live-1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedPageICloud')), findsNothing);
  });

  testWidgets('L-S5 leave while preparing clears preparing Key', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const [
      'live-1',
    ], mediaKind: PlaybackMediaKind.livePhoto);
    seedDecodableStillPaths(display, const ['still-2']);
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1', 'still-2'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'live-1',
            'still-2',
          ]),
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
    await pumpPastLivePreparingSuppress(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
  });

  testWidgets('L-S6 leave→return: stale ready does not clear new preparing', (
    tester,
  ) async {
    // Cap 9.5: (1) off-page stream ready after leave → no startPlayback
    // (subscriptions torn down). (2) After re-enter preparing is lit,
    // debugSetLivePreparing(stale) must not clear it — defensive gate litmus
    // (not a stream-reproducible dual-listener race; see hook doc).
    final live = FakeLivePhotoRepository();
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const [
      'live-1',
    ], mediaKind: PlaybackMediaKind.livePhoto);
    seedDecodableStillPaths(display, const ['still-2']);
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['live-1', 'still-2'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'live-1',
            'still-2',
          ]),
        ),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
    await pumpPastLivePreparingSuppress(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
    );

    live.calls.clear();
    final cancelHold = Completer<void>();
    live.cancelHold = cancelHold;
    live.cancelHoldAssetId = 'live-1';

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);

    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    await tester.idle();
    await tester.pump();
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );

    // Stale ready while off Live — must not startPlayback.
    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await tester.pump();
    expect(live.calls.where((c) => c == 'startPlayback'), isEmpty);

    // Return while cancel held — no new preparing until chain advances.
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await tester.pump();
    await tester.idle();
    await pumpPastLivePreparingSuppress(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
      reason:
          '14.6b handoff keeps the Live spinner during LiveHostOpSerial wait',
    );
    expect(live.calls.where((c) => c == 'requestLivePhoto:live-1'), isEmpty);

    cancelHold.complete();
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
      reason: 'current activation preparing after re-enter request',
    );

    // Defensive stale write (not a stream-reproducible race today — leave
    // cancels listeners before return re-subscribes). generation 0 is never
    // current after any begin(); locks gatedFlagUpdate via the sole write path.
    final startPlaybackBeforeStale = live.calls
        .where((c) => c == 'startPlayback')
        .length;
    final livePage = tester.state<MediaFeedPageState>(
      find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == 'live-1',
      ),
    );
    livePage.debugSetLivePreparing(0, false);
    await tester.pump();
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsOneWidget,
      reason: 'stale generation must not clear current preparing',
    );
    expect(
      live.calls.where((c) => c == 'startPlayback').length,
      startPlaybackBeforeStale,
    );

    // Current ready ends preparing and may startPlayback.
    live.readyController.add(
      const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
    );
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      findsNothing,
    );
    expect(live.calls, contains('startPlayback'));
  });

  testWidgets(
    'W-14.6b-L1 Live hung Layer 2 uses combined spinner, not Layer 3',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const [
        'live-1',
      ], mediaKind: PlaybackMediaKind.livePhoto);
      display.displayGates['live-1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1'],
            availabilityById: const {
              'live-1': AssetAvailability.iCloudNotDownloaded,
            },
          ),
          mediaDisplay: display,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
      await revealLayer2WaitChromeForTest(tester, 'live-1');

      expect(
        find.byKey(const Key('mainBrowseFeedStill_live-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsNothing,
      );
      expect(
        live.calls.where((c) => c.startsWith('requestLivePhoto')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'W-14.6b-L2 Live spinner stays after Layer 2 until motion ready',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const [
        'live-1',
      ], mediaKind: PlaybackMediaKind.livePhoto);
      // Hold L2 with elapsed ≥ T so wait chrome latches — ADR-037 continuity.
      final gate = Completer<void>();
      display.displayGates['live-1'] = gate;
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1'],
            availabilityById: const {
              'live-1': AssetAvailability.iCloudNotDownloaded,
            },
          ),
          mediaDisplay: display,
          livePhoto: live,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate(
          (w) => w is MediaFeedPage && w.assetIdentifier == 'live-1',
        ),
      );
      await pumpUntilStillCoverReady(tester, page);
      await revealLayer2WaitChromeForTest(tester, 'live-1');
      expect(
        find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
        findsOneWidget,
      );
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(display.displayCalls, contains('live-1'));
      expect(live.calls, contains('requestLivePhoto:live-1'));

      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
          findsOneWidget,
          reason: 'combined spinner must not drop between Layer 2 and ready',
        );
        expect(
          find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
          findsNothing,
        );
      }
    },
  );

  testWidgets(
    'W-14.6b-L3 Live chrome sits top-leading under Browse band (measure)',
    (tester) async {
      final live = FakeLivePhotoRepository();
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const [
        'live-1',
      ], mediaKind: PlaybackMediaKind.livePhoto);
      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'live-1': PresentationMetadata(
            assetIdentifier: 'live-1',
            mediaKind: PresentationMediaKind.livePhoto,
            createdAt: DateTime(2024, 7, 1, 9, 0),
          ),
        },
        sizeById: {
          'live-1': const PresentationFileSize(
            assetIdentifier: 'live-1',
            fileSizeBytes: 2048,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['live-1'],
            ),
          ),
          mediaDisplay: display,
          livePhoto: live,
          presentationMetadata: presentation,
        ),
      );
      await pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, 'live-1');
      await pumpPastLivePreparingSuppress(tester);

      final chrome = tester.getRect(
        find.byKey(const Key('mainBrowseFeedLiveChrome_live-1')),
      );
      final badge = tester.getRect(
        find.byKey(const Key('mainBrowseLiveBadge')),
      );
      final overlay = tester.getRect(find.byKey(const Key('mediaInfoOverlay')));
      final badgeContext = tester.element(
        find.byKey(const Key('mainBrowseLiveBadge')),
      );
      final paddingTop = MediaQuery.paddingOf(badgeContext).top;
      final expectedTop = mainBrowseLiveBadgeTopInset(
        mediaQueryPaddingTop: paddingTop,
        limitedCreateHelperBand: false,
      );
      expect(
        chrome.overlaps(overlay),
        isFalse,
        reason: 'top-leading LIVE must not overlap bottom Meta overlay',
      );
      expect(
        badge.left,
        closeTo(kLiveBadgeLeadingInset, 0.5),
        reason: 'LIVE left matches Temp/Saved chip leading inset',
      );
      expect(
        badge.top,
        closeTo(expectedTop, 1.0),
        reason:
            'LIVE top = padding.top($paddingTop) + Full band + gap '
            '(got ${badge.top}; expected $expectedTop)',
      );
      final liveSpinner = tester.getRect(
        find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
      );
      expect(
        liveSpinner.bottom,
        greaterThan(badge.bottom),
        reason: 'prepare spinner stays bottom-trailing after LIVE move',
      );
    },
  );

  testWidgets(
    'W-14.6b-L4 non-Live Layer 2 spinner sits in the same bottom-right corner',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['a1']);
      display.displayGates['a1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: const {
              'a1': AssetAvailability.iCloudNotDownloaded,
            },
          ),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      await pumpUntilStillCoverReadyForAsset(tester, 'a1');
      await revealLayer2WaitChromeForTest(tester, 'a1');

      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseFeedLoading')), findsNothing);
      final spinner = tester.getRect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
      );
      final chrome = tester.getRect(
        find.byKey(const Key('mainBrowseFeedLayer3Chrome')),
      );
      final feed = tester.getRect(find.byKey(const Key('mainBrowseFeed')));
      final tokens = Theme.of(
        tester.element(find.byKey(const Key('mainBrowseFeed'))),
      ).extension<WakeTokTokens>()!;
      expect(
        spinner.center.dx,
        greaterThan(feed.center.dx),
        reason: 'Layer 2 spinner must be right of feed center, not centered',
      );
      expect(
        spinner.center.dy,
        greaterThan(feed.center.dy),
        reason: 'Layer 2 spinner must be below feed center, not centered',
      );
      // Debt 454: trailing stays kMediaChromeTrailingInset; bottom follows
      // mainBrowseLiveStatusBottomInset since 81904e1 (was hardcoded 12).
      expect(feed.right - chrome.right, closeTo(kMediaChromeTrailingInset, 1));
      expect(
        feed.bottom - chrome.bottom,
        closeTo(mainBrowseLiveStatusBottomInset(tokens), 1),
      );
      expect(
        spinner.center.dy,
        closeTo(chrome.center.dy, 1),
        reason:
            'non-Live spinner is vertically centered in the corner chrome row',
      );
    },
  );

  testWidgets(
    'W-15.3 Layer 1 miss uses corner chrome, not centered or library loading',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final display = FakeMediaDisplayRepository();
      display.previewGates['a1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);

      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoadingChrome')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('mainBrowseFeedLoading')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
        findsNothing,
      );
      expect(find.byKey(const Key('mainBrowseFeedLayer3Chrome')), findsNothing);
      expect(
        find.bySemanticsLabel(l10n.mainBrowseFeedLayer1Loading),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.mainBrowseLiveBadge), findsNothing);
      expect(
        find.bySemanticsLabel(l10n.mainBrowseFeedLayer3Loading),
        findsNothing,
      );

      final spinner = tester.getRect(
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
      );
      final chrome = tester.getRect(
        find.byKey(const Key('mainBrowseFeedPageLoadingChrome')),
      );
      final feed = tester.getRect(find.byKey(const Key('mainBrowseFeed')));
      final tokens = Theme.of(
        tester.element(find.byKey(const Key('mainBrowseFeed'))),
      ).extension<WakeTokTokens>()!;
      expect(
        spinner.center.dx,
        greaterThan(feed.center.dx),
        reason:
            'Layer 1 miss spinner must be right of feed center, not centered',
      );
      expect(
        spinner.center.dy,
        greaterThan(feed.center.dy),
        reason: 'Layer 1 miss spinner must be below feed center, not centered',
      );
      // Debt 454: trailing stays kMediaChromeTrailingInset; bottom follows
      // mainBrowseLiveStatusBottomInset since 81904e1 (was hardcoded 12).
      expect(feed.right - chrome.right, closeTo(kMediaChromeTrailingInset, 1));
      expect(
        feed.bottom - chrome.bottom,
        closeTo(mainBrowseLiveStatusBottomInset(tokens), 1),
      );
      expect(
        spinner.center.dy,
        closeTo(chrome.center.dy, 1),
        reason: 'miss spinner is vertically centered in the corner chrome row',
      );

      display.previewGates['a1']!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('L-M1 default unmuted: setMute:false before startPlayback', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);

    final muteAt = live.calls.indexOf('setMute:false');
    final startAt = live.calls.indexOf('startPlayback');
    expect(muteAt, isNonNegative, reason: 'explicit setMute(false) required');
    expect(startAt, isNonNegative);
    expect(muteAt, lessThan(startAt));
  });

  testWidgets('L-M2 muted pref: setMute:true before startPlayback', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['live-1']),
        mediaDisplay: display,
        livePhoto: live,
        sharedMuteInitiallyMuted: true,
      ),
    );
    await pumpAsyncWork(tester);

    final muteAt = live.calls.indexOf('setMute:true');
    final startAt = live.calls.indexOf('startPlayback');
    expect(muteAt, isNonNegative);
    expect(startAt, isNonNegative);
    expect(muteAt, lessThan(startAt));
    expect(live.calls.contains('setMute:false'), isFalse);
  });

  testWidgets(
    'L-M3 after Live clear → video: setMute before play (index order)',
    (tester) async {
      final live = FakeLivePhotoRepository(autoReady: true);
      final playback = FakePlaybackRepository();
      final display = FakeMediaDisplayRepository();
      display.displaysById['live-1'] = const DisplayAsset(
        assetIdentifier: 'live-1',
        mediaKind: PlaybackMediaKind.livePhoto,
        localFilePath: '/tmp/live-1.jpg',
      );
      // All: unsupportedMedia → video path for v1.
      display.displayErrorById['v1'] = 'unsupportedMedia';
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['live-1', 'v1'],
          ),
          mediaDisplay: display,
          playback: playback,
          livePhoto: live,
        ),
      );
      await pumpAsyncWork(tester);
      expect(playback.calls, contains('clearPlaybackPool'));

      playback.calls.clear();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
      final muteAt = playback.calls.indexOf('setMute:false');
      final playAt = playback.calls.indexOf('play');
      expect(muteAt, isNonNegative);
      expect(playAt, isNonNegative);
      expect(muteAt, lessThan(playAt));
    },
  );

  testWidgets('L-M4 video→Live→video: second video setMute before play', (
    tester,
  ) async {
    final live = FakeLivePhotoRepository(autoReady: true);
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    display.displaysById['live-1'] = const DisplayAsset(
      assetIdentifier: 'live-1',
      mediaKind: PlaybackMediaKind.livePhoto,
      localFilePath: '/tmp/live-1.jpg',
    );
    display.previewsById['live-1'] = display.displaysById['live-1']!;
    display.displayErrorById['v1'] = 'unsupportedMedia';
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'live-1']),
        mediaDisplay: display,
        playback: playback,
        livePhoto: live,
      ),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    expect(
      playback.calls.indexOf('setMute:false'),
      lessThan(playback.calls.indexOf('play')),
    );

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    expect(playback.calls, contains('clearPlaybackPool'));

    playback.calls.clear();
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    final muteAt = playback.calls.indexOf('setMute:false');
    final playAt = playback.calls.indexOf('play');
    expect(muteAt, isNonNegative);
    expect(playAt, isNonNegative);
    expect(muteAt, lessThan(playAt));
  });

  testWidgets('W-SHUF-1 Random(0) head matches Shuffle golden', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(allIds: const ['x', 'y', 'z']);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
      ),
    );
    await tester.pumpAndSettle();

    // Random(0) → [z,y,x]
    expect(find.byKey(const Key('mainBrowseFeedStill_z')), findsOneWidget);
  });

  testWidgets(
    'W-SHUF-2 distinguishable seeds yield different ordered content',
    (tester) async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      // Hard assert via two ProviderContainers (same as APP-3) — avoids
      // WidgetTester ProviderScope reuse pitfalls across pumpWidget swaps.
      final container1 = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) =>
                () => Random(1),
          ),
        ],
      );
      addTearDown(container1.dispose);
      final ids1 = (await container1.read(
        browseSessionProvider.future,
      )).orderedAssetIds;

      final container2 = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) =>
                () => Random(2),
          ),
        ],
      );
      addTearDown(container2.dispose);
      final ids2 = (await container2.read(
        browseSessionProvider.future,
      )).orderedAssetIds;

      expect(ids1, ['a', 'b', 'c', 'd', 'e']);
      expect(ids2, ['c', 'a', 'e', 'b', 'd']);
      expect(ids2, isNot(ids1));

      // UI smoke: seed 2 lands on shuffled head.
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a', 'b', 'c', 'd', 'e'],
          ),
          browseShuffleSeed: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_c')), findsOneWidget);
    },
  );

  testWidgets('W-END-1 advanceToNextRound API: index 0, first ≠ prior last', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    final before = container.read(browseSessionProvider).requireValue;
    expect(before.orderedAssetIds, ['e', 'c', 'd', 'b', 'a']);
    final lastId = before.orderedAssetIds.last;

    // Avoid pumpAndSettle near end — placeholder neighbor spinner never settles.
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(4);
    await tester.pump();
    await tester.pump();

    container.read(browseSessionProvider.notifier).advanceToNextRound();
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    await tester.pump();
    await tester.pump();

    final after = container.read(browseSessionProvider).requireValue;
    expect(container.read(mainBrowseFeedIndexProvider), 0);
    expect(after.orderedAssetIds.first, isNot(lastId));
    expect(after.roundEpoch, greaterThan(before.roundEpoch));
  });

  testWidgets('W-END-2 last real page in-range ScrollUpdate does not advance', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    final before = container.read(browseSessionProvider).requireValue;
    // Last real item (n-1), not the placeholder page.
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(4);
    await tester.pump();
    await tester.pump();

    final pageContext = tester.element(find.byType(PageView));
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 800,
      pixels: 800,
      viewportDimension: 400,
      axisDirection: AxisDirection.down,
      devicePixelRatio: tester.view.devicePixelRatio,
    );
    expect(metrics.extentAfter, 0);
    expect(metrics.outOfRange, isFalse);
    ScrollUpdateNotification(
      metrics: metrics,
      context: pageContext,
      depth: 0,
      dragDetails: null,
      scrollDelta: 12,
    ).dispatch(pageContext);
    await tester.pump();

    final after = container.read(browseSessionProvider).requireValue;
    expect(after.roundEpoch, before.roundEpoch);
    expect(container.read(mainBrowseFeedIndexProvider), 4);
  });

  testWidgets('W-END-3 placeholder exists when n>1', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    final n = container
        .read(browseSessionProvider)
        .requireValue
        .orderedAssetIds
        .length;
    expect(n, greaterThan(1));

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final delegate = pageView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, n + 1);

    // Land on last real page so allowImplicitScrolling builds the neighbor
    // placeholder — do not jumpToPage(n) (ScrollEnd settle would advance).
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(n - 1);
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(
        const Key('mainBrowseEndlessRoundPlaceholder'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('mainBrowseEndlessRoundPlaceholder'),
          skipOffstage: false,
        ),
        matching: find.byKey(
          const Key('mainBrowseFeedCoverlessWaitLabel'),
          skipOffstage: false,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('mainBrowseEndlessRoundPlaceholder'),
          skipOffstage: false,
        ),
        matching: find.byKey(
          const Key('mainBrowseFeedPageLoadingSpinner'),
          skipOffstage: false,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'W-END-9 round advance does not arm ADR-039 Layer1 center-label delay',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: sources,
          browseShuffleSeed: 0,
        ),
      );
      await tester.pumpAndSettle();

      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      expect(feedState.debugLastDelayInitialLayer1CenterLabel, isFalse);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      feedState.debugAdvanceEndlessRound(l10n);
      await tester.pump();
      await tester.pump();

      expect(feedState.debugLastDelayInitialLayer1CenterLabel, isFalse);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      hideCap19BrowseToast();
      await tester.pump(kCap19BrowseToastDuration);
    },
  );
  testWidgets(
    'W-END-4 placeholder ScrollEnd settle advances (debugAdvanceEndlessRound)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: sources,
          browseShuffleSeed: 0,
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      final before = container.read(browseSessionProvider).requireValue;
      final lastId = before.orderedAssetIds.last;
      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Prefer debug seam — widget-test ScrollEnd settle on placeholder is flaky.
      feedState.debugAdvanceEndlessRound(l10n);
      await tester.pump();
      await tester.pump();

      final after = container.read(browseSessionProvider).requireValue;
      expect(after.roundEpoch, greaterThan(before.roundEpoch));
      expect(after.orderedAssetIds.first, isNot(lastId));
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.byKey(const Key('mainBrowseNewRoundToast')), findsOneWidget);
      hideCap19BrowseToast();
      await tester.pump(kCap19BrowseToastDuration);
    },
  );

  testWidgets('W-END-5 overscroll from end advances round', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    final before = container.read(browseSessionProvider).requireValue;
    final lastId = before.orderedAssetIds.last;

    final pageContext = tester.element(find.byType(PageView));
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 800,
      pixels: 800,
      viewportDimension: 400,
      axisDirection: AxisDirection.down,
      devicePixelRatio: tester.view.devicePixelRatio,
    );
    OverscrollNotification(
      metrics: metrics,
      context: pageContext,
      overscroll: 24,
      dragDetails: null,
    ).dispatch(pageContext);
    await tester.pump();
    await tester.pump();

    final after = container.read(browseSessionProvider).requireValue;
    expect(after.roundEpoch, greaterThan(before.roundEpoch));
    expect(after.orderedAssetIds.first, isNot(lastId));
    expect(container.read(mainBrowseFeedIndexProvider), 0);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    hideCap19BrowseToast();
    await tester.pump(kCap19BrowseToastDuration);
  });

  testWidgets('W-END-7 starting-over toast hides when leaving remounted head', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
      ),
    );
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    expect(container.read(mainBrowseFeedIndexProvider), 0);

    final feedState = tester.state<VerticalMediaFeedState>(
      find.byType(VerticalMediaFeed),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    feedState.debugShowNewRoundToastArmed(l10n);
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseNewRoundToast')), findsOneWidget);
    expect(feedState.debugNewRoundToastDismissOnLeaveHead, isTrue);

    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseNewRoundToast')), findsNothing);
    expect(feedState.debugNewRoundToastDismissOnLeaveHead, isFalse);
  });

  testWidgets('W-END-8 Settings off skips starting-over toast after advance', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final sources = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c', 'd', 'e'],
    );
    final prefs = FakeNewRoundToastPreferences()..newRoundToastEnabled = false;
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: sources,
        browseShuffleSeed: 0,
        newRoundToastPreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    final feedState = tester.state<VerticalMediaFeedState>(
      find.byType(VerticalMediaFeed),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    feedState.debugAdvanceEndlessRound(l10n);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.byKey(const Key('mainBrowseNewRoundToast')), findsNothing);
  });

  test('U-14.4 Layer 1 miss is null not failed', () async {
    final display = FakeMediaDisplayRepository();
    display.previewErrorById['a1'] = 'iCloudDownloadRequired';
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer1(
      gate: gate,
      generation: gate.begin(),
      assetIdentifier: 'a1',
      displayRepository: display,
    );
    expect(media, isNull);
    expect(display.previewCalls, ['a1']);
  });

  test('U-14.4 off-current still does not call preview in Layer 2', () async {
    final display = FakeMediaDisplayRepository();
    final playback = FakePlaybackRepository();
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: gate.begin(),
      sourceKind: AssetSourceKind.mediaTypePhotos,
      assetIdentifier: 'a1',
      feedIndex: 1,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: playback,
    );
    expect(display.previewCalls, isEmpty);
    expect(media?.kind, FeedPageMediaKind.still);
    expect(media?.displayLayer, FeedDisplayLayer.full);
  });

  testWidgets('W-14.4 leave current cancels in-flight PhotoKit requests', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayGates['a1'] = Completer<void>();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(display.cancelPreviewCalls, contains('a1'));
    expect(display.cancelDisplayCalls, contains('a1'));
    expect(display.cancelPlayableCalls, contains('a1'));
  });

  testWidgets('W-14.4 disposing current page cancels PhotoKit requests', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayGates['a1'] = Completer<void>();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(display.cancelPreviewCalls, contains('a1'));
    expect(display.cancelDisplayCalls, contains('a1'));
    expect(display.cancelPlayableCalls, contains('a1'));
  });

  testWidgets('W-14.5 two items at 0 preheats +1 neighbour', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
      ),
    );
    await tester.pumpAndSettle();
    final ids = await _feedOrderedIds(tester);
    expect(display.previewCalls.toSet(), {ids[0], ids[1]});
    expect(display.displayCalls, [ids[0]]);
    expect(display.playableCalls, isEmpty);
  });

  test('U-14.4 Layer 2 operationCancelled is null not failed', () async {
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['a1'] = 'operationCancelled';
    final gate = FeedMediaRequestGate();
    final media = await loadFeedPageLayer2(
      gate: gate,
      generation: gate.begin(),
      sourceKind: AssetSourceKind.entireLibrary,
      assetIdentifier: 'a1',
      feedIndex: 0,
      isCurrent: true,
      layer1: null,
      displayRepository: display,
      playbackRepository: FakePlaybackRepository(),
    );
    expect(media, isNull);
  });

  testWidgets('W-14.4 video keeps Layer 1 poster until surface ready (G3/G4)', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    final posterPath = writeStillCoverTestPng('v1_14_4');
    display.previewsById['v1'] = DisplayAsset(
      assetIdentifier: 'v1',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: posterPath,
    );
    final playback = FakePlaybackRepository();
    playback.loadGates['v1'] = Completer<void>();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['v1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'v1',
          ]),
        ),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'v1');
    await revealLayer2WaitChromeForTest(tester, 'v1');

    expect(find.byKey(const Key('mainBrowseFeedStill_v1')), findsOneWidget);
    expect(
      find.byKey(const Key('mainBrowseFeedLayer3Spinner')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsNothing);

    playback.loadGates['v1']!.complete();
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedStill_v1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedLayer3Spinner')), findsNothing);
  });

  testWidgets(
    'W-14.4 missing JPEG file uses errorBuilder placeholder (LRU eviction)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      const missing = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/waketok_14_4_missing_file.jpg',
      );
      display.previewsById['a1'] = missing;
      display.displaysById['a1'] = missing;
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'W-14.4b inactive→resumed retries full-page fail via _startLoad',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.previewErrorById['a1'] = 'iCloudDownloadRequired';
      display.displayErrorById['a1'] = 'assetUnavailable';
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsOneWidget);
      final before = display.displayCalls.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpAsyncWork(tester);

      expect(display.displayCalls.length, greaterThan(before));
    },
  );

  testWidgets(
    'W-14.4b inactive→resumed retries overlay fail via Layer 2 only',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayErrorById['a1'] = 'iCloudDownloadFailed';
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['a1'],
            ),
          ),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseFeedLayer2Retry')),
        findsOneWidget,
      );
      final previews = display.previewCalls.length;
      final displays = display.displayCalls.length;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpAsyncWork(tester);

      expect(display.displayCalls.length, greaterThan(displays));
      expect(display.previewCalls.length, previews);
    },
  );

  testWidgets('W-14.4b inactive→resumed does not retry a successful still', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        mediaDisplay: display,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    final before = display.displayCalls.length;

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpAsyncWork(tester);

    expect(display.displayCalls.length, before);
  });

  testWidgets(
    'S-1 still Layer 2 success refreshes blank Overlay size on same page',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      const sizeBytes = 2_886_627;
      final sizeCopy = formatOverlayFileSize(
        l10n: l10n,
        fileSizeBytes: sizeBytes,
      );
      final presentation = FakePresentationMetadataRepository(
        sizeSequenceById: {
          'a1': [
            const PresentationFileSize(assetIdentifier: 'a1'),
            const PresentationFileSize(
              assetIdentifier: 'a1',
              fileSizeBytes: sizeBytes,
              fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
            ),
          ],
        },
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      seedDecodableStillPaths(display, const ['a1']);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById: FakeAssetSourceRepository.deviceLocalForIds(
              const ['a1'],
            ),
          ),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );
      await tester.pumpAndSettle();
      await pumpUntilStillCoverReadyForAsset(tester, 'a1');
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(find.text(sizeCopy), findsOneWidget);
      expect(presentation.sizeCalls, 2);
    },
  );

  testWidgets('S-2 existing Overlay size skips Layer 2 size refresh', (
    tester,
  ) async {
    const sizeBytes = 2_886_627;
    final presentation = FakePresentationMetadataRepository(
      sizeById: {
        'a1': const PresentationFileSize(
          assetIdentifier: 'a1',
          fileSizeBytes: sizeBytes,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      },
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(presentation.sizeCalls, 1);
  });

  testWidgets('S-3 swipe away discards in-flight Layer 2 size refresh', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    const a1Bytes = 2_886_627;
    const a2Bytes = 11_260_685;
    final a1Size = formatOverlayFileSize(l10n: l10n, fileSizeBytes: a1Bytes);
    final a2Size = formatOverlayFileSize(l10n: l10n, fileSizeBytes: a2Bytes);
    final presentation = FakePresentationMetadataRepository(
      hangOnSizeCall: 2,
      sizeGate: Completer<void>(),
      sizeSequenceById: {
        'a1': [
          const PresentationFileSize(assetIdentifier: 'a1'),
          const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: a1Bytes,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        ],
      },
      sizeById: {
        'a2': const PresentationFileSize(
          assetIdentifier: 'a2',
          fileSizeBytes: a2Bytes,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      },
    );
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    seedDecodableStillPaths(display, const ['a1', 'a2']);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1', 'a2'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'a1',
            'a2',
          ]),
        ),
        mediaDisplay: display,
        presentationMetadata: presentation,
      ),
    );
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'a1');
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(find.text(a1Size), findsNothing);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();
    await pumpUntilStillCoverReadyForAsset(tester, 'a2');
    expect(find.text(a2Size), findsOneWidget);
    expect(find.text(a1Size), findsNothing);

    presentation.sizeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text(a2Size), findsOneWidget);
    expect(find.text(a1Size), findsNothing);
  });

  testWidgets('S-4 Layer 2 failure does not refresh Overlay size', (
    tester,
  ) async {
    final presentation = FakePresentationMetadataRepository(
      sizeById: {'a1': const PresentationFileSize(assetIdentifier: 'a1')},
    );
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['a1'] = 'iCloudDownloadFailed';
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'a1',
          ]),
        ),
        mediaDisplay: display,
        presentationMetadata: presentation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedLayer2Retry')), findsOneWidget);
    expect(presentation.sizeCalls, 1);
  });

  testWidgets('S-5 video Overlay size refreshes after surface ready', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    const sizeBytes = 11_260_685;
    final sizeCopy = formatOverlayFileSize(
      l10n: l10n,
      fileSizeBytes: sizeBytes,
    );
    final presentation = FakePresentationMetadataRepository(
      sizeSequenceById: {
        'v1': [
          const PresentationFileSize(assetIdentifier: 'v1'),
          const PresentationFileSize(
            assetIdentifier: 'v1',
            fileSizeBytes: sizeBytes,
            fileSizeSemantics: FileSizeSemantics.localVideoUrl,
          ),
        ],
      },
    );
    final display = FakeMediaDisplayRepository();
    final posterPath = writeStillCoverTestPng('v1_poster');
    display.previewsById['v1'] = DisplayAsset(
      assetIdentifier: 'v1',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: posterPath,
    );
    display.displaysById['v1'] = DisplayAsset(
      assetIdentifier: 'v1',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: posterPath,
    );
    final playback = FakePlaybackRepository();
    playback.loadGates['v1'] = Completer<void>();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['v1'],
          availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
            'v1',
          ]),
        ),
        mediaDisplay: display,
        playback: playback,
        presentationMetadata: presentation,
      ),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsNothing);
    expect(find.text(sizeCopy), findsNothing);

    playback.loadGates['v1']!.complete();
    await pumpAsyncWork(tester);
    await pumpUntilStillCoverReadyForAsset(tester, 'v1');
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    expect(find.text(sizeCopy), findsOneWidget);
    expect(presentation.sizeCalls, 2);
  });

  testWidgets(
    'W-14.4c Settings round-trip restarts Layer 2 and does not stick on loading',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      expect(display.displayCalls, isNotEmpty);
      final displaysAtHang = display.displayCalls.length;

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);
      await pumpAsyncWork(tester);

      expect(display.displayCalls.length, greaterThan(displaysAtHang));
      display.displayGates['a1']!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mainBrowseFeedStill_a1')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedPageLoading')), findsNothing);
    },
  );

  testWidgets(
    'W-14.4c Settings round-trip keeps VerticalMediaFeed State; leave resets index',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await pumpAsyncWork(tester);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();
      expect(container.read(mainBrowseFeedIndexProvider), 1);
      final epochBefore = (await container.read(
        browseSessionProvider.future,
      )).roundEpoch;

      final stateBefore = tester.state(find.byType(VerticalMediaFeed));

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);
      await pumpAsyncWork(tester);

      final stateAfter = tester.state(find.byType(VerticalMediaFeed));
      expect(identical(stateBefore, stateAfter), isTrue);
      // Cap 14.4e: leave Browse resets queue/index; IndexedStack still keeps
      // VerticalMediaFeed State (14.4c keep-alive).
      expect(container.read(mainBrowseFeedIndexProvider), 0);
      final epochAfter = (await container.read(
        browseSessionProvider.future,
      )).roundEpoch;
      expect(epochAfter, greaterThan(epochBefore));
    },
  );

  testWidgets(
    'W-14.4c Settings round-trip from non-zero index does not show page failed',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await pumpAsyncWork(tester);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);
      await pumpAsyncWork(tester);

      expect(container.read(mainBrowseFeedIndexProvider), 0);
      expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsNothing);
      expect(
        find.byKey(const Key('mainBrowseFeedPageFailed'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-14.4c leave without Layer 1 is a neutral placeholder not failed or loading',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      display.previewErrorById['a1'] = 'iCloudDownloadRequired';
      display.displayGates['a1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await pumpAsyncWork(tester);

      expect(
        find.byKey(const Key('mainBrowseFeedPageFailed'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading'), skipOffstage: false),
        findsNothing,
      );
      display.displayGates['a1']!.complete();
    },
  );

  testWidgets(
    'W-14.4c off-current _startLoad does not promote to current when isCurrent flips mid-teardown',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      display.previewGates['a1'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      expect(display.previewCalls, isNotEmpty);

      final page = tester.state<MediaFeedPageState>(find.byType(MediaFeedPage));
      page.debugHoldOffCurrentTeardown = Completer<void>();

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);
      await pumpAsyncWork(tester);
      final previewsAfterReturn = display.previewCalls.length;

      page.debugHoldOffCurrentTeardown!.complete();
      page.debugHoldOffCurrentTeardown = null;
      await pumpAsyncWork(tester);
      expect(display.previewCalls.length, previewsAfterReturn);

      display.previewGates['a1']!.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('W-14.5 three items at 0 preheats +1 only', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1', 'a2', 'a3'],
        ),
        mediaDisplay: display,
      ),
    );
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    expect(display.previewCalls.toSet(), {ids[0], ids[1]});
    expect(display.previewCalls, isNot(contains(ids[2])));
    expect(display.displayCalls, [ids[0]]);
  });

  testWidgets('W-14.5 three items at 1 preheats both neighbours', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1', 'a2', 'a3'],
        ),
        mediaDisplay: display,
      ),
    );
    await pumpAsyncWork(tester);
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    expect(display.previewCalls.toSet(), {ids[0], ids[1], ids[2]});
    expect(display.displayCalls, [ids[0], ids[1]]);
  });

  testWidgets(
    'W-14.5 swipe 1→2 releases leaving id before new neighbour preview',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2', 'a3', 'a4'],
          ),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      expect(display.previewCalls, contains(ids[2]));

      display.releaseGate = Completer<void>();
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(display.releasePreviewCalls, contains(ids[0]));
      expect(display.previewCalls, isNot(contains(ids[3])));

      display.releaseGate!.complete();
      display.releaseGate = null;
      await pumpAsyncWork(tester);
      expect(display.previewCalls, contains(ids[3]));
      final releaseAt = display.previewLifecycleLog.indexOf(
        'release:${ids[0]}',
      );
      final previewAt = display.previewLifecycleLog.indexOf(
        'preview:${ids[3]}',
      );
      expect(releaseAt, greaterThanOrEqualTo(0));
      expect(previewAt, greaterThan(releaseAt));
    },
  );

  testWidgets('W-14.5 neighbour iCloud miss does not fail or start Layer 2', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.previewErrorById['a1'] = 'iCloudDownloadRequired';
    display.previewErrorById['a2'] = 'iCloudDownloadRequired';
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
      ),
    );
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    expect(find.byKey(const Key('mainBrowseFeedPageFailed')), findsNothing);
    expect(
      find.byKey(const Key('mainBrowseFeedPageFailed'), skipOffstage: false),
      findsNothing,
    );
    expect(display.displayCalls, [ids[0]]);
    expect(display.displayCalls, isNot(contains(ids[1])));
  });

  testWidgets(
    'W-14.5 promoting a neighbour with Layer 1 skips preview and loads Layer 2',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final neighbor = ids[1];
      final previewsForNeighbor = display.previewCalls
          .where((id) => id == neighbor)
          .length;
      expect(previewsForNeighbor, greaterThan(0));

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(
        display.previewCalls.where((id) => id == neighbor).length,
        previewsForNeighbor,
      );
      expect(display.displayCalls, contains(neighbor));
    },
  );

  testWidgets(
    'W-14.5 promoting a neighbour mid-preheat does not race with the new current load',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final gateA1 = Completer<void>();
      final gateA2 = Completer<void>();
      display.previewGates['a1'] = gateA1;
      display.previewGates['a2'] = gateA2;
      display.previewsById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/preview_a1.jpg',
      );
      display.previewsById['a2'] = const DisplayAsset(
        assetIdentifier: 'a2',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/preview_a2.jpg',
      );
      display.displaysById['a1'] = const DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/full_a1.jpg',
      );
      display.displaysById['a2'] = const DisplayAsset(
        assetIdentifier: 'a2',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/full_a2.jpg',
      );
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final current = ids[0];
      final neighbor = ids[1];
      if (current == 'a1') {
        gateA1.complete();
      } else {
        gateA2.complete();
      }
      await pumpAsyncWork(tester);
      expect(display.previewCalls, contains(neighbor));
      final previewsForNeighbor = display.previewCalls
          .where((id) => id == neighbor)
          .length;

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pump();

      if (neighbor == 'a1') {
        gateA1.complete();
      } else {
        gateA2.complete();
      }
      await pumpAsyncWork(tester);

      // Cap 15.4: join neighbour Layer 1; do not issue a second preview.
      expect(
        display.previewCalls.where((id) => id == neighbor).length,
        previewsForNeighbor,
      );
      expect(display.displayCalls, contains(neighbor));

      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate(
          (w) =>
              w is MediaFeedPage &&
              w.assetIdentifier == neighbor &&
              w.isCurrent,
        ),
      );
      expect(
        page.debugMedia?.display?.localFilePath,
        '/tmp/full_$neighbor.jpg',
      );
      expect(page.debugMedia?.displayLayer, FeedDisplayLayer.full);
    },
  );

  testWidgets('W-15.4a promote joins neighbour preview; Layer 2 once', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
      ),
    );
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    final neighbor = ids[1];
    final previewsForNeighbor = display.previewCalls
        .where((id) => id == neighbor)
        .length;
    expect(previewsForNeighbor, greaterThan(0));

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(
      display.previewCalls.where((id) => id == neighbor).length,
      previewsForNeighbor,
    );
    expect(display.displayCalls.where((id) => id == neighbor).length, 1);
  });

  testWidgets('W-15.4b become-current begins activation once', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
      ),
    );
    await pumpAsyncWork(tester);
    final feed = tester.state<VerticalMediaFeedState>(
      find.byType(VerticalMediaFeed),
    );
    final begins = feed.debugActivationBeginCount;
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    expect(feed.debugActivationBeginCount, begins + 1);
  });

  testWidgets(
    'W-15.4d join then leave ±1 window releases preview and does not write',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final gateA1 = Completer<void>();
      final gateA2 = Completer<void>();
      final gateA3 = Completer<void>();
      final gateA4 = Completer<void>();
      display.previewGates['a1'] = gateA1;
      display.previewGates['a2'] = gateA2;
      display.previewGates['a3'] = gateA3;
      display.previewGates['a4'] = gateA4;
      for (final id in ['a1', 'a2', 'a3', 'a4']) {
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/preview_$id.jpg',
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2', 'a3', 'a4'],
          ),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final current = ids[0];
      final neighbor = ids[1];
      final currentGate = display.previewGates[current]!;
      currentGate.complete();
      await pumpAsyncWork(tester);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pump();
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(3);
      await pumpAsyncWork(tester);

      expect(display.releasePreviewCalls, contains(neighbor));
      display.previewGates[neighbor]!.complete();
      await pumpAsyncWork(tester);
      expect(display.displayCalls, isNot(contains(neighbor)));

      final neighborPages = find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == neighbor,
        skipOffstage: false,
      );
      if (neighborPages.evaluate().isNotEmpty) {
        final page = tester.state<MediaFeedPageState>(neighborPages);
        expect(
          page.debugMedia?.display?.localFilePath,
          isNot('/tmp/preview_$neighbor.jpg'),
        );
      }
    },
  );

  testWidgets('W-14.5 leave Browse does not keep preheating neighbours', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        mediaDisplay: display,
      ),
    );
    await pumpAsyncWork(tester);
    final n = display.previewCalls.length;
    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container
        .read(mainBrowseDestinationProvider.notifier)
        .select(MainBrowseDestination.settings);
    await pumpAsyncWork(tester);
    expect(display.previewCalls.length, n);
  });

  testWidgets('W-15.7a video keeps Layer 1 poster after surface ready', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.previewsById['v1'] = const DisplayAsset(
      assetIdentifier: 'v1',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: '/tmp/fake_preview_v1.jpg',
    );
    display.displayErrorById['v1'] = 'unsupportedMedia';
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await pumpAsyncWork(tester);

    expect(find.byKey(const Key('mainBrowseFeedStill_v1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
  });

  testWidgets(
    'W-15.7b leave current keeps poster Image State (not pendingVideo)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      // Cap 22.5: n=2 leave→last mounts bridge; pad so index 1 ≠ n-2.
      for (final id in const ['v1', 'v2', 'v3', 'v4', 'v5']) {
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: '/tmp/fake_preview_$id.jpg',
        );
      }
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['v1', 'v2', 'v3', 'v4', 'v5'],
          ),
          mediaDisplay: display,
          playback: playback,
          browseShuffleSeed: 0,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final leaving = ids[0];

      final still = find.byKey(
        Key('mainBrowseFeedStill_$leaving'),
        skipOffstage: false,
      );
      expect(still, findsOneWidget);
      final imageFinder = find.descendant(
        of: still,
        matching: find.byType(Image),
        skipOffstage: false,
      );
      expect(imageFinder, findsOneWidget);
      final stateBefore =
          (tester.element(imageFinder) as StatefulElement).state;

      playback.calls.clear();
      await tester.drag(find.byType(PageView), const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(container.read(mainBrowseFeedIndexProvider), 1);

      expect(
        find.byKey(
          Key('mainBrowseFeedVideoPending_$leaving'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      expect(still, findsOneWidget);
      expect(imageFinder, findsOneWidget);
      final stateAfter = (tester.element(imageFinder) as StatefulElement).state;
      expect(
        identical(stateBefore, stateAfter),
        isTrue,
        reason: 'leave-current must reuse Image State (peek poster)',
      );
      expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
      expect(
        playback.calls.where((c) => c == 'cancelInFlightPrepare:$leaving'),
        isNotEmpty,
      );

      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate(
          (w) =>
              w is MediaFeedPage &&
              w.assetIdentifier == leaving &&
              w.feedIndex == 0,
          skipOffstage: false,
        ),
      );
      expect(page.debugMedia?.kind, FeedPageMediaKind.video);
      expect(
        page.debugMedia?.display?.localFilePath,
        '/tmp/fake_preview_$leaving.jpg',
      );
    },
  );

  testWidgets('W-15.7c leave current without poster may become pendingVideo', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    for (final id in const ['v1', 'v2']) {
      display.previewErrorById[id] = 'iCloudDownloadRequired';
      display.displayErrorById[id] = 'unsupportedMedia';
    }
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    final leaving = ids[0];

    expect(find.byKey(Key('mainBrowseFeedStill_$leaving')), findsNothing);
    expect(find.byKey(Key('mainBrowseFeedVideo_$leaving')), findsOneWidget);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);

    expect(
      find.byKey(
        Key('mainBrowseFeedVideoPending_$leaving'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(Key('mainBrowseFeedStill_$leaving'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets(
    'W-15.7d neighbour Layer 1 must not flip off-current video+poster to still',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      for (final id in const ['v1', 'v2', 'v3', 'v4', 'v5']) {
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: '/tmp/fake_preview_$id.jpg',
        );
      }
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['v1', 'v2', 'v3', 'v4', 'v5'],
          ),
          mediaDisplay: display,
          playback: playback,
          browseShuffleSeed: 0,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final leaving = ids[0];

      final secondPreheat = Completer<void>();
      display.previewGates[leaving] = secondPreheat;
      display.previewGateAfterCall[leaving] =
          display.previewCalls.where((id) => id == leaving).length + 1;

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        display.previewCalls.where((id) => id == leaving).length,
        greaterThanOrEqualTo(display.previewGateAfterCall[leaving]!),
      );

      secondPreheat.complete();
      await pumpAsyncWork(tester);

      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate(
          (w) =>
              w is MediaFeedPage &&
              w.assetIdentifier == leaving &&
              w.feedIndex == 0,
          skipOffstage: false,
        ),
      );
      expect(page.debugMedia?.kind, FeedPageMediaKind.video);
      expect(
        page.debugMedia?.display?.localFilePath,
        '/tmp/fake_preview_$leaving.jpg',
      );
    },
  );

  testWidgets(
    'W-15.10a still revisit skips second L2 display via Session token',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      // Cap 15.13 lookup() existsSync — Session cover paths must be real files.
      for (final id in const ['a1', 'a2', 'a3']) {
        final path = File('${Directory.systemTemp.path}/wt_15_10a_$id.png');
        path.writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          ),
        );
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1', 'a2', 'a3'],
          ),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      await pumpAsyncWork(tester);
      expect(display.displayCalls.where((id) => id == head).length, 1);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(container.read(browseL2ReadySessionProvider)[head], isNotNull);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);
      expect(container.read(browseL2ReadySessionProvider)[head], isNotNull);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await pumpAsyncWork(tester);
      expect(display.displayCalls.where((id) => id == head).length, 1);
    },
  );

  testWidgets(
    'W-15.10b leave during in-flight L2 does not mint Session token',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final gateA = Completer<void>();
      final gateB = Completer<void>();
      display.displayGates['a1'] = gateA;
      display.displayGates['a2'] = gateB;
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(container.read(browseL2ReadySessionProvider)[head], isNull);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);
      expect(container.read(browseL2ReadySessionProvider)[head], isNull);

      gateA.complete();
      gateB.complete();
      await pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-15.10c video revisit fast path keeps poster without L1 loading gate',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      for (final id in const ['v1', 'v2']) {
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: '/tmp/fake_preview_$id.jpg',
        );
      }
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      await pumpAsyncWork(tester);
      expect(playback.calls.any((c) => c.startsWith('load:')), isTrue);

      final previewsBefore = display.previewCalls
          .where((id) => id == head)
          .length;

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(
        container.read(browseL2ReadySessionProvider)[head]?.kind,
        FeedL2ReadyKind.video,
      );

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await pumpAsyncWork(tester);

      // Neighbour preheat may add previews; become-current fast path must not
      // open the full-page L1 loading gate.
      expect(
        display.previewCalls.where((id) => id == head).length,
        greaterThanOrEqualTo(previewsBefore),
      );
      expect(
        find.byKey(Key('mainBrowseFeedStill_$head'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-15.12a Photos-tab deviceLocal still skips preview on first visit',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          browseLayer2Dwell: const Duration(milliseconds: 300),
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(display.previewCalls.where((id) => id == head), isEmpty);
      expect(display.displayCalls.where((id) => id == head).length, 1);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-15.12h All-tab deviceLocal still probes preview but skips blur gate',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['still1', 'still2'],
            availabilityById: const {
              'still1': AssetAvailability.deviceLocal,
              'still2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(display.previewCalls.where((id) => id == head).length, 1);
      expect(display.displayCalls.where((id) => id == head).length, 1);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(Key('mainBrowseFeedStill_$head'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-15.12b iCloud asset still uses Layer 1 preview on first visit',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['cloud1', 'a2'],
            availabilityById: const {
              'cloud1': AssetAvailability.iCloudNotDownloaded,
            },
          ),
          mediaDisplay: display,
        ),
      );
      await pumpAsyncWork(tester);
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(display.previewCalls.where((id) => id == head).length, 1);
    },
  );

  testWidgets(
    'W-15.12c video deviceLocal first visit keeps poster not L1 loading gate',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      for (final id in const ['v1', 'v2']) {
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: '/tmp/fake_preview_$id.jpg',
        );
      }
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            videosIds: const ['v1', 'v2'],
            availabilityById: const {
              'v1': AssetAvailability.deviceLocal,
              'v2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await pumpAsyncWork(tester);
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(display.previewCalls.where((id) => id == head).length, 1);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading'), skipOffstage: false),
        findsNothing,
      );
      expect(playback.calls.where((c) => c == 'load:$head').length, 1);
    },
  );

  testWidgets(
    'W-15.12d false positive local fast path falls back to full L1 without token',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = _FailOnceDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(display.previewCalls.where((id) => id == head).length, 1);
      expect(display.displayCalls.where((id) => id == head).length, 2);
      expect(container.read(browseL2ReadySessionProvider)[head], isNotNull);
    },
  );

  testWidgets(
    'W-15.12i false-positive fallback waits production dwell before retry L2',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = _FailOnceDisplayRepository();
      final gate = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          browseLayer2Dwell: const Duration(milliseconds: 300),
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      // Short pumps: first L2 fails; install gate before production dwell
      // (300 ms) elapses so the fallback attempt cannot complete early.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];
      display.displayGates[head] = gate;

      // Fast-path L2 failed (1st display). Fallback re-arms 300 ms dwell;
      // 2nd display must not start until dwell elapses.
      expect(display.displayCalls.where((id) => id == head).length, 1);

      await tester.pump(const Duration(milliseconds: 300));
      // Gated: second attempt may have started but must not complete.
      expect(
        display.displayCalls.where((id) => id == head).length,
        lessThan(3),
      );

      gate.complete();
      await pumpAsyncWork(tester);
      expect(display.displayCalls.where((id) => id == head).length, 2);
    },
  );

  testWidgets(
    'W-15.12e Session L2-ready beats deviceLocal first-visit fast path',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      for (final id in const ['a1', 'a2', 'a3']) {
        final path = File('${Directory.systemTemp.path}/wt_15_12e_$id.png');
        path.writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          ),
        );
        display.displaysById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2', 'a3'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
              'a3': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];
      expect(display.displayCalls.where((id) => id == head).length, 1);

      expect(container.read(browseL2ReadySessionProvider)[head], isNotNull);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await pumpAsyncWork(tester);
      expect(display.displayCalls.where((id) => id == head).length, 1);
    },
  );

  testWidgets(
    'W-15.12f leave before N_local issues zero Layer 2 display invoke',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          browseLocalFirstVisitDwell: const Duration(milliseconds: 500),
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];
      final gate = Completer<void>();
      display.displayGates[head] = gate;

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(display.displayCalls.where((id) => id == head), isEmpty);
      gate.complete();
      await pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-15.12g leave after N_local during in-flight L2 cancels display',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final gate = Completer<void>();
      for (final id in const ['a1', 'a2', 'a3', 'a4', 'a5']) {
        display.displayGates[id] = gate;
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          // Cap 22.5: pad past n=2 so leave 0→1 does not mount bridge.
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2', 'a3', 'a4', 'a5'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
              'a3': AssetAvailability.deviceLocal,
              'a4': AssetAvailability.deviceLocal,
              'a5': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          browseShuffleSeed: 0,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];
      expect(display.displayCalls.where((id) => id == head).length, 1);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(display.cancelDisplayCalls.where((id) => id == head).length, 1);
      gate.complete();
      await pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-15.12j deviceLocal fast path keeps peek cover painted until L2 lands',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            photosIds: const ['a1', 'a2'],
            availabilityById: const {
              'a1': AssetAvailability.deviceLocal,
              'a2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      // Neighbour preheat paints a Layer 1 cover on the not-yet-current page.
      expect(display.previewCalls.where((id) => id == target).length, 1);
      expect(
        find.byKey(Key('mainBrowseFeedStill_$target'), skipOffstage: false),
        findsOneWidget,
      );

      // Hold Layer 2 so the become-current window stays observable.
      final l2Gate = Completer<void>();
      display.displayGates[target] = l2Gate;
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(
        display.displayCalls.where((id) => id == target).length,
        1,
        reason: 'fast path must have reached Layer 2 for this assertion window',
      );
      expect(
        find.byKey(Key('mainBrowseFeedStill_$target'), skipOffstage: false),
        findsOneWidget,
        reason: 'blanking the peek cover paints an empty frame at settle',
      );
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading'), skipOffstage: false),
        findsNothing,
      );

      l2Gate.complete();
      await pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-15.15a become-current probes getAssetAvailabilities when resolve map empty',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final sources = FakeAssetSourceRepository(
        photosIds: const ['a1', 'a2'],
        availabilityById: const {
          'a1': AssetAvailability.deviceLocal,
          'a2': AssetAvailability.deviceLocal,
        },
      )..resolveOmitsAvailability = true;
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: sources,
          mediaDisplay: display,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(sources.getAssetAvailabilitiesCalls, greaterThanOrEqualTo(1));
      expect(
        sources.getAssetAvailabilitiesHistory.any(
          (call) => call.length == 1 && call.single == head,
        ),
        isTrue,
        reason: 'probe must request the current id only',
      );
      expect(display.previewCalls.where((id) => id == head), isEmpty);
      expect(display.displayCalls.where((id) => id == head).length, 1);
    },
  );

  testWidgets(
    'W-15.15b probe miss (iCloud) does not take deviceLocal fast path',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final sources = FakeAssetSourceRepository(
        photosIds: const ['cloud1', 'a2'],
        availabilityById: const {
          'cloud1': AssetAvailability.iCloudNotDownloaded,
          'a2': AssetAvailability.deviceLocal,
        },
      )..resolveOmitsAvailability = true;
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: sources,
          mediaDisplay: display,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      expect(sources.getAssetAvailabilitiesCalls, greaterThanOrEqualTo(1));
      expect(display.previewCalls.where((id) => id == head).length, 1);
    },
  );

  testWidgets(
    'W-15.14a STILL→VIDEO promote reuses peek cover without second requestPreview',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository();
      final paths = <String, String>{};
      for (final id in const ['v1', 'v2']) {
        final path = File('${Directory.systemTemp.path}/wt_15_14_$id.png');
        path.writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          ),
        );
        paths[id] = path.path;
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            videosIds: const ['v1', 'v2'],
            availabilityById: const {
              'v1': AssetAvailability.deviceLocal,
              'v2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          playback: playback,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      // Neighbour preheat paints Layer 1 once.
      expect(display.previewCalls.where((id) => id == target).length, 1);
      final still = find.byKey(
        Key('mainBrowseFeedStill_$target'),
        skipOffstage: false,
      );
      expect(still, findsOneWidget);
      // Off-current PageView children may not layout LayoutBuilder → no Image
      // yet. Identity target is _ReloadableFileImage State (same as diag).
      final stateBefore = _reloadableFileImageState(tester, still);

      // Hold L2 prepare so STILL→VIDEO promote window stays observable.
      final loadGate = Completer<void>();
      playback.loadGates[target] = loadGate;
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(
        display.previewCalls.where((id) => id == target).length,
        1,
        reason: 'deviceLocal promote must not re-requestPreview (15.14 / 1A)',
      );
      expect(still, findsOneWidget);
      final stateAfter = _reloadableFileImageState(tester, still);
      expect(
        identical(stateBefore, stateAfter),
        isTrue,
        reason: 'STILL→VIDEO must reuse Image State (15.14 / 4A+5A)',
      );
      final page = tester.state<MediaFeedPageState>(
        find.byWidgetPredicate(
          (w) => w is MediaFeedPage && w.assetIdentifier == target,
          skipOffstage: false,
        ),
      );
      expect(page.debugMedia?.kind, FeedPageMediaKind.video);
      expect(page.debugMedia?.display?.localFilePath, paths[target]);

      loadGate.complete();
      await pumpAsyncWork(tester);
    },
  );

  testWidgets(
    'W-15.14b revisit L2 apply arms poster-hold before video slot mounts',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 7;
      for (final id in const ['v1', 'v2']) {
        final path = File('${Directory.systemTemp.path}/wt_15_14b_$id.png');
        path.writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          ),
        );
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            videosIds: const ['v1', 'v2'],
            availabilityById: const {
              'v1': AssetAvailability.deviceLocal,
              'v2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          playback: playback,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      final loadGate = Completer<void>();
      playback.loadGates[target] = loadGate;
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      final pageFinder = find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == target,
      );
      final page = tester.state<MediaFeedPageState>(pageFinder);
      expect(page.debugHoldPosterUntilFirstFrame, isFalse);

      loadGate.complete();
      await pumpAsyncWork(tester);

      expect(page.debugHoldPosterUntilFirstFrame, isTrue);
      final opacityFinder = find.byKey(Key('feedVideoOpacity_$target'));
      expect(opacityFinder, findsOneWidget);
      expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);
    },
  );

  testWidgets(
    'W-15.14c dead peek file still arms poster-hold at DEVICE_LOCAL L2 apply',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 9;
      final paths = <String, File>{};
      for (final id in const ['v1', 'v2']) {
        final path = File('${Directory.systemTemp.path}/wt_15_14c_$id.png');
        path.writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
          ),
        );
        paths[id] = path;
        display.displayErrorById[id] = 'unsupportedMedia';
        display.previewsById[id] = DisplayAsset(
          assetIdentifier: id,
          mediaKind: PlaybackMediaKind.video,
          localFilePath: path.path,
        );
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            videosIds: const ['v1', 'v2'],
            availabilityById: const {
              'v1': AssetAvailability.deviceLocal,
              'v2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          playback: playback,
          browseLayer2Dwell: Duration.zero,
        ),
      );
      await tester.pump();
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await pumpAsyncWork(tester);
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      // Neighbour preheat paints peek cover once.
      expect(display.previewCalls.where((id) => id == target).length, 1);
      // Evict on-disk preview while page still holds the path (canReuseCover=false).
      expect(paths[target]!.existsSync(), isTrue);
      paths[target]!.deleteSync();
      expect(paths[target]!.existsSync(), isFalse);

      final loadGate = Completer<void>();
      playback.loadGates[target] = loadGate;
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(
        display.previewCalls.where((id) => id == target).length,
        2,
        reason: 'dead peek must re-requestPreview (canReuseCover=false)',
      );
      final pageFinder = find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == target,
      );
      final page = tester.state<MediaFeedPageState>(pageFinder);
      expect(page.debugHoldPosterUntilFirstFrame, isFalse);

      loadGate.complete();
      await pumpAsyncWork(tester);

      expect(
        page.debugHoldPosterUntilFirstFrame,
        isTrue,
        reason:
            '15.14c: DEVICE_LOCAL APPLY arms hold even when cover file gone',
      );
      final opacityFinder = find.byKey(Key('feedVideoOpacity_$target'));
      expect(opacityFinder, findsOneWidget);
      expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);
    },
  );

  testWidgets(
    'W-15.11a scroll offset arms guard without cover on peek target page',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 2;
      await _pumpTwoVideoPosterFeed(
        tester,
        display: display,
        playback: playback,
      );
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      _seedPvHandoffSnapshots(container, ids);
      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final pageController = feedState.debugPageController!;
      pageController.jumpTo(pageController.position.viewportDimension * 0.35);
      await tester.pump();
      expect(pageController.page, greaterThan(0.02));
      feedState.debugDispatchPvScrollArm(0);
      await pumpAsyncWork(tester);

      expect(
        container.read(pvTransitionGuardProvider).isCovering(target),
        isTrue,
      );
      expect(
        find.byKey(Key('pvTransitionCover_$target'), skipOffstage: false),
        findsNothing,
      );
      await container.read(pvTransitionGuardProvider.notifier).disarm();
    },
  );

  testWidgets(
    'W-15.11b arm suppresses audio and ack clears cover plus suppress',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 4;
      await _pumpTwoVideoPosterFeed(
        tester,
        display: display,
        playback: playback,
      );
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      _seedPvHandoffSnapshots(container, ids);
      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final gate = feedState.debugCurrentDisplayGate;
      await container
          .read(pvTransitionGuardProvider.notifier)
          .tryArmOnScroll(
            currentFeedIndex: 0,
            targetFeedIndex: 1,
            sourceAssetId: ids[0],
            targetAssetId: target,
            displayGeneration: gate.generation,
            displayGate: gate,
          );
      await pumpAsyncWork(tester);

      expect(playback.transitionAudioSuppressed, isTrue);
      final guard = container.read(pvTransitionGuardProvider);
      // Attach alone must NOT unwrap (15.11b).
      playback.emitSurfaceAttached(
        PlaybackSurfaceAttachedEvent(
          assetIdentifier: guard.targetAssetId!,
          feedIndex: guard.targetFeedIndex!,
          clearEpoch: guard.armPoolEpoch!,
        ),
      );
      await pumpAsyncWork(tester);
      expect(playback.transitionAudioSuppressed, isTrue);
      expect(
        container.read(pvTransitionGuardProvider).targetAssetId,
        isNotNull,
      );

      playback.emitSurfaceReadyForDisplay(
        PlaybackSurfaceReadyForDisplayEvent(
          assetIdentifier: guard.targetAssetId!,
          feedIndex: guard.targetFeedIndex!,
          clearEpoch: guard.armPoolEpoch!,
        ),
      );
      await pumpAsyncWork(tester);
      expect(playback.transitionAudioSuppressed, isFalse);
      expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);
      expect(
        find.byKey(Key('pvTransitionCover_$target'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  test('W-15.11c stale attach-ack does not unwrap guard', () async {
    final playback = FakePlaybackRepository()..playbackPoolEpoch = 5;
    final container = ProviderContainer(
      overrides: [playbackRepositoryProvider.overrideWithValue(playback)],
    );
    addTearDown(container.dispose);
    final gate = FeedMediaRequestGate();
    final generation = gate.generation;
    final notifier = container.read(pvTransitionGuardProvider.notifier);
    notifier.updatePageSnapshot(
      'v1',
      const PvHandoffPageSnapshot(
        isVideoWithPoster: true,
        isCurrentSurfaceReady: true,
        posterPath: '/tmp/v1.jpg',
      ),
    );
    notifier.updatePageSnapshot(
      'v2',
      const PvHandoffPageSnapshot(
        isVideoWithPoster: true,
        posterPath: '/tmp/v2.jpg',
      ),
    );
    await notifier.tryArmOnScroll(
      currentFeedIndex: 0,
      targetFeedIndex: 1,
      sourceAssetId: 'v1',
      targetAssetId: 'v2',
      displayGeneration: generation,
      displayGate: gate,
    );
    expect(container.read(pvTransitionGuardProvider).targetAssetId, 'v2');

    playback.emitSurfaceReadyForDisplay(
      const PlaybackSurfaceReadyForDisplayEvent(
        assetIdentifier: 'wrong-id',
        feedIndex: 1,
        clearEpoch: 5,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pvTransitionGuardProvider).targetAssetId, 'v2');

    playback.emitSurfaceReadyForDisplay(
      const PlaybackSurfaceReadyForDisplayEvent(
        assetIdentifier: 'v2',
        feedIndex: 1,
        clearEpoch: 99,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pvTransitionGuardProvider).targetAssetId, 'v2');

    // User settled on an unrelated index → disarm clears target before ack.
    notifier.onFeedIndexChanged(2);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);

    playback.emitSurfaceReadyForDisplay(
      const PlaybackSurfaceReadyForDisplayEvent(
        assetIdentifier: 'v2',
        feedIndex: 1,
        clearEpoch: 5,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);
  });

  test(
    'W-15.11h ready-for-display triple match matches attach-ack trust model',
    () async {
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 5;
      final container = ProviderContainer(
        overrides: [playbackRepositoryProvider.overrideWithValue(playback)],
      );
      addTearDown(container.dispose);
      final gate = FeedMediaRequestGate();
      final generation = gate.generation;
      final notifier = container.read(pvTransitionGuardProvider.notifier);
      notifier.updatePageSnapshot(
        'v1',
        const PvHandoffPageSnapshot(
          isVideoWithPoster: true,
          isCurrentSurfaceReady: true,
          posterPath: '/tmp/v1.jpg',
        ),
      );
      notifier.updatePageSnapshot(
        'v2',
        const PvHandoffPageSnapshot(
          isVideoWithPoster: true,
          posterPath: '/tmp/v2.jpg',
        ),
      );
      await notifier.tryArmOnScroll(
        currentFeedIndex: 0,
        targetFeedIndex: 1,
        sourceAssetId: 'v1',
        targetAssetId: 'v2',
        displayGeneration: generation,
        displayGate: gate,
      );
      expect(playback.transitionAudioSuppressed, isTrue);

      // Wrong index — same gate as former attach-ack.
      playback.emitSurfaceReadyForDisplay(
        const PlaybackSurfaceReadyForDisplayEvent(
          assetIdentifier: 'v2',
          feedIndex: 0,
          clearEpoch: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pvTransitionGuardProvider).targetAssetId, 'v2');
      expect(playback.transitionAudioSuppressed, isTrue);

      // Matching triple unwraps.
      playback.emitSurfaceReadyForDisplay(
        const PlaybackSurfaceReadyForDisplayEvent(
          assetIdentifier: 'v2',
          feedIndex: 1,
          clearEpoch: 5,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);
      expect(playback.transitionAudioSuppressed, isFalse);
    },
  );

  testWidgets(
    'W-15.11i poster hold Opacity hide keeps same Image State (identical)',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 3;
      await _pumpTwoVideoPosterFeed(
        tester,
        display: display,
        playback: playback,
      );
      final ids = await _feedOrderedIds(tester);
      final head = ids[0];

      final pageFinder = find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == head && w.isCurrent,
      );
      final page = tester.state<MediaFeedPageState>(pageFinder);
      expect(page.debugHoldPosterUntilFirstFrame, isTrue);
      expect(page.debugHoldPoolEpoch, 3);

      final opacityFinder = find.byKey(Key('feedVideoOpacity_$head'));
      expect(opacityFinder, findsOneWidget);
      expect(tester.widget<Opacity>(opacityFinder).opacity, 0.0);

      final still = find.byKey(Key('mainBrowseFeedStill_$head'));
      expect(still, findsOneWidget);
      final imageFinder = find.descendant(
        of: still,
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);
      final stateBefore =
          (tester.element(imageFinder) as StatefulElement).state;

      playback.emitSurfaceReadyForDisplay(
        PlaybackSurfaceReadyForDisplayEvent(
          assetIdentifier: head,
          feedIndex: page.widget.feedIndex,
          clearEpoch: page.debugHoldPoolEpoch!,
        ),
      );
      await pumpAsyncWork(tester);

      expect(page.debugHoldPosterUntilFirstFrame, isFalse);
      expect(tester.widget<Opacity>(opacityFinder).opacity, 1.0);
      expect(imageFinder, findsOneWidget);
      final stateAfter = (tester.element(imageFinder) as StatefulElement).state;
      expect(
        identical(stateBefore, stateAfter),
        isTrue,
        reason: 'hold↔ready must not reorder Stack; poster Image State stays',
      );
    },
  );

  testWidgets('W-15.11d timeout and manual disarm unmute without attach-ack', (
    tester,
  ) async {
    final display = FakeMediaDisplayRepository();
    final playback = FakePlaybackRepository();
    await _pumpTwoVideoPosterFeed(tester, display: display, playback: playback);

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    final ids = await _feedOrderedIds(tester);
    _seedPvHandoffSnapshots(container, ids);
    final feedState = tester.state<VerticalMediaFeedState>(
      find.byType(VerticalMediaFeed),
    );
    final gate = feedState.debugCurrentDisplayGate;
    await container
        .read(pvTransitionGuardProvider.notifier)
        .tryArmOnScroll(
          currentFeedIndex: 0,
          targetFeedIndex: 1,
          sourceAssetId: ids[0],
          targetAssetId: ids[1],
          displayGeneration: gate.generation,
          displayGate: gate,
        );
    await pumpAsyncWork(tester);
    expect(playback.transitionAudioSuppressed, isTrue);

    await container.read(pvTransitionGuardProvider.notifier).disarm();
    await pumpAsyncWork(tester);
    expect(playback.transitionAudioSuppressed, isFalse);

    _seedPvHandoffSnapshots(container, ids);
    await container
        .read(pvTransitionGuardProvider.notifier)
        .tryArmOnScroll(
          currentFeedIndex: 0,
          targetFeedIndex: 1,
          sourceAssetId: ids[0],
          targetAssetId: ids[1],
          displayGeneration: gate.generation,
          displayGate: gate,
        );
    await pumpAsyncWork(tester);
    expect(playback.transitionAudioSuppressed, isTrue);

    await tester.pump(const Duration(seconds: 2));
    await pumpAsyncWork(tester);
    expect(playback.transitionAudioSuppressed, isFalse);
  });

  testWidgets(
    'W-15.11f scroll-back settle triggers maybeDisarmOnSettled and unmutes',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository();
      await _pumpTwoVideoPosterFeed(
        tester,
        display: display,
        playback: playback,
      );

      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      _seedPvHandoffSnapshots(container, ids);
      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final pageController = feedState.debugPageController!;

      pageController.jumpTo(pageController.position.viewportDimension * 0.35);
      await tester.pump();
      feedState.debugDispatchPvScrollArm(0);
      await pumpAsyncWork(tester);

      expect(playback.transitionAudioSuppressed, isTrue);
      expect(container.read(pvTransitionGuardProvider).targetFeedIndex, 1);
      expect(
        find.byKey(Key('pvTransitionCover_$target'), skipOffstage: false),
        findsNothing,
      );

      pageController.jumpTo(0);
      await tester.pump();
      expect(pageController.page!.abs(), lessThan(0.02));
      feedState.debugDispatchPvScrollSettled(0);
      await pumpAsyncWork(tester);

      expect(playback.transitionAudioSuppressed, isFalse);
      expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);
      expect(
        find.byKey(Key('pvTransitionCover_$target'), skipOffstage: false),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-15.11g settle-on-target releases covering; audio waits for ready',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository()..playbackPoolEpoch = 6;
      await _pumpTwoVideoPosterFeed(
        tester,
        display: display,
        playback: playback,
      );
      final ids = await _feedOrderedIds(tester);
      final target = ids[1];

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      _seedPvHandoffSnapshots(container, ids);
      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final gate = feedState.debugCurrentDisplayGate;
      await container
          .read(pvTransitionGuardProvider.notifier)
          .tryArmOnScroll(
            currentFeedIndex: 0,
            targetFeedIndex: 1,
            sourceAssetId: ids[0],
            targetAssetId: target,
            displayGeneration: gate.generation,
            displayGate: gate,
          );
      await pumpAsyncWork(tester);
      expect(playback.transitionAudioSuppressed, isTrue);

      // Capture triple before covering release clears armed state.
      final armed = container.read(pvTransitionGuardProvider);
      final readyAsset = armed.targetAssetId!;
      final readyIdx = armed.targetFeedIndex!;
      final readyEpoch = armed.armPoolEpoch!;

      // True feed-index commit (same path as _activateCurrentItem) — not
      // near-settled ScrollUpdate.
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await pumpAsyncWork(tester);

      expect(
        container.read(pvTransitionGuardProvider).isCovering(target),
        isFalse,
      );
      expect(playback.transitionAudioSuppressed, isTrue);
      expect(
        find.byKey(Key('mainBrowseFeedVideo_$target'), skipOffstage: false),
        findsOneWidget,
      );
      final pageFinder = find.byWidgetPredicate(
        (w) => w is MediaFeedPage && w.assetIdentifier == target && w.isCurrent,
      );
      expect(
        tester
            .state<MediaFeedPageState>(pageFinder)
            .debugHoldPosterUntilFirstFrame,
        isTrue,
      );

      playback.emitSurfaceReadyForDisplay(
        PlaybackSurfaceReadyForDisplayEvent(
          assetIdentifier: readyAsset,
          feedIndex: readyIdx,
          clearEpoch: readyEpoch,
        ),
      );
      await pumpAsyncWork(tester);

      expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);
      expect(playback.transitionAudioSuppressed, isFalse);
      expect(
        find.byKey(Key('mainBrowseFeedVideo_$target'), skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('W-15.11j stale post-settle ScrollUpdate does not re-arm guard', (
    tester,
  ) async {
    final display = FakeMediaDisplayRepository();
    final playback = FakePlaybackRepository()..playbackPoolEpoch = 7;
    await _pumpTwoVideoPosterFeed(tester, display: display, playback: playback);
    final ids = await _feedOrderedIds(tester);
    final target = ids[1];

    final element = tester.element(find.byType(VerticalMediaFeed));
    final container = ProviderScope.containerOf(element);
    _seedPvHandoffSnapshots(container, ids);
    final feedState = tester.state<VerticalMediaFeedState>(
      find.byType(VerticalMediaFeed),
    );
    final gate = feedState.debugCurrentDisplayGate;

    await container
        .read(pvTransitionGuardProvider.notifier)
        .tryArmOnScroll(
          currentFeedIndex: 0,
          targetFeedIndex: 1,
          sourceAssetId: ids[0],
          targetAssetId: target,
          displayGeneration: gate.generation,
          displayGate: gate,
        );
    await pumpAsyncWork(tester);
    expect(
      container.read(pvTransitionGuardProvider).isCovering(target),
      isTrue,
    );

    // Settle: releaseCovering (same path as device feed-index commit).
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await pumpAsyncWork(tester);
    expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);

    // Device race: ScrollUpdate still carries pre-settle curIdx=0 → tgt=1.
    // Defensive: tryArmOnScroll must refuse target-is-current.
    await container
        .read(pvTransitionGuardProvider.notifier)
        .tryArmOnScroll(
          currentFeedIndex: 0,
          targetFeedIndex: 1,
          sourceAssetId: ids[0],
          targetAssetId: target,
          displayGeneration: gate.generation,
          displayGate: gate,
        );
    await pumpAsyncWork(tester);
    expect(
      container.read(pvTransitionGuardProvider).targetAssetId,
      isNull,
      reason: 'stale tryArm args must not re-cover after settle',
    );

    // Root-cause path: page already on settled index; live feedIndex read
    // must not treat a stale dispatch arg as curIdx and re-arm.
    final pageController = feedState.debugPageController!;
    pageController.jumpToPage(1);
    await tester.pump();
    feedState.debugDispatchPvScrollArm(0);
    await pumpAsyncWork(tester);
    expect(
      container.read(pvTransitionGuardProvider).targetAssetId,
      isNull,
      reason: 'live feedIndex must ignore stale scroll dispatch',
    );
    expect(
      find.byKey(Key('pvTransitionCover_$target'), skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets(
    'W-15.11e video without poster does not arm transition guard on scroll',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      final playback = FakePlaybackRepository();
      for (final id in const ['v1', 'v2']) {
        display.previewErrorById[id] = 'iCloudDownloadRequired';
        display.displayErrorById[id] = 'unsupportedMedia';
      }
      await tester.pumpWidget(
        permissionUiHarness(
          disableBrowseAllPrefetch: true,
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await pumpAsyncWork(tester);
      await _feedOrderedIds(tester);
      await pumpAsyncWork(tester);

      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final pageController = feedState.debugPageController!;
      pageController.jumpTo(pageController.position.viewportDimension * 0.35);
      await tester.pump();
      feedState.debugDispatchPvScrollArm(0);
      await pumpAsyncWork(tester);

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      expect(container.read(pvTransitionGuardProvider).targetAssetId, isNull);
      expect(playback.transitionAudioSuppressed, isFalse);
      expect(find.byKey(const Key('pvTransitionCover_v2')), findsNothing);
    },
  );

  testWidgets('W-18.3-F1 A→B→A emits nav intent before play on return', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    for (final id in const ['v1', 'v2']) {
      display.displayErrorById[id] = 'unsupportedMedia';
      display.previewsById[id] = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.video,
        localFilePath: '/tmp/fake_preview_$id.jpg',
      );
    }
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
        mediaDisplay: display,
        playback: playback,
        browseShuffleSeed: 0,
      ),
    );
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[0]}')), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -280));
    await pumpAsyncWork(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[1]}')), findsOneWidget);

    playback.calls.clear();
    playback.intentCalls.clear();

    await tester.drag(find.byType(PageView), const Offset(0, 280));
    await pumpAsyncWork(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[0]}')), findsOneWidget);

    final returnIntent = playback.intentCalls.firstWhere(
      (intent) => intent.assetIdentifier == ids[0],
    );
    expect(returnIntent.startsNewNavigationActivation, isTrue);
    expect(returnIntent.wantsPlay, isTrue);
    final navIntentCall = playback.calls.firstWhere(
      (c) =>
          c.startsWith('setPlaybackIntent:${ids[0]}') && c.contains('nav=true'),
    );
    final playIdx = playback.calls.lastIndexOf('play');
    expect(playback.calls.indexOf(navIntentCall), lessThan(playIdx));
  });

  testWidgets('W-18.3-F2 inactive→resumed auto-plays when intent preserved', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['v1'] = 'unsupportedMedia';
    display.previewsById['v1'] = const DisplayAsset(
      assetIdentifier: 'v1',
      mediaKind: PlaybackMediaKind.video,
      localFilePath: '/tmp/fake_preview_v1.jpg',
    );
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
    expect(playback.calls.where((c) => c == 'play'), isNotEmpty);

    playback.calls.clear();
    playback.intentCalls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pumpAsyncWork(tester);
    expect(
      playback.intentCalls.any(
        (intent) =>
            intent.wantsPlay == true &&
            intent.clearsPendingNavigationActivation == true,
      ),
      isTrue,
    );
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);

    playback.calls.clear();
    playback.intentCalls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpAsyncWork(tester);

    expect(
      playback.intentCalls.any((intent) => intent.wantsPlay == true),
      isTrue,
    );
    expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
  });

  testWidgets('W-18.4-F1 L2-ready video tap pauses and shows affordance', (
    tester,
  ) async {
    final playback = await _pumpSingleVideoFeed(tester);
    expect(
      find.byKey(const Key('mainBrowsePlaybackTapTarget')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('mainBrowseCenterPlayAffordance')),
      findsNothing,
    );

    playback.calls.clear();
    playback.intentCalls.clear();
    await tester.tap(find.byKey(const Key('mainBrowsePlaybackTapTarget')));
    await pumpAsyncWork(tester);

    expect(
      playback.intentCalls.any(
        (i) =>
            i.wantsPlay == false &&
            i.startsNewNavigationActivation == false &&
            i.clearsPendingNavigationActivation == false,
      ),
      isTrue,
    );
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
    expect(
      find.byKey(const Key('mainBrowseCenterPlayAffordance')),
      findsOneWidget,
    );
  });

  testWidgets('W-18.4-F2 affordance tap resumes and hides affordance', (
    tester,
  ) async {
    final playback = await _pumpSingleVideoFeed(tester);
    await tester.tap(find.byKey(const Key('mainBrowsePlaybackTapTarget')));
    await pumpAsyncWork(tester);
    expect(
      find.byKey(const Key('mainBrowseCenterPlayAffordance')),
      findsOneWidget,
    );

    playback.calls.clear();
    playback.intentCalls.clear();
    await tester.tap(find.byKey(const Key('mainBrowsePlaybackTapTarget')));
    await pumpAsyncWork(tester);

    expect(
      playback.intentCalls.any(
        (i) => i.wantsPlay == true && i.startsNewNavigationActivation == false,
      ),
      isTrue,
    );
    expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
    expect(
      find.byKey(const Key('mainBrowseCenterPlayAffordance')),
      findsNothing,
    );
  });

  testWidgets(
    'W-18.4-F3 inactive→resumed auto-plays without center affordance',
    (tester) async {
      final playback = await _pumpSingleVideoFeed(tester);
      expect(playback.calls.where((c) => c == 'play'), isNotEmpty);

      playback.calls.clear();
      playback.intentCalls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpAsyncWork(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpAsyncWork(tester);

      expect(playback.intentCalls.any((i) => i.wantsPlay == true), isTrue);
      expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
      expect(
        find.byKey(const Key('mainBrowseCenterPlayAffordance')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'W-18.4-F3b tap pause before inactive stays paused after resume',
    (tester) async {
      final playback = await _pumpSingleVideoFeed(tester);
      await tester.tap(find.byKey(const Key('mainBrowsePlaybackTapTarget')));
      await pumpAsyncWork(tester);
      expect(
        find.byKey(const Key('mainBrowseCenterPlayAffordance')),
        findsOneWidget,
      );

      playback.calls.clear();
      playback.intentCalls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpAsyncWork(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pumpAsyncWork(tester);

      expect(playback.calls.where((c) => c == 'play'), isEmpty);
      expect(
        find.byKey(const Key('mainBrowseCenterPlayAffordance')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-18.4-E1 epoch-only didUpdateWidget triggers foreground resume sync',
    (tester) async {
      final playback = await _pumpSingleVideoFeed(tester);
      expect(playback.calls.where((c) => c == 'play'), isNotEmpty);

      playback.calls.clear();
      playback.intentCalls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await pumpAsyncWork(tester);
      expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);

      playback.calls.clear();
      playback.intentCalls.clear();

      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final epochBefore = feedState.debugForegroundResumeSyncEpoch;
      feedState.debugBumpForegroundResumeSyncEpoch();
      await tester.pump();

      expect(feedState.debugForegroundResumeSyncEpoch, equals(epochBefore + 1));
      expect(playback.intentCalls.any((i) => i.wantsPlay == true), isTrue);
      expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
    },
  );

  testWidgets('W-18.4-F4 still tap does not call playback intent', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displaysById['s1'] = const DisplayAsset(
      assetIdentifier: 's1',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/fake_still_s1.jpg',
    );
    display.previewsById['s1'] = const DisplayAsset(
      assetIdentifier: 's1',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/fake_preview_s1.jpg',
    );
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['s1']),
        mediaDisplay: display,
        playback: playback,
      ),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(const Key('mainBrowseFeedStill_s1')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowsePlaybackTapTarget')), findsNothing);

    playback.calls.clear();
    playback.intentCalls.clear();
    await tester.tap(find.byKey(const Key('mainBrowseFeedStill_s1')));
    await pumpAsyncWork(tester);

    expect(playback.intentCalls, isEmpty);
    expect(playback.calls.where((c) => c == 'play' || c == 'pause'), isEmpty);
  });

  testWidgets('W-18.4-F5 vertical drag still changes page', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    for (final id in const ['v1', 'v2']) {
      display.displayErrorById[id] = 'unsupportedMedia';
      display.previewsById[id] = DisplayAsset(
        assetIdentifier: id,
        mediaKind: PlaybackMediaKind.video,
        localFilePath: '/tmp/fake_preview_$id.jpg',
      );
    }
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
        mediaDisplay: display,
        playback: playback,
        browseShuffleSeed: 0,
      ),
    );
    await pumpAsyncWork(tester);
    final ids = await _feedOrderedIds(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[0]}')), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, -280));
    await pumpAsyncWork(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[1]}')), findsOneWidget);
  });

  testWidgets('W-18.4-F6 scrubber band tap is no-op', (tester) async {
    final playback = await _pumpSingleVideoFeed(tester);
    expect(find.byKey(const Key('mainBrowseVideoScrubber')), findsOneWidget);
    expect(
      find.byKey(const Key('mainBrowseCenterPlayAffordance')),
      findsNothing,
    );

    playback.calls.clear();
    playback.intentCalls.clear();

    await tester.tap(find.byKey(const Key('mainBrowseVideoScrubber')));
    await pumpAsyncWork(tester);

    expect(playback.intentCalls, isEmpty);
    expect(playback.calls.where((c) => c == 'play' || c == 'pause'), isEmpty);
    expect(
      find.byKey(const Key('mainBrowseCenterPlayAffordance')),
      findsNothing,
    );
  });

  testWidgets('W-18.5-5 band horizontal drag does not change page', (
    tester,
  ) async {
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    await _pumpTwoVideoPosterFeed(tester, playback: playback, display: display);
    final ids = await _feedOrderedIds(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[0]}')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('mainBrowseVideoScrubber')),
      const Offset(120, 0),
    );
    await pumpAsyncWork(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[0]}')), findsOneWidget);
  });

  testWidgets('W-18.5-6 vertical drag outside band still changes page', (
    tester,
  ) async {
    final playback = FakePlaybackRepository();
    final display = FakeMediaDisplayRepository();
    await _pumpTwoVideoPosterFeed(tester, playback: playback, display: display);
    final ids = await _feedOrderedIds(tester);

    await tester.drag(find.byType(PageView), const Offset(0, -280));
    await pumpAsyncWork(tester);
    expect(find.byKey(Key('mainBrowseFeedVideo_${ids[1]}')), findsOneWidget);
  });
}

/// Session ids plus a built [PageView] (current [MediaFeedPage] mounted).
///
/// Provider [hasValue] can lead the widget by a frame. Dwell [Timer] starts
/// in page [State.initState] — returning earlier makes a later `pump(500ms)`
/// elapse before the clock exists.
Future<List<String>> pumpUntilFeedIds(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 40; i++) {
    if (find.byType(PageView).evaluate().isNotEmpty) {
      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      final async = container.read(browseSessionProvider);
      if (async.hasValue && async.requireValue.orderedAssetIds.isNotEmpty) {
        return async.requireValue.orderedAssetIds;
      }
    }
    await tester.pump();
  }
  fail('feed ids never ready');
}

Future<List<String>> _feedOrderedIds(WidgetTester tester) async {
  final element = tester.element(find.byType(VerticalMediaFeed));
  final container = ProviderScope.containerOf(element);
  return (await container.read(browseSessionProvider.future)).orderedAssetIds;
}

Future<FakePlaybackRepository> _pumpSingleVideoFeed(WidgetTester tester) async {
  final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
  final display = FakeMediaDisplayRepository();
  display.displayErrorById['v1'] = 'unsupportedMedia';
  display.previewsById['v1'] = const DisplayAsset(
    assetIdentifier: 'v1',
    mediaKind: PlaybackMediaKind.video,
    localFilePath: '/tmp/fake_preview_v1.jpg',
  );
  final playback = FakePlaybackRepository();
  await tester.pumpWidget(
    permissionUiHarness(
      disableBrowseAllPrefetch: true,
      repo: repo,
      assetSources: FakeAssetSourceRepository(allIds: const ['v1']),
      mediaDisplay: display,
      playback: playback,
    ),
  );
  await pumpAsyncWork(tester);
  expect(find.byKey(const Key('mainBrowseFeedVideo_v1')), findsOneWidget);
  for (var i = 0; i < 40; i++) {
    if (find
            .byKey(const Key('mainBrowsePlaybackTapTarget'))
            .evaluate()
            .isNotEmpty &&
        playback.calls.any((c) => c == 'play')) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(find.byKey(const Key('mainBrowsePlaybackTapTarget')), findsOneWidget);
  return playback;
}

void _seedPvHandoffSnapshots(ProviderContainer container, List<String> ids) {
  final notifier = container.read(pvTransitionGuardProvider.notifier);
  notifier.updatePageSnapshot(
    ids[0],
    PvHandoffPageSnapshot(
      isVideoWithPoster: true,
      isCurrentSurfaceReady: true,
      posterPath: '/tmp/fake_preview_${ids[0]}.jpg',
    ),
  );
  notifier.updatePageSnapshot(
    ids[1],
    PvHandoffPageSnapshot(
      isVideoWithPoster: true,
      posterPath: '/tmp/fake_preview_${ids[1]}.jpg',
    ),
  );
}

/// Cap 15.14: [_ReloadableFileImage] is library-private; match by runtimeType.
State _reloadableFileImageState(WidgetTester tester, Finder root) {
  State? found;
  var count = 0;
  for (final element in root.evaluate()) {
    void visit(Element e) {
      if (e is StatefulElement &&
          e.widget.runtimeType.toString() == '_ReloadableFileImage') {
        found = e.state;
        count++;
      }
      e.visitChildren(visit);
    }

    visit(element);
  }
  expect(count, 1, reason: 'expected one _ReloadableFileImage under $root');
  return found!;
}

Future<void> _pumpTwoVideoPosterFeed(
  WidgetTester tester, {
  required FakeMediaDisplayRepository display,
  required FakePlaybackRepository playback,
}) async {
  for (final id in const ['v1', 'v2']) {
    display.displayErrorById[id] = 'unsupportedMedia';
    display.previewsById[id] = DisplayAsset(
      assetIdentifier: id,
      mediaKind: PlaybackMediaKind.video,
      localFilePath: '/tmp/fake_preview_$id.jpg',
    );
  }
  final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
  await tester.pumpWidget(
    permissionUiHarness(
      disableBrowseAllPrefetch: true,
      repo: repo,
      assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
      mediaDisplay: display,
      playback: playback,
    ),
  );
  await pumpAsyncWork(tester);
  final ids = await _feedOrderedIds(tester);
  for (var i = 0; i < 40; i++) {
    final currentVideo = find.byWidgetPredicate(
      (widget) =>
          widget is MediaFeedPage &&
          widget.assetIdentifier == ids[0] &&
          widget.isCurrent,
    );
    if (currentVideo.evaluate().isNotEmpty &&
        playback.calls.any((c) => c.startsWith('notifyReady:'))) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(playback.calls.any((c) => c.startsWith('notifyReady:')), isTrue);
  for (var i = 0; i < 40; i++) {
    final neighbor = find.byWidgetPredicate(
      (widget) => widget is MediaFeedPage && widget.assetIdentifier == ids[1],
      skipOffstage: false,
    );
    if (neighbor.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 20));
      continue;
    }
    final neighborState = tester.state<MediaFeedPageState>(neighbor);
    if (neighborState.debugMedia?.display?.localFilePath != null) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
  await pumpAsyncWork(tester);
}

class _FailOnceDisplayRepository extends FakeMediaDisplayRepository {
  bool _failedOnce = false;

  @override
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier) async {
    displayCalls.add(assetIdentifier);
    if (!_failedOnce) {
      _failedOnce = true;
      throw PlatformException(code: 'iCloudDownloadFailed', message: 'fake');
    }
    final gate = displayGates[assetIdentifier];
    if (gate != null) {
      await gate.future;
    }
    final perIdError = displayErrorById[assetIdentifier];
    if (perIdError != null) {
      throw PlatformException(code: perIdError, message: 'fake');
    }
    final code = displayErrorCode;
    if (code != null) {
      throw PlatformException(code: code, message: 'fake');
    }
    return displaysById[assetIdentifier] ??
        display ??
        DisplayAsset(
          assetIdentifier: assetIdentifier,
          mediaKind: PlaybackMediaKind.image,
          localFilePath: '/tmp/fake_$assetIdentifier.jpg',
        );
  }
}

class _HangingResolveRepository extends FakeAssetSourceRepository {
  _HangingResolveRepository({super.allIds});

  final Completer<void> gate = Completer<void>();

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    await gate.future;
    return super.resolve(reference);
  }
}

class _ThrowingResolveRepository extends FakeAssetSourceRepository {
  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    resolveCalls += 1;
    lastResolve = reference;
    resolveHistory.add(reference);
    throw StateError('resolve failed');
  }
}

/// Fails the first [failTimes] resolve calls, then delegates to the fake.
class _FailThenSucceedRepository extends FakeAssetSourceRepository {
  _FailThenSucceedRepository({
    super.allIds,
    super.photosIds,
    super.videosIds,
    this.failTimes = 1,
  });

  final int failTimes;
  int _failuresEmitted = 0;

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    if (_failuresEmitted < failTimes) {
      _failuresEmitted += 1;
      resolveCalls += 1;
      lastResolve = reference;
      resolveHistory.add(reference);
      throw StateError('resolve failed');
    }
    return super.resolve(reference);
  }
}
