import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Media Info Overlay (Cap 8.5 / kickoff + Photo-App-A-aligned Location row).
///
/// Rows 1–3 keep fixed per-row height (empty still occupies so progressive
/// metadata does not jump). Row 4 (Location) is dynamic: present only when
/// [PresentationOverlaySnapshot.locationLabel] is non-empty — Cap 8 omits
/// Location content (Q1=B), so the row collapses.
class MediaInfoOverlay extends StatelessWidget {
  const MediaInfoOverlay({super.key, required this.snapshot, this.now});

  final PresentationOverlaySnapshot? snapshot;
  final DateTime? now;

  /// Logical height reserved per Overlay row when the row is shown.
  static const double rowHeight = 20;

  /// Always-rendered rows (Relative / Exact / Characteristics).
  static const int baseRowCount = 3;

  /// Trailing inset so Overlay copy stays left of bottom-right Live chrome.
  ///
  /// W-14.6b measured Live chrome width 103 + `right: 12` pad = 115 from the
  /// trailing edge; +8 gap from Overlay copy.
  static const double trailingInset = 123;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final clock = now ?? DateTime.now();
    final snap = snapshot;

    final datesResolved = snap?.exactDateResolved ?? false;
    final relative = formatOverlayRelativeDate(
      l10n: l10n,
      exactDateResolved: datesResolved,
      createdAt: snap?.createdAt,
      now: clock,
    );
    final exact = formatOverlayExactDateTime(
      l10n: l10n,
      exactDateResolved: datesResolved,
      captureWallClock: snap?.captureWallClock,
      createdAt: snap?.createdAt,
    );
    final characteristics = _row3(l10n: l10n, snap: snap);
    final location = snap?.locationLabel?.trim() ?? '';

    final style = tokens.labelOnMedia.copyWith(
      shadows: tokens.onMediaLabelShadows,
    );

    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, trailingInset, 12),
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
              if (location.isNotEmpty)
                _OverlayRow(
                  key: const Key('mediaInfoOverlayRow4'),
                  text: location,
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
    final live = snap.mediaKind == PresentationMediaKind.livePhoto
        ? l10n.mediaInfoLivePhoto
        : '';
    final size = formatOverlayFileSize(
      l10n: l10n,
      fileSizeBytes: snap.fileSizeBytes,
    );
    if (live.isEmpty) {
      return size;
    }
    if (size.isEmpty) {
      return live;
    }
    return l10n.mediaInfoCharacteristicsJoined(live, size);
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
        alignment: Alignment.centerLeft,
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
