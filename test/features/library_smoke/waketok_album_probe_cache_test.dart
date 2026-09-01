import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/features/library_smoke/waketok_album_probe_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('T-19.2a-1 WaketokAlbumProbeCache is debug-only', () async {
    final result = await WaketokAlbumProbeCache.loadAlbumId();
    if (kDebugMode) {
      await WaketokAlbumProbeCache.save('album-test-id');
      expect(await WaketokAlbumProbeCache.loadAlbumId(), 'album-test-id');
      await WaketokAlbumProbeCache.clear();
      expect(await WaketokAlbumProbeCache.loadAlbumId(), isNull);
    } else {
      expect(result, isNull);
    }
  });

  test('T-19.2a-1b WaketokAlbumProbeCache ignores empty save', () async {
    if (!kDebugMode) {
      return;
    }
    await WaketokAlbumProbeCache.clear();
    await WaketokAlbumProbeCache.save('');
    expect(await WaketokAlbumProbeCache.loadAlbumId(), isNull);
  });
}
