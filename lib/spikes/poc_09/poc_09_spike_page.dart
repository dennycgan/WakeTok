import 'package:flutter/material.dart';
import 'package:waketok/spikes/poc_09/generated/poc_09_export.g.dart';
import 'package:waketok/spikes/poc_09/poc_09_duration.dart';

/// POC-09 debug UI: probe current vs original representation and export.
class Poc09SpikePage extends StatefulWidget {
  const Poc09SpikePage({super.key});

  @override
  State<Poc09SpikePage> createState() => _Poc09SpikePageState();
}

class _Poc09SpikePageState extends State<Poc09SpikePage> {
  final Poc09ExportApi _api = Poc09ExportApi();
  Poc09AuthStatus? _auth;
  List<Poc09VideoAssetDto> _videos = const [];
  /// `local` or `cloudOnly` — last list mode for HUD label.
  String _listMode = 'local';
  Poc09VideoAssetDto? _selected;
  Poc09ProbeResultDto? _probe;
  String? _error;
  bool _busy = false;
  bool _networkAccessAllowed = true;

  @override
  void initState() {
    super.initState();
    _refreshAuth();
  }

  @override
  void dispose() {
    // Best-effort; ignore channel errors if engine already torn down.
    _api.stopExportPlayback().catchError((_) {});
    super.dispose();
  }

