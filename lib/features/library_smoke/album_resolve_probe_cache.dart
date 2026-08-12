import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Debug-only persistence for Cap 11.3 Limited album-resolve probe.
///
/// Survives iOS SIGKILL when Photos access changes Full → Limited while
/// `flutter run` is attached. Not product Saved Pool storage.
class AlbumResolveProbeCache {
  AlbumResolveProbeCache._();

  static const _idKey = 'waketok.debug.albumResolveProbe.id';
  static const _nameKey = 'waketok.debug.albumResolveProbe.name';

  /// Loads a previously saved User Album ref, or null.
  static Future<({SourceReference ref, String name})?> load() async {
    if (!kDebugMode) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      return null;
    }
    final name = prefs.getString(_nameKey) ?? '';
    return (
      ref: SourceReference(kind: AssetSourceKind.album, id: id),
      name: name,
    );
  }

  /// Persists [ref] after a successful Full-Access User Album resolve.
  static Future<void> save(SourceReference ref, String displayName) async {
    if (!kDebugMode) {
      return;
    }
    if (ref.kind != AssetSourceKind.album || ref.id.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, ref.id);
    await prefs.setString(_nameKey, displayName);
  }
}
