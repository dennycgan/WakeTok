import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Media Info Overlay (Cap 8.5 / kickoff).
///
/// MVP: fixed three rows (Relative / Exact / Characteristics). Location and
/// richer meta move to a future long-press half-sheet — do not grow this
/// column for [PresentationOverlaySnapshot.locationLabel].
class MediaInfoOverlay extends StatelessWidget {
  const MediaInfoOverlay({super.key, required this.snapshot, this.now});

  final PresentationOverlaySnapshot? snapshot;
  final DateTime? now;

  /// Logical height reserved per Overlay row when the row is shown.
  static const double rowHeight = 20;

  /// Always-rendered MVP rows (Relative / Exact / Characteristics).
  static const int baseRowCount = 3;

  /// Trailing inset so Overlay copy stays left of the action column.
  ///
  /// Derived from [kMediaChromeOverlayTrailingInset] (action hit + clearance).
  /// Cap 26.4b: LIVE is top-leading and no longer reserves trailing width.
  static double get trailingInset => kMediaChromeOverlayTrailingInset;

  /// Column height for Cap 20 Reset placement above this Overlay (ADR-043 D2-A).
  ///
  /// MVP is always [baseRowCount] rows (location ignored on this surface).
  static double columnHeightFor(PresentationOverlaySnapshot? _) {
    return rowHeight * baseRowCount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final clock = now ?? DateTime.now();
    final snap = snapshot;

    final relative = formatOverlayRelativeDate(
      l10n: l10n,
      createdAt: snap?.createdAt,
      now: clock,
    );
    final exact = formatOverlayExactDateTime(
      l10n: l10n,
      createdAt: snap?.createdAt,
    );
    final characteristics = _row3(l10n: l10n, snap: snap);

    final style = tokens.labelOnMedia.copyWith(
      shadows: tokens.onMediaLabelShadows,
    );

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            kMediaChromeLeadingInset,
            0,
            trailingInset,
            mainBrowseMediaOverlayBottomInset(tokens),
          ),
          child: Column(
            key: const Key('mediaInfoOverlay'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverlayRow(
                key: const Key('mediaInfoOverlayRow1'),
                text: relative,
                style: style,
              ),
              _OverlayRow(
                key: const Key('mediaInfoOverlayRow2'),
                text: exact,
                style: style,
              ),
              _OverlayRow(
                key: const Key('mediaInfoOverlayRow3'),
                text: characteristics,
                style: style,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _row3({
    required AppLocalizations l10n,
    required PresentationOverlaySnapshot? snap,
  }) {
    if (snap == null) {
      return '';
    }
    // ADR-053: livePhoto checked first; isAnimated only in the else branch
    // so malformed upstream (both live + animated) cannot dual-label row 3.
    // Do not reorder for "simpler" boolean expressions.
    final label = snap.mediaKind == PresentationMediaKind.livePhoto
        ? l10n.mediaInfoLivePhoto
        : (snap.isAnimated ? l10n.mediaInfoAnimated : '');
    final size = formatOverlayFileSize(
      l10n: l10n,
      fileSizeBytes: snap.fileSizeBytes,
    );
    if (label.isEmpty) {
      return size;
    }
    if (size.isEmpty) {
      return label;
    }
    return l10n.mediaInfoCharacteristicsJoined(label, size);
  }
}

class _OverlayRow extends StatelessWidget {
  const _OverlayRow({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaInfoOverlay.rowHeight,
      child: Align(
        // Bottom-align so row-3 text bottom == Overlay column bottom ==
        // scrubber timestamp text bottom ([mainBrowseMediaOverlayBottomInset]).
        alignment: Alignment.bottomLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}