  Future<void> _refreshAuth() async {
    try {
      final status = await _api.getAuthorizationStatus();
      if (!mounted) return;
      setState(() {
        _auth = status;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applyVideoList(List<Poc09VideoAssetDto> list, String mode) {
    _listMode = mode;
    _videos = list;
    _probe = null;
    if (list.isEmpty) {
      _selected = null;
      return;
    }
    final prevId = _selected?.assetId;
    _selected = list.where((v) => v.assetId == prevId).followedBy(list).first;
  }

  @override
  Widget build(BuildContext context) {
    final probeHud = _probe == null
        ? 'no probe'
        : formatProbeSummary(
            phAssetDurationSec: _probe!.phAssetDurationSec,
            currentAvDurationSec: _probe!.currentAvDurationSec,
            originalAvDurationSec: _probe!.originalAvDurationSec,
            exportDurationSec: _probe!.exportDurationSec,
            audioTrackCount: _probe!.audioTrackCount,
            textTrackCount: _probe!.textTrackCount,
            errorCode: _probe!.errorCode,
          );
    final trimHud = _probe == null
        ? ''
        : formatTrimGateSummary(
            currentAvDurationSec: _probe!.currentAvDurationSec,
            originalAvDurationSec: _probe!.originalAvDurationSec,
            exportDurationSec: _probe!.exportDurationSec,
            errorCode: _probe!.errorCode,
          );
    final sloMoHud = _probe == null
        ? ''
        : formatSloMoGateSummary(
            isHighFrameRate: _probe!.isHighFrameRate,
            phAssetDurationSec: _probe!.phAssetDurationSec,
            currentAvDurationSec: _probe!.currentAvDurationSec,
            exportDurationSec: _probe!.exportDurationSec,
            errorCode: _probe!.errorCode,
          );

    final audioHud = _probe == null
        ? ''
        : formatAudioGateSummary(
            audioTrackCount: _probe!.audioTrackCount,
            exportPath: _probe!.exportPath,
            exportDurationSec: _probe!.exportDurationSec,
            errorCode: _probe!.errorCode,
          );
    final failHud = _probe == null
        ? ''
        : formatFailGateSummary(
            networkAccessAllowed: _probe!.networkAccessAllowed,
            errorCode: _probe!.errorCode,
            exportPath: _probe!.exportPath,
          );
    final controlHud = _probe == null
        ? ''
        : formatControlGateSummary(
            networkAccessAllowed: _probe!.networkAccessAllowed,
            errorCode: _probe!.errorCode,
            exportPath: _probe!.exportPath,
            exportDurationSec: _probe!.exportDurationSec,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('POC-09 export representation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '9.6 Explicit failure (F5 iCloud-only):\n'
            'List iCloud-only → OFF Probe (failGate=PASS) → ON Probe '
            '(controlGate=PASS).\n'
            'N1 required: local + OFF must NOT be inCloudUnavailable.',
          ),
          const SizedBox(height: 12),
          Text('auth=${_auth?.name ?? "—"}'),
          Text(probeHud),
          if (trimHud.isNotEmpty) Text(trimHud),
          if (sloMoHud.isNotEmpty) Text(sloMoHud),
          if (audioHud.isNotEmpty) Text(audioHud),
          if (failHud.isNotEmpty) Text(failHud),
          if (controlHud.isNotEmpty) Text(controlHud),
          if (_probe != null)
            Text('HFR subtype=${_probe!.isHighFrameRate}'),
          if (_probe?.errorCode != null)
            Text('errorCode=${_probe!.errorCode}'),
          if (_probe?.exportPath != null) Text('path=${_probe!.exportPath}'),
          if (_probe?.errorMessage != null)
            Text(
              _probe!.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('networkAccessAllowed'),
            value: _networkAccessAllowed,
            onChanged: _busy
                ? null
                : (v) => setState(() => _networkAccessAllowed = v),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final s = await _api.requestAuthorization();
                          setState(() => _auth = s);
                        }),
                child: const Text('Authorize'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final list = await _api.listLocalVideos(40);
                          setState(() => _applyVideoList(list, 'local'));
                        }),
                child: const Text('List local videos'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          // Smaller limit: each candidate probes locality (slow).
                          final list = await _api.listCloudOnlyVideos(20);
                          setState(() => _applyVideoList(list, 'cloudOnly'));
                        }),
                child: const Text('List iCloud-only'),
              ),
              FilledButton(
                onPressed: _busy || _selected == null
                    ? null
                    : () => _run(() async {
                          await _api.stopExportPlayback();
                          final r = await _api.probeAndExport(
                            _selected!.assetId,
                            _networkAccessAllowed,
                          );
                          setState(() => _probe = r);
                        }),
                child: const Text('Probe+Export'),
              ),
              FilledButton.tonal(
                onPressed: _busy || _probe?.exportPath == null
                    ? null
                    : () => _run(() async {
                          await _api.playExport(_probe!.exportPath!);
                        }),
                child: const Text('Play export'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await _api.stopExportPlayback();
                        }),
                child: const Text('Stop playback'),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          await _api.clearExportCache();
                          setState(() => _probe = null);
                        }),
                child: const Text('Clear exports'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _refreshAuth,
                child: const Text('Refresh auth'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Videos (${_videos.length}) [$_listMode]:'),
          ..._videos.map((v) {
            final selected = _selected?.assetId == v.assetId;
            return ListTile(
              dense: true,
              selected: selected,
              title: Text(
                '${v.durationSeconds.toStringAsFixed(1)}s'
                '${v.isHighFrameRate ? " · HFR" : ""}',
              ),
              subtitle: Text(
                v.assetId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _busy
                  ? null
                  : () {
                      _api.stopExportPlayback().catchError((_) {});
                      setState(() {
                        _selected = v;
                        _probe = null;
                      });
                    },
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Manual 9.6 (Explicit failure / F5 + N1):\n'
            'P0 Authorize (limited: include target videos)\n'
            'P1 List iCloud-only — if empty, free space / pick unused clip (R1)\n'
            'OFF: network OFF → Probe F5 → failGate=PASS '
            '(error=inCloudUnavailable, no path)\n'
            'ON: same F5, network ON → controlGate=PASS (path + duration)\n'
            '    failGate=N/A (network on)\n'
            'N1 REQUIRED: List local → pick local → network OFF → Probe\n'
            '    MUST NOT be inCloudUnavailable; expect export success\n'
            'Do OFF before ON on the same F5 (ON may make it local)',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
