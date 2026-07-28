import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_03/poc_03_checkpoint.dart';

void main() {
  test('formatCheckpointSummary none when empty', () {
    expect(
      formatCheckpointSummary(clipId: null, positionMs: null, wasPlaying: null),
      'ckpt=none',
    );
  });

  test('formatCheckpointSummary includes clip and position', () {
    expect(
      formatCheckpointSummary(
        clipId: 'clip_b',
        positionMs: 1508,
        wasPlaying: true,
      ),
      'ckpt=clip_b@1508ms (wasPlaying)',
    );
  });

  test('shouldOfferRestore only when cold and pending', () {
    expect(
      shouldOfferRestore(engineConfigured: false, pendingClipId: 'clip_a'),
      isTrue,
    );
    expect(
      shouldOfferRestore(engineConfigured: true, pendingClipId: 'clip_a'),
      isFalse,
    );
    expect(
      shouldOfferRestore(engineConfigured: false, pendingClipId: null),
      isFalse,
    );
  });
}
