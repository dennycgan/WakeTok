import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Persisted Saved Pool Preset (Glossary §15): SPD recipe + timestamps.
///
/// Not a parallel content container. [toDefinition] is for callers that
/// already hold a valid record — save paths must not construct an SPD.
class SavedPoolRecord {
  SavedPoolRecord({
    required this.id,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    required List<SourceReference> orderedSourceReferences,
  }) : orderedSourceReferences = List<SourceReference>.unmodifiable(
          orderedSourceReferences,
        );

  final String id;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SourceReference> orderedSourceReferences;

  /// Maps this preset to a saved [SourcePoolDefinition].
  SourcePoolDefinition toDefinition() {
    return SourcePoolDefinition(
      id: id,
      displayName: displayName,
      persistencePolicy: PersistencePolicy.saved,
      orderedSourceReferences: orderedSourceReferences,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! SavedPoolRecord) {
      return false;
    }
    if (id != other.id ||
        displayName != other.displayName ||
        createdAt != other.createdAt ||
        updatedAt != other.updatedAt) {
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
        createdAt,
        updatedAt,
        Object.hashAll(orderedSourceReferences),
      );
}
