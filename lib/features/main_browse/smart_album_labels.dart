import 'package:waketok/domain/source/smart_album_boundary.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 21.4b ARB labels for whitelist subtypes (Q6=C).
String smartAlbumDisplayLabel(AppLocalizations l10n, int subtype) {
  return switch (subtype) {
    SmartAlbumBoundary.favorites => l10n.smartAlbumFavorites,
    213 => l10n.smartAlbumLivePhotos,
    211 => l10n.smartAlbumScreenshots,
    214 => l10n.smartAlbumAnimated,
    210 => l10n.smartAlbumSelfies,
    202 => l10n.smartAlbumVideos,
    220 => l10n.smartAlbumScreenRecordings,
    201 => l10n.smartAlbumPanoramas,
    204 => l10n.smartAlbumTimelapse,
    207 => l10n.smartAlbumBursts,
    208 => l10n.smartAlbumSlomo,
    212 => l10n.smartAlbumPortrait,
    215 => l10n.smartAlbumLongExposure,
    217 => l10n.smartAlbumRaw,
    218 => l10n.smartAlbumCinematic,
    219 => l10n.smartAlbumSpatial,
    221 => l10n.smartAlbumDualCapture,
    _ => 'Smart album $subtype',
  };
}
