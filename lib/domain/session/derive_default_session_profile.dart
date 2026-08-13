import 'package:waketok/domain/session/default_session_profile.dart';
import 'package:waketok/domain/session/pool_profile_kind.dart';
import 'package:waketok/domain/session/session_configuration.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';

/// Classifies a pool for Default Session Profile (ADR-N / ADR-022 D2).
///
/// Cap 12: no `generatedClip` kind and no Clip Descriptor model — always
/// returns [PoolProfileKind.generalMixed]. Future Generated Clip Cap fills
/// the Pure checks (SPD all Generated Clip Sources; every Snapshot item has
/// a valid Clip Descriptor; no plain media later added to backing albums).
///
/// [definition] and [snapshot] are both required so the Pure path can use
/// them without changing the signature later. Cap 12 does not inspect them.
PoolProfileKind classifyPoolProfile({
  required SourcePoolDefinition definition,
  required ResolvedPoolSnapshot snapshot,
}) {
  // Cap 12: Generated Clip specialization absent → always Mixed (ADR-022
  // D2), including empty SPD/Snapshot. Parameters are part of the locked
  // signature for the future Pure path (SPD kinds + Clip Descriptors).
  final _ = (
    definition.orderedSourceReferences.length,
    snapshot.coalescedAssetIds.length,
  );
  return PoolProfileKind.generalMixed;
}

/// Derives the kickoff Default Session Profile for a new Consumption Session.
///
/// Returns [DefaultSessionProfile.generalMixed] for every constructible Cap
/// 12 pool. Cap 13.4 wires this profile to Main Browse Mixed tabs (ADR-023).
SessionConfiguration deriveDefaultSessionProfile({
  required SourcePoolDefinition definition,
  required ResolvedPoolSnapshot snapshot,
}) {
  return switch (classifyPoolProfile(
    definition: definition,
    snapshot: snapshot,
  )) {
    PoolProfileKind.generalMixed => DefaultSessionProfile.generalMixed,
    PoolProfileKind.pureGeneratedClip =>
      DefaultSessionProfile.pureGeneratedClip,
  };
}
