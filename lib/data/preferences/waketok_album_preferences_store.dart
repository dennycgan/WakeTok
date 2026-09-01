import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/domain/library/waketok_album_store.dart';

/// Product WakeTok album KV (Cap 19.3). Not the 19.2a debug probe cache.
class WakeTokAlbumPreferencesStore implements WakeTokAlbumStore {
  WakeTokAlbumPreferencesStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _albumIdKey = 'waketok.waketokAlbum.localIdentifier';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<String?> loadAlbumId() async {
    final prefs = await _prefs();
    final id = prefs.getString(_albumIdKey);
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  @override
  Future<void> saveAlbumId(String albumIdentifier) async {
    if (albumIdentifier.isEmpty) {
      return;
    }
    final prefs = await _prefs();
    await prefs.setString(_albumIdKey, albumIdentifier);
  }

  @override
  Future<void> clearAlbumId() async {
    final prefs = await _prefs();
    await prefs.remove(_albumIdKey);
  }
}
