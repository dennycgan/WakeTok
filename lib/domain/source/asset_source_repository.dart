import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Domain port for built-in Asset Source list / resolve (Cap 6 / ADR-013).
///
/// Separate from catalog repository (ADR-011). No Riverpod (ADR-010).
/// Errors surface as channel PlatformExceptions (same pattern as catalog).
abstract class AssetSourceRepository {
  /// Cap 6: the three built-ins only (All / Photos / Videos).
  Future<List<AssetSource>> listBuiltInSources();

  /// Full ordered id list for [reference] (D1=A).
  Future<ResolvedSource> resolve(SourceReference reference);
}

