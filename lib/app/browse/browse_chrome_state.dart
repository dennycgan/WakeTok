import 'package:flutter/foundation.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Cap 21 / ADR-044: what currently drives the Consumption Session.
sealed class BrowseOrigin {
  const BrowseOrigin();
}

/// Built-in All / Photos / Videos tab selection.
final class BrowseOriginBuiltIn extends BrowseOrigin {
  const BrowseOriginBuiltIn(this.source);

  final SourceReference source;

  @override
  bool operator ==(Object other) {
    return other is BrowseOriginBuiltIn && other.source == source;
  }

  @override
  int get hashCode => Object.hash(BrowseOriginBuiltIn, source);
}

/// Ephemeral multi-source (or single-source) Pool from Build → Start.
final class BrowseOriginEphemeralPool extends BrowseOrigin {
  const BrowseOriginEphemeralPool(this.definition);

  final SourcePoolDefinition definition;

  @override
  bool operator ==(Object other) {
    return other is BrowseOriginEphemeralPool && other.definition == definition;
  }

  @override
  int get hashCode => Object.hash(BrowseOriginEphemeralPool, definition);
}

/// Saved Pool Preset currently driving the Session (Cap 22 / ADR-046 D3–D4).
///
/// Identity is [poolId] only. [definition] is the recipe snapshot used to
/// resolve this Session — it does not participate in equality (SPD `==`
/// includes displayName, which would treat a later Rename as a new Origin).
final class BrowseOriginSavedPool extends BrowseOrigin {
  const BrowseOriginSavedPool({required this.poolId, required this.definition});

  final String poolId;
  final SourcePoolDefinition definition;

  @override
  bool operator ==(Object other) {
    return other is BrowseOriginSavedPool && other.poolId == poolId;
  }

  @override
  int get hashCode => Object.hash(BrowseOriginSavedPool, poolId);
}

/// Cap 21 / ADR-044 D6.1: session authority + parked temp Pool memory.
///
/// [lastRememberedBuiltIn] is updated on every built-in select so the
/// projection can return a built-in ref while [activeOrigin] is ephemeral
/// (21.3+ chrome honesty). Product path in Cap 21.2 keeps [activeOrigin]
/// built-in and [parkedEphemeralPool] null.
///
/// Cap 21.5: [parkedCompositionLabels] freezes human-readable names at
/// Start Browsing (same order/length as [parkedEphemeralPool] refs) so
/// composition peek never falls back to PhotoKit ids when a source vanishes.
class BrowseChromeState {
  const BrowseChromeState({
    required this.activeOrigin,
    required this.parkedEphemeralPool,
    required this.lastRememberedBuiltIn,
    this.parkedCompositionLabels,
  });

  final BrowseOrigin activeOrigin;
  final SourcePoolDefinition? parkedEphemeralPool;

  /// Last built-in chosen via [BrowseChromeStateNotifier.selectBuiltIn].
  final SourceReference lastRememberedBuiltIn;

  /// Display names captured at Start; null when nothing parked or unset.
  final List<String>? parkedCompositionLabels;

  /// Built-in ref for tab highlight / legacy projection.
  SourceReference get projectedBuiltIn {
    final origin = activeOrigin;
    if (origin is BrowseOriginBuiltIn) {
      return origin.source;
    }
    return lastRememberedBuiltIn;
  }

  /// Stable id for feed PageView key / Layer1 source-switch delay (ADR-044).
  String get feedDataSourceId {
    return switch (activeOrigin) {
      BrowseOriginBuiltIn(:final source) => source.id,
      BrowseOriginEphemeralPool(:final definition) =>
        'ephemeral:${definition.id}',
      BrowseOriginSavedPool(:final poolId) => 'saved:$poolId',
    };
  }

  /// Kind passed into feed pages.
  ///
  /// A Pool mixes Albums and media types, so it maps to
  /// [AssetSourceKind.entireLibrary] — the "probe per item" contract Layer 2
  /// and Layer 3 already implement (still first, `unsupportedMedia` → video).
  /// Album / smart-album kinds must never reach feed pages: their Layer 2
  /// branch is a hard failure (Cap 21.4 device finding).
  AssetSourceKind get feedSourceKind {
    return switch (activeOrigin) {
      BrowseOriginBuiltIn(:final source) => source.kind,
      BrowseOriginEphemeralPool() => AssetSourceKind.entireLibrary,
      BrowseOriginSavedPool() => AssetSourceKind.entireLibrary,
    };
  }

  /// Definition used to resolve / build the Session for [activeOrigin].
  SourcePoolDefinition activeDefinition({
    required SourcePoolDefinition Function(SourceReference source) forBuiltIn,
  }) {
    final origin = activeOrigin;
    return switch (origin) {
      BrowseOriginBuiltIn(:final source) => forBuiltIn(source),
      BrowseOriginEphemeralPool(:final definition) => definition,
      BrowseOriginSavedPool(:final definition) => definition,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is BrowseChromeState &&
        other.activeOrigin == activeOrigin &&
        other.parkedEphemeralPool == parkedEphemeralPool &&
        other.lastRememberedBuiltIn == lastRememberedBuiltIn &&
        listEquals(other.parkedCompositionLabels, parkedCompositionLabels);
  }

  @override
  int get hashCode => Object.hash(
    activeOrigin,
    parkedEphemeralPool,
    lastRememberedBuiltIn,
    Object.hashAll(parkedCompositionLabels ?? const []),
  );
}

/// Test-only / future Start helpers for parked + ephemeral active.
@visibleForTesting
extension BrowseChromeStateTesting on BrowseChromeState {
  /// Copy with an injected parked Definition (does not change [activeOrigin]).
  ///
  /// Clears [parkedCompositionLabels] — test parking is chip-layout only.
  BrowseChromeState copyWithParked(SourcePoolDefinition? parked) {
    return BrowseChromeState(
      activeOrigin: activeOrigin,
      parkedEphemeralPool: parked,
      lastRememberedBuiltIn: lastRememberedBuiltIn,
      parkedCompositionLabels: null,
    );
  }
}
