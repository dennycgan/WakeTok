import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';

void main() {
  group('BrowseL2ReadySession', () {
    test('record and lookup', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      const cover = DisplayAsset(
        assetIdentifier: 'a1',
        mediaKind: PlaybackMediaKind.image,
        localFilePath: '/tmp/a1.jpg',
      );
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'a1',
          kind: FeedL2ReadyKind.stillFull,
          cover: cover,
        ),
      );

      final entry = container.read(browseL2ReadySessionProvider)['a1'];
      expect(entry?.kind, FeedL2ReadyKind.stillFull);
      expect(entry?.cover?.localFilePath, '/tmp/a1.jpg');
    });

    test('clear removes all entries', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'a1',
          kind: FeedL2ReadyKind.video,
        ),
      );
      notifier.clear();
      expect(container.read(browseL2ReadySessionProvider), isEmpty);
    });

    test('source change clears session map', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'a1',
          kind: FeedL2ReadyKind.stillFull,
        ),
      );

      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);

      expect(container.read(browseL2ReadySessionProvider), isEmpty);
    });

    test('in-flight L2 never minted when record not called', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(browseL2ReadySessionProvider)['a1'], isNull);
    });

    test('completed token survives leave-current simulation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'a1',
          kind: FeedL2ReadyKind.video,
          cover: DisplayAsset(
            assetIdentifier: 'a1',
            mediaKind: PlaybackMediaKind.video,
            localFilePath: '/tmp/poster.jpg',
          ),
        ),
      );

      // Leave-current does not call clear — only Session end does.
      expect(container.read(browseL2ReadySessionProvider)['a1'], isNotNull);
    });

    test('lookupIfCoverOnDisk evicts when cover path is missing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'a1',
          kind: FeedL2ReadyKind.stillFull,
          cover: DisplayAsset(
            assetIdentifier: 'a1',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: '/tmp/wt_15_13_missing_cover.jpg',
          ),
        ),
      );

      expect(notifier.lookup('a1'), isNotNull);
      expect(await notifier.lookupIfCoverOnDisk('a1'), isNull);
      expect(container.read(browseL2ReadySessionProvider), isEmpty);
    });

    test('evictEntriesWithMissingPathsAsync removes stale tokens only', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dir = await Directory.systemTemp.createTemp('wt_15_13_l2');
      addTearDown(() => dir.delete(recursive: true));
      final live = File('${dir.path}/live.jpg');
      await live.writeAsBytes(const [0xFF, 0xD8, 0xFF]);

      final notifier = container.read(browseL2ReadySessionProvider.notifier);
      notifier.record(
        FeedL2ReadyEntry(
          assetIdentifier: 'live',
          kind: FeedL2ReadyKind.stillFull,
          cover: DisplayAsset(
            assetIdentifier: 'live',
            mediaKind: PlaybackMediaKind.image,
            localFilePath: live.path,
          ),
        ),
      );
      notifier.record(
        const FeedL2ReadyEntry(
          assetIdentifier: 'stale',
          kind: FeedL2ReadyKind.video,
          cover: DisplayAsset(
            assetIdentifier: 'stale',
            mediaKind: PlaybackMediaKind.video,
            localFilePath: '/tmp/wt_15_13_evict_me.jpg',
          ),
        ),
      );

      await notifier.evictEntriesWithMissingPathsAsync();

      final map = container.read(browseL2ReadySessionProvider);
      expect(map.containsKey('live'), isTrue);
      expect(map.containsKey('stale'), isFalse);
    });
  });
}
