import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap 28.6 / ADR-058 Decision 6: process-only Media Info Overlay visibility.
///
/// `true` (default) = paint the bottom-left three meta rows when other gates
/// allow. `false` = do not paint / do not expose to VoiceOver. Does **not**
/// change Reset / Action / LIVE / scrubber geometry (layout notes §2 —
/// [MediaInfoOverlay.columnHeightFor] stays fixed). Does **not** gate
/// metadata fetch or [presentationSizeCacheProvider].
///
/// Settings UI polarity (title "Show bottom-left details"): CupertinoSwitch ON means
/// show → bind `value: shown`, `onChanged: setShown`. Default ON = details
/// visible.
final browseMetaOverlayShownProvider =
    NotifierProvider<BrowseMetaOverlayShownNotifier, bool>(
      BrowseMetaOverlayShownNotifier.new,
    );

class BrowseMetaOverlayShownNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setShown(bool shown) {
    state = shown;
  }
}
