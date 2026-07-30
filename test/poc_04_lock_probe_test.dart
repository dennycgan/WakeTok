import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';
import 'package:waketok/spikes/poc_04/poc_04_lock_probe.dart';

Poc04AssetDto _img(String id) => Poc04AssetDto(
      assetId: id,
      mediaType: Poc04MediaType.image,
      pixelWidth: 10,
      pixelHeight: 10,
    );

Poc04AssetDto _vid(String id) => Poc04AssetDto(
      assetId: id,
      mediaType: Poc04MediaType.video,
      pixelWidth: 10,
      pixelHeight: 10,
      durationSeconds: 1,
    );

void main() {
  test('buildPlaybackPlan filters images and keeps feed indices', () {
    final items = <Poc04AssetDto>[
      _img('i0'),
      _vid('v0'),
      _img('i1'),
      _vid('v1'),
      _vid('v2'),
    ];
    final plan = buildPlaybackPlan(items);
    expect(plan.map((e) => e.assetId).toList(), ['v0', 'v1', 'v2']);
    expect(plan.map((e) => e.feedIndex).toList(), [1, 3, 4]);
  });

  test('formatLockProbeHud includes core fields', () {
    final hud = formatLockProbeHud(
      Poc04LockProbeState(
        enabled: true,
        layerDetached: true,
        playing: true,
        planIndex: 1,
        feedIndex: 3,
        activeAssetId: 'abcdefghijklmnop',
        lastEvent: 'detached',
      ),
    );
    expect(hud, contains('lock=ON'));
    expect(hud, contains('det=Y'));
    expect(hud, contains('play=Y'));
    expect(hud, contains('plan=1'));
    expect(hud, contains('feed=3'));
    expect(hud, contains('id=abcdefgh'));
    expect(hud, contains('detached'));
  });
}
