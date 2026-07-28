import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';
import 'package:waketok/spikes/poc_04/poc_04_entry.dart';
import 'package:waketok/spikes/poc_04/poc_04_feed_page.dart';

/// POC-04 Phase 2.2–2.3: Photos auth/list + entry to mixed feed.
class Poc04PlaceholderPage extends StatefulWidget {
  const Poc04PlaceholderPage({super.key});

  @override
  State<Poc04PlaceholderPage> createState() => _Poc04PlaceholderPageState();
}

class _Poc04PlaceholderPageState extends State<Poc04PlaceholderPage> {
  final Poc04PhotoLibraryApi _api = Poc04PhotoLibraryApi();

  Poc04AuthStatus? _status;
  List<Poc04AssetDto> _assets = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _api.getAuthorizationStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestAuth() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await _api.requestAuthorization();
      if (!mounted) return;
      setState(() => _status = status);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _listAssets() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final assets = await _api.listLocalMixedAssets(100);
      if (!mounted) return;
      setState(() => _assets = assets);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '${e.code}: ${e.message}';
        _assets = const [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _assets = const [];
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POC-04 spike'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'POC-04 · Phase 2.2 / 2.3',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Photos authorization + list device-local image/video PHAssets. '
              'Open feed for Fit-only mixed vertical playback (pool 1+1).',
            ),
            if (!canPop && kPoc04SpikeAsHome) ...[
              const SizedBox(height: 8),
              Text(
                'Opened as home via POC04_SPIKE=true (no back). '
                'Re-run without the define to use Demo home + POC-04 button.',
                style: TextStyle(color: Theme.of(context).colorScheme.secondary),
              ),
            ],
            const SizedBox(height: 16),
            Text('Auth status: ${_status?.name ?? '—'}'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : _requestAuth,
                  child: const Text('Request Photos access'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _refreshStatus,
                  child: const Text('Refresh status'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : _listAssets,
                  child: const Text('List local assets (≤100)'),
                ),
                FilledButton(
                  onPressed: _busy || _assets.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Poc04FeedPage(assets: _assets),
                            ),
                          );
                        },
                  child: const Text('Open feed'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Listed: ${_assets.length}'),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _assets.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final asset = _assets[index];
                  final meta = StringBuffer()
                    ..write(asset.mediaType.name)
                    ..write(' · ')
                    ..write('${asset.pixelWidth ?? '?'}×${asset.pixelHeight ?? '?'}');
                  if (asset.durationSeconds != null) {
                    meta.write(' · ${asset.durationSeconds!.toStringAsFixed(1)}s');
                  }
                  return ListTile(
                    dense: true,
                    title: Text(
                      asset.assetId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(meta.toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
