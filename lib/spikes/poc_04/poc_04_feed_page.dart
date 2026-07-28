import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';
import 'package:waketok/spikes/poc_04/poc_04_feed_controller.dart';

/// POC-04 Phase 2.3: mixed vertical feed (Fit only, pool 1+1).
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
  bool _busyProbe = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _controller = Poc04FeedController(bridge: _bridge, items: widget.assets);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPage(0);
    });
  }

  @override
  void dispose() {
    // Best-effort async cleanup; spike teardown.
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _applyPage(int index) async {
    try {
      await _controller.onPageChanged(index);
      final d = await _bridge.getPoolDiagnostics();
      if (!mounted) return;
      setState(() {
        _diagnostics = d;
        _pageError = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _pageError = '${e.code}: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _pageError = e.toString());
    }
  }

  Future<void> _runLeakProbe({int transitions = 30}) async {
    if (widget.assets.length < 2) {
      setState(() => _probeResult = 'Need ≥2 assets for probe');
      return;
    }
    setState(() {
      _busyProbe = true;
      _probeResult = null;
    });
    try {
      final before = await _bridge.getPoolDiagnostics();
      for (var step = 0; step < transitions; step++) {
        final next = (step + 1) % widget.assets.length;
        await _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 80),
          curve: Curves.linear,
        );
        await _applyPage(next);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      final after = await _bridge.getPoolDiagnostics();
      final okPool = Poc04FeedController.poolWithinCap(after) &&
          Poc04FeedController.poolWithinCap(before);
      final okTemp = after.tempFileCount <= kPoc04TempFileSoftCap + 2;
      setState(() {
        _diagnostics = after;
        _probeResult = okPool && okTemp
            ? 'PASS pool=${after.activeCount}+${after.warmingCount} '
                'tmp=${after.tempFileCount} (n=$transitions)'
            : 'FAIL pool=${after.activeCount}+${after.warmingCount} '
                'tmp=${after.tempFileCount} (n=$transitions)';
      });
    } catch (e) {
      setState(() => _probeResult = 'Probe error: $e');
    } finally {
      if (mounted) setState(() => _busyProbe = false);
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
    if (d != null) {
      hud.write(' · pool ${d.activeCount}+${d.warmingCount}');
      hud.write(' · tmp ${d.tempFileCount}');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: const Text('POC-04 feed'),
        actions: [
          TextButton(
            onPressed: _busyProbe ? null : () => _runLeakProbe(),
            child: const Text('Leak probe'),
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
                    return _VideoPage(assetId: asset.assetId);
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
                        fontSize: 12,
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
                            : Colors.orangeAccent,
                        fontSize: 12,
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
  const _VideoPage({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context) {
    // Platform View is iOS-only for this spike.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return const Center(
        child: Text(
          'Video Platform View is iOS-only in POC-04',
          style: TextStyle(color: Colors.white70),
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
