import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cap 27 / ADR-057 Decision 3: shared Origin→Session classification.
///
/// Single authoritative read site at the composition root (alongside
/// [browseChromeStateProvider]). Origin-sensitive Session side effects must
/// read this signal — not invent private promote flags.
enum BrowseOriginSessionDeltaKind {
  /// Normal Origin / Session path — new Consumption Session boundary.
  realSessionBoundary,

  /// Temp peek promote — keep Consumption Session (ADR-057 Decision 1).
  identityPreservingPromote,
}

/// Latest classification for Origin-driven Session side effects.
///
/// [generation] advances on every mark so dependents that *watch* this
/// provider can observe updates; Cap 27.2 Session / feed listeners
/// **read** it when `activeOrigin` changes (they do not rely on watching
/// this alone to decide keep-Session).
class BrowseOriginSessionDelta {
  const BrowseOriginSessionDelta({
    required this.kind,
    required this.generation,
  });

  final BrowseOriginSessionDeltaKind kind;
  final int generation;

  bool get isIdentityPreservingPromote =>
      kind == BrowseOriginSessionDeltaKind.identityPreservingPromote;

  bool get isRealSessionBoundary =>
      kind == BrowseOriginSessionDeltaKind.realSessionBoundary;
}

/// Composition-root signal (ADR-057 D3 / ADR-048 shared-hook discipline).
final browseOriginSessionDeltaProvider =
    NotifierProvider<BrowseOriginSessionDeltaNotifier, BrowseOriginSessionDelta>(
      BrowseOriginSessionDeltaNotifier.new,
    );

class BrowseOriginSessionDeltaNotifier
    extends Notifier<BrowseOriginSessionDelta> {
  @override
  BrowseOriginSessionDelta build() {
    return const BrowseOriginSessionDelta(
      kind: BrowseOriginSessionDeltaKind.realSessionBoundary,
      generation: 0,
    );
  }

  /// Written only by the explicit Temp-peek promote API (ADR-057 D1).
  void markIdentityPreservingPromote() {
    state = BrowseOriginSessionDelta(
      kind: BrowseOriginSessionDeltaKind.identityPreservingPromote,
      generation: state.generation + 1,
    );
  }

  /// Written by normal Session-boundary chrome / restart writers.
  void markRealSessionBoundary() {
    state = BrowseOriginSessionDelta(
      kind: BrowseOriginSessionDeltaKind.realSessionBoundary,
      generation: state.generation + 1,
    );
  }
}
