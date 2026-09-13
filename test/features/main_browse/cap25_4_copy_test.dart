import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 25.4 — Share fail toast must not collide with Cap 19 / Cap 24
/// failure copy (same discipline as U-23.4-copy).
void main() {
  group('U-25.4-copy Cap 25 share fail ≠ Cap 19/24 fail strings', () {
    void expectSeparated(AppLocalizations l10n) {
      expect(
        l10n.cap25ShareFailed,
        isNot(equals(l10n.cap24SoftDeleteFailed)),
      );
      expect(
        l10n.cap25ShareFailed,
        isNot(equals(l10n.cap19PanelAddToAlbumError)),
      );
      expect(
        l10n.cap25ShareFailed,
        isNot(equals(l10n.cap19PanelFavoritesError)),
      );
      expect(
        l10n.cap25ShareFailed,
        isNot(equals(l10n.cap19LeftSwipeAppendError)),
      );
      expect(
        l10n.cap25ShareFailed,
        isNot(equals(l10n.mainBrowseFeedNetworkFailed)),
      );
      expect(
        l10n.cap25ShareFailed,
        isNot(equals(l10n.mainBrowseFeedUnavailable)),
      );
    }

    test('EN copy keys stay distinct (ADR-051 D4/D5)', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expectSeparated(en);
    });

    test('zh_Hans copy keys stay distinct (ADR-051 D4/D5)', () async {
      final zh = await AppLocalizations.delegate.load(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      );
      expectSeparated(zh);
    });
  });
}
