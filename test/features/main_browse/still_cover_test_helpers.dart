import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_media_display_repository.dart';

/// Cap 24.5.5 / debt 466: Cap 21 `_suppressStillCoverMeta` hides
/// [MediaInfoOverlay] until the still/poster [Image] has a decoded frame
/// (unresolved **or** broken). Cap 26.4b: corner spinner / LIVE are suppressed
/// only when decode-**broken** (`_suppressStillCoverWaitChrome`) — unresolved
/// keeps spinner + LIVE. Harness paths that point at non-decodable
/// `/tmp/fake_*.jpg` never clear the Meta gate — seed a real 1×1 PNG and pump
/// until [debugStillCoverReady].

const kStillCoverTestTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// Writes a decodable 1×1 PNG under the system temp directory.
String writeStillCoverTestPng(String name) {
  final file = File('${Directory.systemTemp.path}/wt_still_cover_$name.png');
  file.writeAsBytesSync(base64Decode(kStillCoverTestTinyPngBase64));
  return file.path;
}

/// Seeds preview + display maps with the same decodable PNG per id.
void seedDecodableStillPaths(
  FakeMediaDisplayRepository display,
  Iterable<String> ids, {
  PlaybackMediaKind mediaKind = PlaybackMediaKind.image,
}) {
  for (final id in ids) {
    final path = writeStillCoverTestPng(id);
    final asset = DisplayAsset(
      assetIdentifier: id,
      mediaKind: mediaKind,
      localFilePath: path,
    );
    display.previewsById[id] = asset;
    display.displaysById[id] = asset;
  }
}

Finder mediaFeedPageFinder(String assetIdentifier) {
  return find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.assetIdentifier == assetIdentifier,
    skipOffstage: false,
  );
}

MediaFeedPageState mediaFeedPageState(
  WidgetTester tester,
  String assetIdentifier,
) {
  return tester.state<MediaFeedPageState>(
    mediaFeedPageFinder(assetIdentifier),
  );
}

/// Ensures still/poster Meta Overlay is not suppressed (cover ready).
///
/// Prefer the Cap 21 [MediaFeedPageState.debugForceStillCoverDecodeBroken]
/// seam when a cover path is already tracked — FakeAsync rarely completes
/// FileImage.frameBuilder, and a long wall-clock poll would also advance
/// ADR-034 G's DateTime.now-based elapsed (false spinner during dwell).
/// Cap 26.4b: spinner no longer requires ready; Overlay still does.
Future<void> pumpUntilStillCoverReady(
  WidgetTester tester,
  MediaFeedPageState page,
) async {
  final path = page.debugMedia?.display?.localFilePath;
  if (path != null && path.isNotEmpty) {
    page.debugForceStillCoverDecodeBroken(false);
    await tester.pump();
    if (page.debugStillCoverReady && !page.debugStillCoverDecodeBroken) {
      // Cap 26.4c: [_syncMediaCoverVisibleGate] publishes post-frame.
      await tester.pump();
      await tester.pump();
      return;
    }
  }
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    if (page.debugStillCoverReady && !page.debugStillCoverDecodeBroken) {
      await tester.pump();
      await tester.pump();
      return;
    }
  }
  fail(
    'still cover never became ready '
    '(ready=${page.debugStillCoverReady} '
    'broken=${page.debugStillCoverDecodeBroken} path=$path)',
  );
}

Future<void> pumpUntilStillCoverReadyForAsset(
  WidgetTester tester,
  String assetIdentifier,
) async {
  await pumpUntilStillCoverReady(
    tester,
    mediaFeedPageState(tester, assetIdentifier),
  );
}

/// Cap 26.4c: make shell Action Column cover-visible for mutation taps.
///
/// Widget tests often never complete [Image.file] frameBuilder; force the
/// page cover-ready seam then pump so the shell provider publishes.
Future<void> ensureShellMediaCoverVisible(WidgetTester tester) async {
  final finder = find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.isCurrent,
  );
  if (finder.evaluate().isEmpty) {
    return;
  }
  final page = tester.state<MediaFeedPageState>(finder);
  if (!page.debugStillCoverReady || page.debugStillCoverDecodeBroken) {
    page.debugForceStillCoverDecodeBroken(false);
  }
  await tester.pump();
  await tester.pump();
}
