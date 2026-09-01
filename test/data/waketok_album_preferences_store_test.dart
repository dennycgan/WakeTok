import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/data/preferences/waketok_album_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('T-19.3-7 product WakeTok album KV round-trips', () async {
    final store = WakeTokAlbumPreferencesStore();
    expect(await store.loadAlbumId(), isNull);

    await store.saveAlbumId('album-product-1');
    expect(await store.loadAlbumId(), 'album-product-1');

    await store.clearAlbumId();
    expect(await store.loadAlbumId(), isNull);
  });

  test('T-19.3-7b product store ignores empty save', () async {
    final store = WakeTokAlbumPreferencesStore();
    await store.saveAlbumId('');
    expect(await store.loadAlbumId(), isNull);
  });
}
