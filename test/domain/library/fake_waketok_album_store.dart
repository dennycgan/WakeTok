import 'package:waketok/domain/library/waketok_album_store.dart';

class FakeWakeTokAlbumStore implements WakeTokAlbumStore {
  String? albumId;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<void> clearAlbumId() async {
    clearCalls += 1;
    albumId = null;
  }

  @override
  Future<String?> loadAlbumId() async => albumId;

  @override
  Future<void> saveAlbumId(String albumIdentifier) async {
    saveCalls += 1;
    albumId = albumIdentifier;
  }
}
