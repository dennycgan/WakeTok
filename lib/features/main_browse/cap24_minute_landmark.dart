import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/features/main_browse/cap24_exif_wall_clock.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Resolved minute landmark for the Cap 24 more half-sheet (ADR-050 D7).
@immutable
class Cap24MinuteLandmark {
  const Cap24MinuteLandmark({
    required this.displayText,
    required this.fromLibrary,
  });

  final String displayText;

  /// `true` = Instant / Photos library date path; `false` = EXIF/TIFF file path.
  final bool fromLibrary;
}

/// Loads the half-sheet minute row **once** (no Instant→EXIF flash).
///
/// Captures [Ref] inside the provider so callers do not pass [WidgetRef].
typedef Cap24MinuteLandmarkLoader = Future<Cap24MinuteLandmark?> Function({
  required AppLocalizations l10n,
  required String assetIdentifier,
});

/// Default production loader; override in tests for flash / mounted cases.
final cap24MinuteLandmarkLoaderProvider =
    Provider<Cap24MinuteLandmarkLoader>((ref) {
  return ({
    required AppLocalizations l10n,
    required String assetIdentifier,
  }) {
    return loadCap24MinuteLandmark(
      ref: ref,
      l10n: l10n,
      assetIdentifier: assetIdentifier,
    );
  };
});

/// ADR-050 D7 source priority for still/Live; Instant-only for video.
Future<Cap24MinuteLandmark?> loadCap24MinuteLandmark({
  required Ref ref,
  required AppLocalizations l10n,
  required String assetIdentifier,
}) async {
  final meta = await ref
      .read(presentationMetadataRepositoryProvider)
      .requestPresentationMetadata(assetIdentifier);
  final kind = meta.mediaKind;

  if (kind == PresentationMediaKind.video) {
    return _libraryLandmark(l10n, meta.createdAt);
  }

  final entry = await ref
      .read(browseL2ReadySessionProvider.notifier)
      .lookupIfCoverOnDisk(assetIdentifier);
  final coverPath = entry?.cover?.localFilePath;
  if (entry != null &&
      entry.kind == FeedL2ReadyKind.stillFull &&
      coverPath != null) {
    final bytes = await readCoverBytesForMinuteLandmark(coverPath);
    if (bytes != null) {
      // Parse bugs (RangeError / TypeError / …) must **not** be swallowed —
      // only IO miss → Instant fallback below.
      final wall = parseJpegExifNakedWallClock(bytes);
      if (wall != null) {
        return Cap24MinuteLandmark(
          displayText: _formatBare(l10n, wall),
          fromLibrary: false,
        );
      }
    }
  }

  return _libraryLandmark(l10n, meta.createdAt);
}

/// Reads L2 cover bytes for EXIF. IO failure → null (Instant fallback);
/// does **not** catch programming errors from callers.
@visibleForTesting
Future<Uint8List?> readCoverBytesForMinuteLandmark(String path) async {
  try {
    return await File(path).readAsBytes();
  } on FileSystemException catch (error, stackTrace) {
    assert(() {
      debugPrint(
        'Cap24 minute landmark: cover read failed path=$path '
        'error=$error\n$stackTrace',
      );
      return true;
    }());
    return null;
  }
}

Cap24MinuteLandmark? _libraryLandmark(
  AppLocalizations l10n,
  DateTime? createdAt,
) {
  if (createdAt == null) {
    return null;
  }
  final local = createdAt.toLocal();
  return Cap24MinuteLandmark(
    displayText: l10n.cap24SoftDeleteSheetExactMinuteLibrary(
      _pad4(local.year),
      _pad2(local.month),
      _pad2(local.day),
      _pad2(local.hour),
      _pad2(local.minute),
    ),
    fromLibrary: true,
  );
}

String _formatBare(AppLocalizations l10n, ExifNakedWallClock wall) {
  final y = _pad4(wall.year);
  final m = _pad2(wall.month);
  final d = _pad2(wall.day);
  final h = _pad2(wall.hour);
  final min = _pad2(wall.minute);
  final sec = wall.second;
  if (sec == null) {
    return l10n.cap24SoftDeleteSheetExactMinuteNoSeconds(y, m, d, h, min);
  }
  return l10n.cap24SoftDeleteSheetExactMinute(
    y,
    m,
    d,
    h,
    min,
    _pad2(sec),
  );
}

String _pad2(int n) => n.toString().padLeft(2, '0');

String _pad4(int n) => n.toString().padLeft(4, '0');
