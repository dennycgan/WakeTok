import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/composition_source_labels.dart';
import 'package:waketok/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('compositionPeekSuffix', () {
    test('missing + Limited → Requires Full Access', () {
      expect(
        compositionPeekSuffix(
          l10n: l10n,
          access: PhotosAccess.limited,
          match: null,
        ),
        l10n.mainBrowseCompositionPeekRequiresFullAccess,
      );
    });

    test('missing + Full → Removed from Photos', () {
      expect(
        compositionPeekSuffix(
          l10n: l10n,
          access: PhotosAccess.full,
          match: null,
        ),
        l10n.mainBrowseCompositionPeekRemovedFromPhotos,
      );
    });

    test('unauthorized → Requires Full Access', () {
      expect(
        compositionPeekSuffix(
          l10n: l10n,
          access: PhotosAccess.full,
          match: const AssetSource(
            kind: AssetSourceKind.album,
            id: 'a',
            displayName: 'A',
            estimatedCount: 0,
            availability: AssetSourceAvailability.unauthorized,
            canAddContent: false,
          ),
        ),
        l10n.mainBrowseCompositionPeekRequiresFullAccess,
      );
    });

    test('unavailable → Removed from Photos', () {
      expect(
        compositionPeekSuffix(
          l10n: l10n,
          access: PhotosAccess.full,
          match: const AssetSource(
            kind: AssetSourceKind.album,
            id: 'a',
            displayName: 'A',
            estimatedCount: 0,
            availability: AssetSourceAvailability.unavailable,
            canAddContent: false,
          ),
        ),
        l10n.mainBrowseCompositionPeekRemovedFromPhotos,
      );
    });

    test('empty / available → no suffix', () {
      expect(
        compositionPeekSuffix(
          l10n: l10n,
          access: PhotosAccess.full,
          match: const AssetSource(
            kind: AssetSourceKind.album,
            id: 'a',
            displayName: 'A',
            estimatedCount: 0,
            availability: AssetSourceAvailability.empty,
            canAddContent: true,
          ),
        ),
        isNull,
      );
      expect(
        compositionPeekSuffix(
          l10n: l10n,
          access: PhotosAccess.full,
          match: const AssetSource(
            kind: AssetSourceKind.album,
            id: 'a',
            displayName: 'A',
            estimatedCount: 1,
            availability: AssetSourceAvailability.available,
            canAddContent: true,
          ),
        ),
        isNull,
      );
    });
  });
}
