import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/smart_album_labels.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Built-in All / Photos / Videos ARB labels (never PhotoKit ids).
String builtInDisplayLabel(AppLocalizations l10n, SourceReference source) {
  if (source == SourceReference.all) {
    return l10n.libraryRowAll;
  }
  if (source == SourceReference.photos) {
    return l10n.libraryRowPhotos;
  }
  if (source == SourceReference.videos) {
    return l10n.libraryRowVideos;
  }
  return l10n.mainBrowseCompositionPeekUnknownSource;
}

/// Human-readable composition line for Build Start freeze / peek.
///
/// Never returns a PhotoKit `localIdentifier`. Missing catalog rows use
/// [mainBrowseCompositionPeekUnknownSource].
String compositionDisplayLabel(
  AppLocalizations l10n,
  SourceReference reference,
  List<AssetSource> catalog,
) {
  if (reference == SourceReference.all ||
      reference == SourceReference.photos ||
      reference == SourceReference.videos) {
    return builtInDisplayLabel(l10n, reference);
  }
  AssetSource? match;
  for (final source in catalog) {
    if (source.kind == reference.kind && source.id == reference.id) {
      match = source;
      break;
    }
  }
  if (match == null) {
    return l10n.mainBrowseCompositionPeekUnknownSource;
  }
  final subtype = match.collectionSubtype;
  if (match.kind == AssetSourceKind.smartAlbum && subtype != null) {
    return smartAlbumDisplayLabel(l10n, subtype);
  }
  if (match.displayName.isEmpty) {
    return l10n.mainBrowseCompositionPeekUnknownSource;
  }
  return match.displayName;
}

/// Cap 21.5 peek suffix for a parked source row (null = no suffix / P1 empty).
///
/// Matrix (owner-locked):
/// - missing + Limited → Requires Full Access
/// - missing + Full → Removed from Photos
/// - unauthorized → Requires Full Access
/// - unavailable → Removed from Photos
/// - empty / available → none
String? compositionPeekSuffix({
  required AppLocalizations l10n,
  required PhotosAccess? access,
  required AssetSource? match,
}) {
  if (match == null) {
    if (access == PhotosAccess.limited) {
      return l10n.mainBrowseCompositionPeekRequiresFullAccess;
    }
    return l10n.mainBrowseCompositionPeekRemovedFromPhotos;
  }
  switch (match.availability) {
    case AssetSourceAvailability.unauthorized:
      return l10n.mainBrowseCompositionPeekRequiresFullAccess;
    case AssetSourceAvailability.unavailable:
      return l10n.mainBrowseCompositionPeekRemovedFromPhotos;
    case AssetSourceAvailability.empty:
    case AssetSourceAvailability.available:
      return null;
  }
}

String compositionPeekLine({
  required AppLocalizations l10n,
  required PhotosAccess? access,
  required SourceReference reference,
  required List<AssetSource> catalog,
  String? frozenLabel,
}) {
  AssetSource? match;
  for (final source in catalog) {
    if (source.kind == reference.kind && source.id == reference.id) {
      match = source;
      break;
    }
  }
  final live = compositionDisplayLabel(l10n, reference, catalog);
  final name = (frozenLabel != null && frozenLabel.isNotEmpty)
      ? frozenLabel
      : live;
  final suffix = compositionPeekSuffix(
    l10n: l10n,
    access: access,
    match: match,
  );
  if (suffix == null) {
    return name;
  }
  return '$name ($suffix)';
}
