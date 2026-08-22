import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart'
    show mainBrowseSelectedSourceProvider;
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Cap 15.10: proof that Layer 2 completed for an asset in the current Browse
/// Session. Survives leave-current; cleared on Session end (leave Browse / tab).
enum FeedL2ReadyKind {
  /// Full still [DisplayAsset] ready to show without L1→L2.
  stillFull,

  /// Video L2 succeeded; [cover] is poster for on-screen cover during prepare.
  video,
}

/// Session-scoped L2-ready entry (handles only — not a disk cache).
class FeedL2ReadyEntry {
  const FeedL2ReadyEntry({
    required this.assetIdentifier,
    required this.kind,
    this.cover,
  });

  final String assetIdentifier;
  final FeedL2ReadyKind kind;

  /// Still: full L2 file. Video: poster shown until surface ready.
  final DisplayAsset? cover;
}

/// Per Browse Session map: `localIdentifier → L2-ready proof`.
///
/// Mint on L2 **success** only. Never mint from in-flight / cancelled L2.
/// Token survives leave-current after success; [clear] on Session end.
class BrowseL2ReadySession extends Notifier<Map<String, FeedL2ReadyEntry>> {
  @override
  Map<String, FeedL2ReadyEntry> build() {
    ref.listen<SourceReference>(
      mainBrowseSelectedSourceProvider,
      (previous, next) {
        if (previous != null && previous != next) {
          state = const {};
        }
      },
    );
    return const {};
  }

  void record(FeedL2ReadyEntry entry) {
    state = {...state, entry.assetIdentifier: entry};
  }

  FeedL2ReadyEntry? lookup(String assetIdentifier) => state[assetIdentifier];

  void clear() {
    state = const {};
  }
}

final browseL2ReadySessionProvider =
    NotifierProvider<BrowseL2ReadySession, Map<String, FeedL2ReadyEntry>>(
      BrowseL2ReadySession.new,
    );
