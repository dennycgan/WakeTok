import 'dart:async';

import 'package:flutter/material.dart';
import 'package:waketok/spikes/poc_03/generated/poc_03_playback.g.dart';
import 'package:waketok/spikes/poc_03/poc_03_checkpoint.dart';
import 'package:waketok/spikes/poc_03/poc_03_gap.dart';

/// POC-03 debug UI. Popping this route must NOT stop native playback (3.1).
class Poc03SpikePage extends StatefulWidget {
  const Poc03SpikePage({super.key});

  @override
  State<Poc03SpikePage> createState() => _Poc03SpikePageState();
}

class _Poc03SpikePageState extends State<Poc03SpikePage> {
  final Poc03PlaybackApi _api = Poc03PlaybackApi();
  Poc03PlaybackStateDto? _state;
  Poc03SessionCheckpointDto? _pendingCheckpoint;
  String? _error;
  String? _gapSummary;
  List<String> _clipIds = const [];
  Timer? _poll;
  bool _restorePromptShown = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    // Intentionally do NOT call stop() — playback must outlive this widget.
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _refresh();
    await _maybeOfferRestore();
  }

  Future<void> _maybeOfferRestore() async {
    if (_restorePromptShown || !mounted) return;
    try {
      final pending = await _api.getPendingCheckpoint();
      if (pending == null) return;
      if (!shouldOfferRestore(
        engineConfigured: false,
        pendingClipId: pending.clipId,
      )) {
        return;
      }
      _restorePromptShown = true;
      if (!mounted) return;
      setState(() => _pendingCheckpoint = pending);
      final summary = formatCheckpointSummary(
        clipId: pending.clipId,
        positionMs: pending.positionMs,
        wasPlaying: pending.wasPlaying,
      );
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore?'),
          content: Text(
            'SessionCheckpoint found.\n$summary\n\n'
            'P5=A: no auto-play until you confirm.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Dismiss'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (restore == true) {
        await _run(() => _api.restoreFromCheckpoint());
      } else {
        await _run(() => _api.dismissCheckpoint());
      }
      if (!mounted) return;
      setState(() => _pendingCheckpoint = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final state = await _api.getPlaybackState();
      final ids = await _api.listBundleClipIds();
      final gaps = await _api.getGapSamplesMs();
      final pending = await _api.getPendingCheckpoint();
      if (!mounted) return;
      setState(() {
        _state = state;
        _clipIds = ids;
        _gapSummary = formatGapSummary(gaps);
        _pendingCheckpoint = pending;
        if (!silent) _error = null;
      });
    } catch (e) {
      if (!mounted || silent) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final hud = StringBuffer()
      ..write(s == null ? 'no state' : 'playing=${s.isPlaying}')
      ..write(
        s == null
            ? ''
            : ' · #${s.currentIndex}/${s.queueLength} · ${s.currentClipId}'
                ' · ${s.positionMs}ms',
      );
    if (s != null) {
      hud.write(
        ' · int=${s.isInterrupted}/${s.interruptionCount}',
      );
      if (s.lastInterruptionSummary.isNotEmpty) {
        hud.write('\n${s.lastInterruptionSummary}');
      }
      if (s.lastRemoteCommand.isNotEmpty) {
        hud.write('\nremote=${s.lastRemoteCommand}');
      }
    }
    final ckpt = _pendingCheckpoint;
    hud.write(
      '\n${formatCheckpointSummary(
        clipId: ckpt?.clipId,
        positionMs: ckpt?.positionMs,
        wasPlaying: ckpt?.wasPlaying,
      )}',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('POC-03 playback'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '3.1: pop route — audio continues.\n'
            '3.2: lock ≥5 advances; gap p90 < 150 ms (P3=B).\n'
            '3.3: interruption; P4=A shouldResume → auto play.\n'
            '3.4: Control Center + AirPods play/pause/next.\n'
            '3.5: kill → silent; cold start Restore? (P5=A).',
          ),
          const SizedBox(height: 12),
          Text(hud.toString()),
          const SizedBox(height: 8),
          Text('Bundle clips: ${_clipIds.join(", ")}'),
          if (_gapSummary != null) ...[
            const SizedBox(height: 8),
            Text(_gapSummary!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => _run(() async {
                  await _api.configureBundleQueue();
                }),
                child: const Text('Configure queue'),
              ),
              FilledButton(
                onPressed: () => _run(() async {
                  await _api.clearGapSamples();
                  await _api.play();
                }),
                child: const Text('Play'),
              ),
              OutlinedButton(
                onPressed: () => _run(() async {
                  await _api.pause();
                }),
                child: const Text('Pause'),
              ),
              OutlinedButton(
                onPressed: () => _run(() async {
                  await _api.stop();
                }),
                child: const Text('Stop'),
              ),
              OutlinedButton(
                onPressed: () => _run(() async {
                  await _api.clearGapSamples();
                }),
                child: const Text('Clear gaps'),
              ),
              OutlinedButton(
                onPressed: () => _refresh(),
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Manual 3.5 (SessionCheckpoint, P5=A):\n'
            '1) Configure → Play (let it advance a few seconds)\n'
            '2) Force-quit WakeTok (swipe up) — audio must stop\n'
            '3) Relaunch → open POC-03 — expect Restore? dialog (no auto-play)\n'
            '4) Restore → resumes near checkpoint; Dismiss → stays silent',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
