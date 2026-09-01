import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug-only persistence for Cap 19.2a Limited album-mutation spike.
///
/// Not product WakeTok album bootstrap KV (Cap 19.3).
class WaketokAlbumProbeCache {
  WaketokAlbumProbeCache._();

  static const waketokAlbumTitle = 'WakeTok';

  static const _idKey = 'waketok.debug.waketokAlbum.id';
  static const _nameKey = 'waketok.debug.waketokAlbum.name';

  static Future<String?> loadAlbumId() async {
    if (!kDebugMode) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_idKey);
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  static Future<void> save(String albumIdentifier) async {
    if (!kDebugMode) {
      return;
    }
    if (albumIdentifier.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idKey, albumIdentifier);
    await prefs.setString(_nameKey, waketokAlbumTitle);
  }

  static Future<void> clear() async {
    if (!kDebugMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idKey);
    await prefs.remove(_nameKey);
  }
}
