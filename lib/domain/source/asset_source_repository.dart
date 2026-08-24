import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Domain port for Asset Source list / resolve (Cap 6 / ADR-013; Cap 11.2).
///
/// Separate from catalog repository (ADR-011). No Riverpod (ADR-010).
/// Errors surface as channel PlatformExceptions (same pattern as catalog).
abstract class AssetSourceRepository {
  /// Full Access: built-ins + User Albums + Smart Albums.
  /// Limited: built-ins only (albums omitted — ADR-021 / ADR-K).
  Future<List<AssetSource>> listAssetSources();

  /// Full ordered id list for [reference] (D1=A).
  /// Cap 11.2: still built-in pairs only on the Host (album resolve = 11.3).
  ///
  /// Cap 15.15: production resolve does **not** populate
  /// [ResolvedSource.assetAvailabilityById] (empty map). Use
  /// [getAssetAvailabilities] on become-current.
  Future<ResolvedSource> resolve(SourceReference reference);

  /// Cap 15.15: on-demand availability for specific ids (become-current).
  ///
  /// Unknown ids map to [AssetAvailability.unavailable]. Order of [ids]
  /// is preserved in the returned map keys only (lookup by id).
  Future<Map<String, AssetAvailability>> getAssetAvailabilities(
    List<String> ids,
  );
}
