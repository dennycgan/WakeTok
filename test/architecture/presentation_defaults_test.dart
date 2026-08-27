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
    final coverOccurrences = RegExp(r'fit: BoxFit\.cover').allMatches(source);
    expect(
      coverOccurrences.length,
      1,
      reason:
          'Only ADR-032 entering-side opaque transition cover may use Fill',
    );
    expect(
      RegExp(
        r'class _PvTransitionCover[\s\S]*?'
        r'child: Image\.file\([\s\S]*?'
        r'fit: BoxFit\.cover,',
      ).hasMatch(source),
      isTrue,
      reason:
          'ADR-032 transition cover fills the viewport; feed media stays Fit',
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

  test('presentation: Layer 1 previewTargetSize is 512×512 (15.6 / ADR-031 A1)',
      () {
    final source = File(
      '${packageRoot.path}/ios/Runner/Platform/PhotoLibraryService.swift',
    ).readAsStringSync();
    expect(
      source.contains(
        'previewTargetSize = CGSize(width: 512, height: 512)',
      ),
      isTrue,
      reason: 'ADR-031 Q1=A1 production box is 512×512',
    );
    expect(
      source.contains(
        'previewTargetSize = CGSize(width: 1080, height: 1080)',
      ),
      isFalse,
      reason: 'Must not revert Layer 1 box to 1080×1080',
    );
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
