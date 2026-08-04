import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';

/// D-1: domain playback signatures stay Riverpod-free (compile-time shape).
void main() {
  test('D-1 PlaybackPlan / DisplayAsset are plain Dart types', () {
    const item = PlaybackItem(
      assetIdentifier: 'a',
      feedIndex: 0,
      mediaKind: PlaybackMediaKind.video,
    );
    const plan = PlaybackPlan(
      planId: 'p',
      orderedItems: [item],
      currentIndex: 0,
    );
    expect(plan.orderedItems.single.assetIdentifier, 'a');
    const display = DisplayAsset(
      assetIdentifier: 'i',
      mediaKind: PlaybackMediaKind.image,
      localFilePath: '/tmp/x.jpg',
    );
    expect(display.localFilePath, endsWith('.jpg'));
    expect(PlaybackRepository, isNotNull);
  });
}
