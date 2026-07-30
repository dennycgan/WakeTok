import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';

/// Builds a video-only playback plan from a mixed feed (images filtered out).
List<Poc04PlaybackPlanItem> buildPlaybackPlan(List<Poc04AssetDto> items) {
  final plan = <Poc04PlaybackPlanItem>[];
  for (var i = 0; i < items.length; i++) {
    if (items[i].mediaType == Poc04MediaType.video) {
      plan.add(
        Poc04PlaybackPlanItem(assetId: items[i].assetId, feedIndex: i),
      );
    }
  }
  return plan;
}

/// Compact HUD line for lock-audio probe diagnostics.
String formatLockProbeHud(Poc04LockProbeState s) {
  final id = s.activeAssetId ?? '-';
  final short = id.length > 8 ? id.substring(0, 8) : id;
  final buf = StringBuffer('lock=')
    ..write(s.enabled ? 'ON' : 'off')
    ..write(' det=')
    ..write(s.layerDetached ? 'Y' : 'N')
    ..write(' play=')
    ..write(s.playing ? 'Y' : 'N')
    ..write(' plan=')
    ..write(s.planIndex)
    ..write(' feed=')
    ..write(s.feedIndex)
    ..write(' id=')
    ..write(short);
  if (s.lastEvent != null && s.lastEvent!.isNotEmpty) {
    buf.write(' · ${s.lastEvent}');
  }
  return buf.toString();
}
