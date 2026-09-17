import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/media_cover_visible_policy.dart';

void main() {
  group('mediaCoverVisiblePredicate (ADR-054)', () {
    test('loading miss → false', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: true,
          liveMotionMounted: false,
          hasDisplay: false,
          stillCoverReady: false,
          stillCoverDecodeBroken: false,
          isVideo: false,
          surfaceReady: false,
        ),
        isFalse,
      );
    });

    test('cover unresolved → false', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: true,
          stillCoverReady: false,
          stillCoverDecodeBroken: false,
          isVideo: false,
          surfaceReady: false,
        ),
        isFalse,
      );
    });

    test('decode-broken → false', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: true,
          stillCoverReady: false,
          stillCoverDecodeBroken: true,
          isVideo: false,
          surfaceReady: false,
        ),
        isFalse,
      );
    });

    test('cover ready (stage ③) → true', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: true,
          stillCoverReady: true,
          stillCoverDecodeBroken: false,
          isVideo: false,
          surfaceReady: false,
        ),
        isTrue,
      );
    });

    test('Live motion mounted → true even without still cover', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: true,
          hasDisplay: false,
          stillCoverReady: false,
          stillCoverDecodeBroken: false,
          isVideo: false,
          surfaceReady: false,
        ),
        isTrue,
      );
    });

    test('coverless video needs surfaceReady', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: false,
          stillCoverReady: false,
          stillCoverDecodeBroken: false,
          isVideo: true,
          surfaceReady: false,
        ),
        isFalse,
      );
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: false,
          stillCoverReady: false,
          stillCoverDecodeBroken: false,
          isVideo: true,
          surfaceReady: true,
        ),
        isTrue,
      );
    });

    test('video with poster uses cover-ready not surfaceReady alone', () {
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: true,
          stillCoverReady: false,
          stillCoverDecodeBroken: false,
          isVideo: true,
          surfaceReady: true,
        ),
        isFalse,
      );
      expect(
        mediaCoverVisiblePredicate(
          loading: false,
          liveMotionMounted: false,
          hasDisplay: true,
          stillCoverReady: true,
          stillCoverDecodeBroken: false,
          isVideo: true,
          surfaceReady: false,
        ),
        isTrue,
      );
    });
  });
}
