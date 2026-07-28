import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';
import 'package:waketok/spikes/poc_04/poc_04_feed_controller.dart';
import 'package:waketok/spikes/poc_04/poc_04_first_frame.dart';
import 'package:waketok/spikes/poc_04/poc_04_probe.dart';

/// POC-04 feed: PV / Texture toggle (T1=B), probes, first-frame timing.
class Poc04FeedPage extends StatefulWidget {
  const Poc04FeedPage({super.key, required this.assets});

  final List<Poc04AssetDto> assets;

  @override
  State<Poc04FeedPage> createState() => _Poc04FeedPageState();
}

class _Poc04FeedPageState extends State<Poc04FeedPage> {
  late final PageController _pageController;
  late final Poc04FeedController _controller;
  final Poc04MediaBridge _bridge = Poc04PigeonMediaBridge();

  Poc04PoolDiagnostics? _diagnostics;
  String? _probeResult;
  String? _ffSummary;
  bool _busyProbe = false;
  String? _pageError;
  bool _probeOwnsPaging = false;

  /// T1=B: default Texture (Conditional escape). Toggle to compare hitch vs PV.
  bool _useTexture = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controller = Poc04FeedController(bridge: _bridge, items: widget.assets);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bridge.setUseTextureSurface(_useTexture);
      await _applyPage(0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleSurface() async {
    final next = !_useTexture;
    setState(() {
      _useTexture = next;
      _controller.activeTextureId = -1;
    });
    await _bridge.setUseTextureSurface(next);
    await _applyPage(_controller.index);
  }

  Future<void> _refreshFfSummary() async {
    final samples = await _bridge.getFirstFrameSamples();
    if (!mounted) return;
    setState(() => _ffSummary = formatFirstFrameSummary(samples));
  }

  Future<void> _awaitFirstFrameIfVideo(int index) async {
    if (index < 0 || index >= widget.assets.length) return;
    if (widget.assets[index].mediaType != Poc04MediaType.video) return;
    try {
      await _bridge.waitActiveFirstFrameMs(kPoc04FirstFrameTimeoutMs);
      await _refreshFfSummary();
    } catch (_) {}
  }

  Future<void> _applyPage(int index) async {
    if (_probeOwnsPaging) return;
    try {
      await _controller.onPageChanged(index);
      final d = await _bridge.getPoolDiagnostics();
      if (!mounted) return;
      // setState after attach returned textureId (or -1 for PV).
      setState(() {
        _diagnostics = d;
        _pageError = null;
      });
      unawaited(_awaitFirstFrameIfVideo(index));
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _pageError = '${e.code}: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pageError = e.toString());
    }
  }

  Future<void> _runLeakProbe({required int transitions}) async {
    if (widget.assets.length < 2) {
      setState(() => _probeResult = 'Need ≥2 assets for probe');
      return;
    }
    setState(() {
      _busyProbe = true;
      _probeOwnsPaging = true;
      _probeResult = 'Running n=$transitions…';
    });
    try {
      await _bridge.releaseAllImageTempFiles();
      _controller.imagePaths.clear();

      final samples = <Poc04ProbeSample>[];
      await _controller.onPageChanged(_controller.index);
      final before = await _bridge.getPoolDiagnostics();
      samples.add(Poc04ProbeSample.fromDiagnostics(0, before));

      for (var step = 0; step < transitions; step++) {
        final next = (step + 1) % widget.assets.length;
        _pageController.jumpToPage(next);
        await _controller.onPageChanged(next);
        final d = await _bridge.getPoolDiagnostics();
        samples.add(Poc04ProbeSample.fromDiagnostics(step + 1, d));
        if (!mounted) return;
        if (step % 10 == 9 || step == transitions - 1) {
          setState(() => _diagnostics = d);
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final evaluation = evaluatePoc04Probe(
        samples: samples,
        transitions: transitions,
      );
      if (!mounted) return;
      final last = samples.last;
      setState(() {
        _diagnostics = Poc04PoolDiagnostics(
          activeCount: last.activeCount,
          warmingCount: last.warmingCount,
          tempFileCount: last.tempFileCount,
        );
        _probeResult = evaluation.summary;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _probeResult = 'Probe error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyProbe = false;
          _probeOwnsPaging = false;
        });
      } else {
        _probeOwnsPaging = false;
      }
    }
  }

  Future<void> _runFirstFrameProbe() async {
    final videoIndices = <int>[];
    for (var i = 0; i < widget.assets.length; i++) {
      if (widget.assets[i].mediaType == Poc04MediaType.video) {
        videoIndices.add(i);
      }
    }
    if (videoIndices.length < 2) {
      setState(() => _probeResult = 'Need ≥2 local videos for FF probe');
      return;
    }

    setState(() {
      _busyProbe = true;
      _probeOwnsPaging = true;
      _probeResult = 'FF probe…';
    });
    try {
      await _bridge.clearFirstFrameSamples();
      const target = kPoc04FirstFrameSampleTarget;
      for (var n = 0; n < target; n++) {
        final index = videoIndices[n % videoIndices.length];
        _pageController.jumpToPage(index);
        await _controller.onPageChanged(index);
        if (!mounted) return;
        setState(() {}); // show textureId after attach returned
        await _bridge.waitActiveFirstFrameMs(kPoc04FirstFrameTimeoutMs);
        if (!mounted) return;
        if (n % 5 == 4 || n == target - 1) {
          final samples = await _bridge.getFirstFrameSamples();
          setState(() {
            _ffSummary = formatFirstFrameSummary(samples);
            _probeResult = 'FF ${n + 1}/$target';
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final samples = await _bridge.getFirstFrameSamples();
      final p90 = poc04Percentile(samples, 90);
      final pass = samples.length >= target && p90 < 500;
      if (!mounted) return;
      setState(() {
        _ffSummary = formatFirstFrameSummary(samples);
        _probeResult =
            '${pass ? 'PASS' : 'FAIL'} ${formatFirstFrameSummary(samples)} '
            '(target p90<500; warming-assisted; '
            '${_useTexture ? 'Texture' : 'PV'})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _probeResult = 'FF probe error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busyProbe = false;
          _probeOwnsPaging = false;
        });
      } else {
        _probeOwnsPaging = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _diagnostics;
    final hud = StringBuffer()
      ..write('#${_controller.index} ')
      ..write(
        widget.assets.isEmpty
            ? 'empty'
            : widget.assets[_controller.index].mediaType.name,
      );
    hud.write(_useTexture ? ' · Tex' : ' · PV');
    if (_useTexture && _controller.activeTextureId >= 0) {
      hud.write(' id=${_controller.activeTextureId}');
    }
    if (d != null) {
      hud.write(' · pool ${d.activeCount}+${d.warmingCount}');
      hud.write(' · tmp ${d.tempFileCount}');
    }
    if (_ffSummary != null) {
      hud.write(' · $_ffSummary');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('POC-04 feed'),
        actions: [
          TextButton(
            onPressed: _busyProbe ? null : _toggleSurface,
            child: Text(_useTexture ? '→PV' : '→Tex'),
          ),
          TextButton(
            onPressed: _busyProbe ? null : () => _runLeakProbe(transitions: 30),
            child: const Text('P30'),
          ),
          TextButton(
            onPressed:
                _busyProbe ? null : () => _runLeakProbe(transitions: 100),
            child: const Text('P100'),
          ),
          TextButton(
            onPressed: _busyProbe ? null : _runFirstFrameProbe,
            child: const Text('FF20'),
          ),
        ],
      ),
      body: widget.assets.isEmpty
          ? const Center(
              child: Text(
                'No local assets to show',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: widget.assets.length,
                  onPageChanged: _applyPage,
                  itemBuilder: (context, index) {
                    final asset = widget.assets[index];
                    if (asset.mediaType == Poc04MediaType.image) {
                      return _ImagePage(
                        assetId: asset.assetId,
                        path: _controller.imagePaths[asset.assetId],
                      );
                    }
                    return _VideoPage(
                      assetId: asset.assetId,
                      useTexture: _useTexture,
                      // Only the active page should bind the live textureId.
                      textureId: index == _controller.index
                          ? _controller.activeTextureId
                          : -1,
                    );
                  },
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 8,
                  child: IgnorePointer(
                    child: Text(
                      hud.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                      ),
                    ),
                  ),
                ),
                if (_pageError != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 48,
                    child: Text(
                      _pageError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (_probeResult != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: Text(
                      _probeResult!,
                      style: TextStyle(
                        color: _probeResult!.startsWith('PASS')
                            ? Colors.lightGreenAccent
                            : _probeResult!.startsWith('Running') ||
                                    _probeResult!.startsWith('FF')
                                ? Colors.white70
                                : Colors.orangeAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.assetId, required this.path});

  final String assetId;
  final String? path;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: path == null
          ? const Center(child: CircularProgressIndicator())
          : Image.file(
              File(path!),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, error, _) => Center(
                child: Text(
                  'Image error\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ),
    );
  }
}

class _VideoPage extends StatelessWidget {
  const _VideoPage({
    required this.assetId,
    required this.useTexture,
    required this.textureId,
  });

  final String assetId;
  final bool useTexture;
  final int textureId;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const Center(
        child: Text(
          'Video is iOS-only in POC-04',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (useTexture) {
      // Ordering contract: black placeholder until textureId arrives from
      // attachActiveVideo (native register completed before the Future returns).
      // Do not construct Texture(textureId) with a speculative/pending id.
      if (textureId < 0) {
        return const ColoredBox(color: Colors.black);
      }
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              height: MediaQuery.sizeOf(context).height,
              child: Texture(textureId: textureId),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: UiKitView(
        viewType: kPoc04AvPlayerViewType,
        layoutDirection: TextDirection.ltr,
        creationParams: <String, dynamic>{'assetId': assetId},
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      ),
    );
  }
}
