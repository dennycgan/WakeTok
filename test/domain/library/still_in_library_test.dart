import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/still_in_library.dart';
import 'package:waketok/l10n/app_localizations.dart';

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

  group('U-23.4-copy Cap 23 dialog ≠ feed/wireless Layer-2 strings', () {
    void expectSeparated(AppLocalizations l10n) {
      expect(
        l10n.stillInLibraryUnavailableTitle,
        isNot(equals(l10n.mainBrowseFeedUnavailable)),
      );
      expect(
        l10n.stillInLibraryUnavailableBody,
        isNot(equals(l10n.mainBrowseFeedUnavailable)),
      );
      expect(
        l10n.stillInLibraryUnavailableTitle,
        isNot(equals(l10n.mainBrowseFeedNetworkFailed)),
      );
      expect(
        l10n.stillInLibraryUnavailableBody,
        isNot(equals(l10n.mainBrowseFeedNetworkFailed)),
      );
    }

    test('EN copy keys stay distinct (ADR-049 D5)', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expectSeparated(en);
    });

    test('zh_Hans copy keys stay distinct (ADR-049 D5)', () async {
      final zh = await AppLocalizations.delegate.load(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
      expectSeparated(zh);
    });
  });
}
