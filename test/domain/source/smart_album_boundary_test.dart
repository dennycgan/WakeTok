import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/smart_album_boundary.dart';

/// Kafka Cap 21.4b probe inventory (PASS_A `.any` + PASS_B brute extras).
///
/// Must stay aligned with `docs/reference/cap21-smart-album-boundary.md`.
const _kafkaProbeSubtypes = <int>{
  201, // Panoramas
  202, // Videos
  203, // Favorites
  204, // Time-lapse
  205, // Hidden
  206, // Recently Added (brute; omitted by `.any`)
  207, // Bursts
  208, // Slo-mo
  209, // Recents
  210, // Selfies
  211, // Screenshots
  212, // Portrait
  213, // Live Photos
  214, // Animated
  215, // Long Exposure
  216, // Unable to Upload (brute; omitted by `.any`)
  217, // RAW
  218, // Cinematic
  219, // Spatial
  220, // Screen Recordings
  221, // Dual Capture
  1000000201, // Recently Deleted
  1000000218, // Recently Saved
  1000000219, // Recovered
};

void main() {
  group('SmartAlbumBoundary', () {
    test('B-21.4b-1 whitelist includes Slo-mo (208) and fixed Favorites pin',
        () {
      expect(SmartAlbumBoundary.whitelist.contains(208), isTrue);
      expect(SmartAlbumBoundary.favorites, 203);
      expect(SmartAlbumBoundary.whitelist.contains(203), isTrue);
      expect(SmartAlbumBoundary.whitelist.length, 17);
    });

    test('B-21.4b-2 host brute covers .any omissions 206 and 216', () {
      expect(SmartAlbumBoundary.hostBruteRawValues, contains(206));
      expect(SmartAlbumBoundary.hostBruteRawValues, contains(216));
      expect(SmartAlbumBoundary.hostBruteRawValues, contains(1000000201));
      expect(SmartAlbumBoundary.hostBruteRawValues, contains(1000000218));
      expect(SmartAlbumBoundary.hostBruteRawValues, contains(1000000219));
    });

    test('B-21.4b-3 every Kafka probe subtype is whitelist or explicit exclude',
        () {
      final gaps = <int>[];
      for (final raw in _kafkaProbeSubtypes) {
        final inWhite = SmartAlbumBoundary.whitelist.contains(raw);
        final inExclude = SmartAlbumBoundary.explicitExcludes.contains(raw);
        if (inWhite == inExclude) {
          gaps.add(raw);
        }
      }
      expect(gaps, isEmpty, reason: 'ambiguous or missing disposition: $gaps');
    });

    test('B-21.4b-4 no whitelist/exclude overlap', () {
      final overlap =
          SmartAlbumBoundary.whitelist.intersection(
            SmartAlbumBoundary.explicitExcludes,
          );
      expect(overlap, isEmpty);
    });

    test('B-21.4b-5 sort pins Favorites, then fixed order, then ascending', () {
      final mixed = <int>[
        221, // Dual Capture (remaining)
        202, // Videos (fixed)
        208, // Slo-mo (remaining)
        203, // Favorites
        213, // Live Photos (fixed)
        201, // Panoramas (remaining)
      ];
      final sorted = SmartAlbumBoundary.sortForDisplay(
        mixed,
        subtypeOf: (s) => s,
      );
      expect(sorted, [
        203, // pin
        213, // fixed #1
        202, // fixed #5
        201, // remaining asc
        208,
        221,
      ]);
    });

    test('B-21.4b-6 zero-hide leaves no fixed-order gap (omit empty slots)', () {
      // Live Photos (213) and Selfies (210) empty → omitted from input.
      final visible = <int>[203, 211, 214, 202, 220];
      final sorted = SmartAlbumBoundary.sortForDisplay(
        visible,
        subtypeOf: (s) => s,
      );
      expect(sorted, [203, 211, 214, 202, 220]);
    });
  });
}
