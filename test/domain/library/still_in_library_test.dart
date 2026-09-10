import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/still_in_library.dart';

void main() {
  group('U-23-pred isAssetStillInLibrary', () {
    test('P1 deviceLocal → true', () {
      expect(
        isAssetStillInLibrary(AssetAvailability.deviceLocal),
        isTrue,
      );
    });

    test('P2 iCloudNotDownloaded → true', () {
      expect(
        isAssetStillInLibrary(AssetAvailability.iCloudNotDownloaded),
        isTrue,
      );
    });

    test('P3 downloading → true', () {
      expect(
        isAssetStillInLibrary(AssetAvailability.downloading),
        isTrue,
      );
    });

    test('P4 unavailable → false', () {
      expect(
        isAssetStillInLibrary(AssetAvailability.unavailable),
        isFalse,
      );
    });
  });

  group('U-23-AND mutationChromeMayProceed', () {
    test('A1 actionable + stillInLibrary → true', () {
      expect(
        mutationChromeMayProceed(actionable: true, stillInLibrary: true),
        isTrue,
      );
    });

    test('A2 actionable + not stillInLibrary → false', () {
      expect(
        mutationChromeMayProceed(actionable: true, stillInLibrary: false),
        isFalse,
      );
    });

    test('A3 not actionable + stillInLibrary → false', () {
      expect(
        mutationChromeMayProceed(actionable: false, stillInLibrary: true),
        isFalse,
      );
    });

    test('A4 neither → false', () {
      expect(
        mutationChromeMayProceed(actionable: false, stillInLibrary: false),
        isFalse,
      );
    });
  });
}
