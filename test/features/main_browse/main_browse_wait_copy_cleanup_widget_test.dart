import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 30,
}) async {
  for (var i = 0; i < maxPumps && finder.evaluate().isEmpty; i++) {
    await tester.pump();
  }
  expect(finder, findsOneWidget);
}

Finder _pageFor(String id) {
  return find.byWidgetPredicate(
    (widget) => widget is MediaFeedPage && widget.assetIdentifier == id,
    skipOffstage: false,
  );
}

void main() {
  testWidgets('source-switch L1 center label uses its independent 150ms delay', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final display = FakeMediaDisplayRepository();
    display.previewGates['photo'] = Completer<void>();
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(
          allIds: const ['all'],
          photosIds: const ['photo'],
        ),
        mediaDisplay: display,
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(VerticalMediaFeed)),
    );
    container
        .read(mainBrowseSelectedSourceProvider.notifier)
        .select(SourceReference.photos);
    await _pumpUntil(
      tester,
      find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
    );

    expect(
      find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(l10n.mainBrowseFeedLayer1Loading),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 149));
    expect(
      find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 1));
    expect(
      find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
      findsOneWidget,
    );

    display.previewGates['photo']!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'source-switch L1 completion below 150ms never paints center label',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      display.previewGates['photo'] = Completer<void>();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            allIds: const ['all'],
            photosIds: const ['photo'],
          ),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      await _pumpUntil(
        tester,
        find.byKey(const Key('mainBrowseFeedPageLoadingSpinner')),
      );
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 50));
      display.previewGates['photo']!.complete();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const Key('mainBrowseFeedCoverlessWaitLabel')),
        findsNothing,
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'coverless video re-enter normalizes loading before L2-ready hold arm',
    (tester) async {
      final display = FakeMediaDisplayRepository();
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['v1', 'v2']),
          mediaDisplay: display,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VerticalMediaFeed)),
      );
      final session = container.read(browseSessionProvider).requireValue;
      final target = session.orderedAssetIds.first;
      final other = session.orderedAssetIds.last;
      final targetPage = tester.state<MediaFeedPageState>(_pageFor(target));

      targetPage.debugForceLayer2WaitChrome(
        path: WaitChromePathClass.a2WaitToPlayable,
        elapsed: Duration.zero,
        mediaKind: FeedPageMediaKind.pendingVideo,
      );
      container
          .read(browseL2ReadySessionProvider.notifier)
          .record(
            FeedL2ReadyEntry(
              assetIdentifier: target,
              kind: FeedL2ReadyKind.video,
              cover: DisplayAsset(
                assetIdentifier: target,
                mediaKind: PlaybackMediaKind.video,
                localFilePath: '/tmp/adr039_missing_video_cover.jpg',
              ),
            ),
          );
      display.previewGates[target] = Completer<void>();
      display.previewGateAfterCall[target] =
          display.previewCalls.where((id) => id == target).length + 1;

      container
          .read(mainBrowseFeedIndexProvider.notifier)
          .setIndex(session.orderedAssetIds.indexOf(other));
      await tester.pump();
      container
          .read(mainBrowseFeedIndexProvider.notifier)
          .setIndex(session.orderedAssetIds.indexOf(target));
      await tester.pump();

      final reentered = tester.state<MediaFeedPageState>(_pageFor(target));
      expect(reentered.widget.isCurrent, isTrue);
      expect(reentered.debugLoading, isTrue);
      expect(
        find.byKey(const Key('mainBrowseFeedPageLoading')),
        findsOneWidget,
        reason: 'cover lookup must remain in the Layer1 loading branch',
      );

      display.previewGates[target]!.complete();
      await tester.pumpAndSettle();
    },
  );
}
