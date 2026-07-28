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

    return Scaffold(
      appBar: AppBar(title: const Text('POC-09 export representation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '9.1 smoke done. 9.2 Trim gate:\n'
            'Photos-trim a local video (save edit) → List → select → Probe+Export.\n'
            'Expect trimGate=PASS: orig-cur>2s AND exp≈cur (±0.25s).',
          ),
          const SizedBox(height: 12),
          Text('auth=${_auth?.name ?? "—"}'),
          Text(probeHud),
          if (trimHud.isNotEmpty) Text(trimHud),
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
                          setState(() {
                            _videos = list;
                            if (list.isEmpty) {
                              _selected = null;
                              return;
                            }
                            final prevId = _selected?.assetId;
                            _selected = list
                                .where((v) => v.assetId == prevId)
                                .followedBy(list)
                                .first;
                          });
                        }),
                child: const Text('List local videos'),
              ),
              FilledButton(
                onPressed: _busy || _selected == null
                    ? null
                    : () => _run(() async {
                          final r = await _api.probeAndExport(
                            _selected!.assetId,
                            _networkAccessAllowed,
                          );
                          setState(() => _probe = r);
                        }),
                child: const Text('Probe+Export'),
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
          Text('Videos (${_videos.length}):'),
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
                  : () => setState(() {
                        _selected = v;
                        _probe = null;
                      }),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Manual 9.2 (Trim / F1):\n'
            '1) Photos → open a longer local video → Edit → Trim → Done → Save Video\n'
            '   (trim enough that original − trimmed > 2 seconds)\n'
            '2) WakeTok POC-09 → List local videos → select the trimmed one\n'
            '   (list duration should be the trimmed length ≈ Photos)\n'
            '3) Probe+Export → expect trimGate=PASS\n'
            '4) FAIL if exp≈orig (silent fallback) or origLonger false on a real trim',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
