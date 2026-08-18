import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cap 14.6c: default Fit + portrait-only. Scan Host / plist / Dart entry.
///
/// PhotoKit `requestLivePhoto(..., contentMode: .aspectFill)` is fetch
/// sizing, not display — this file only locks the three *display* defaults.
void main() {
  final packageRoot = _findPackageRoot();

  test('presentation: feed still default is BoxFit.contain (14.6c)', () {
    final source = File(
      '${packageRoot.path}/lib/features/main_browse/vertical_media_feed.dart',
    ).readAsStringSync();
    expect(source.contains('fit: BoxFit.contain'), isTrue);
    expect(
      source.contains('BoxFit.cover'),
      isFalse,
      reason: 'Browse still must not default to Fill (BoxFit.cover)',
    );
  });

  test('presentation: video gravity is resizeAspect not Fill (14.6c)', () {
    final source = File(
      '${packageRoot.path}/ios/Runner/Platform/PlaybackApiHost.swift',
    ).readAsStringSync();
    expect(
      source.contains('playerLayer.videoGravity = .resizeAspect'),
      isTrue,
    );
    expect(
      source.contains('resizeAspectFill'),
      isFalse,
      reason: 'Playback surface must not default to Fill',
    );
  });

  test('presentation: Live view contentMode is scaleAspectFit (14.6c)', () {
    final source = File(
      '${packageRoot.path}/ios/Runner/Platform/LivePhotoApiHost.swift',
    ).readAsStringSync();
    expect(
      source.contains('liveView.contentMode = .scaleAspectFit'),
      isTrue,
    );
    expect(
      source.contains('liveView.contentMode = .scaleAspectFill'),
      isFalse,
      reason: 'Live display view must not default to Fill',
    );
  });

  test('presentation: Info.plist is portrait-only (14.6c)', () {
    final plist = File(
      '${packageRoot.path}/ios/Runner/Info.plist',
    ).readAsStringSync();
    expect(
      plist.contains('UIInterfaceOrientationLandscape'),
      isFalse,
      reason: 'Remove landscape from UISupportedInterfaceOrientations',
    );
    expect(
      plist.contains('UIInterfaceOrientationPortraitUpsideDown'),
      isFalse,
      reason: 'MVP portrait is upright only',
    );
    expect(plist.contains('UIInterfaceOrientationPortrait'), isTrue);
  });

  test('presentation: main.dart locks portrait via SystemChrome (14.6c)', () {
    final source = File('${packageRoot.path}/lib/main.dart').readAsStringSync();
    expect(source.contains('setPreferredOrientations'), isTrue);
    expect(source.contains('DeviceOrientation.portraitUp'), isTrue);
  });
}

Directory _findPackageRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('pubspec.yaml not found from ${Directory.current.path}');
    }
    dir = parent;
  }
}
