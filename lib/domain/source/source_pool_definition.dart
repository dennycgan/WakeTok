import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Source Pool Definition — ordered Asset Source recipe (Glossary §6).
///
/// Records which sources to resolve and in what order; not a frozen Media
/// Item list. No repository in Cap 10 — [PersistencePolicy.saved] is
/// constructible at the type level only (ADR-020 D6=A).
class SourcePoolDefinition {
  /// Creates a validated definition.
  ///
  /// - [id] must be non-empty.
  /// - [orderedSourceReferences] length must be in
  ///   `0 .. PoolCapacity.maxSourcesPerPool` (inclusive). Duplicate
  ///   references are allowed (Cap 10 Q1=A); product UI may constrain later.
  /// - Empty [displayName] is normalized to `null` (intentional — callers
  ///   may pass `''` from forms; Cap 10 treats blank as unnamed).
  /// - When [persistencePolicy] is [PersistencePolicy.saved], Cap 10 does
  ///   **not** require a non-null [displayName]; that UX constraint is left
  ///   to the Saved Pool capability (Cap 15).
  factory SourcePoolDefinition({
    required String id,
    String? displayName,
    required PersistencePolicy persistencePolicy,
    required List<SourceReference> orderedSourceReferences,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'must be non-empty');
    }
    final count = orderedSourceReferences.length;
    if (count > PoolCapacity.maxSourcesPerPool) {
      throw ArgumentError.value(
        count,
        'orderedSourceReferences.length',
        'must be <= ${PoolCapacity.maxSourcesPerPool}',
      );
    }
    // Intentional: blank form strings become unnamed (null), not "".
    final String? normalizedName =
        (displayName == null || displayName.isEmpty) ? null : displayName;
    return SourcePoolDefinition._(
      id: id,
      displayName: normalizedName,
      persistencePolicy: persistencePolicy,
      orderedSourceReferences: List<SourceReference>.unmodifiable(
        orderedSourceReferences,
      ),
    );
  }

  const SourcePoolDefinition._({
    required this.id,
    required this.displayName,
    required this.persistencePolicy,
    required this.orderedSourceReferences,
  });

  final String id;
  final String? displayName;
  final PersistencePolicy persistencePolicy;
  final List<SourceReference> orderedSourceReferences;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SourcePoolDefinition) {
      return false;
    }
    if (id != other.id ||
        displayName != other.displayName ||
        persistencePolicy != other.persistencePolicy) {
      return false;
    }
    if (orderedSourceReferences.length !=
        other.orderedSourceReferences.length) {
      return false;
    }
    for (var i = 0; i < orderedSourceReferences.length; i++) {
      if (orderedSourceReferences[i] != other.orderedSourceReferences[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        persistencePolicy,
        Object.hashAll(orderedSourceReferences),
      );
}
