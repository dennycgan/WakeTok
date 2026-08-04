import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 7.3 debug probe: one local image via temp file + one video via PV.
///
/// Not Main Browse. Local-only host policy — iCloud-only surfaces as error copy.
class PlaybackPipelineProbeSection extends ConsumerStatefulWidget {
  const PlaybackPipelineProbeSection({super.key});

  static const String playbackViewType = 'waketok/playback_surface';

  @override
  ConsumerState<PlaybackPipelineProbeSection> createState() =>
      _PlaybackPipelineProbeSectionState();
}

class _PlaybackPipelineProbeSectionState
    extends ConsumerState<PlaybackPipelineProbeSection> {
  bool _busy = false;
  String? _status;
  String? _imagePath;
  String? _videoId;
  bool _videoReady = false;

  Future<void> _loadImage() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _status = null;
      _imagePath = null;
    });
    try {
      final resolved = await ref
          .read(assetSourceRepositoryProvider)
          .resolve(SourceReference.photos);
      if (resolved.assetIdentifiers.isEmpty) {
        setState(() => _status = l10n.playbackProbeNoAssets);
        return;
      }
      final id = resolved.assetIdentifiers.first;
      final display =
          await ref.read(mediaDisplayRepositoryProvider).requestDisplayAsset(id);
      if (!mounted) {
        return;
      }
      setState(() {
        _imagePath = display.localFilePath;
        _status = l10n.playbackProbeImageOk;
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.code == 'iCloudDownloadRequired'
            ? l10n.playbackProbeICloudOnly
            : l10n.playbackProbeFailed;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _status = l10n.playbackProbeFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _loadVideo() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _status = null;
      _videoId = null;
      _videoReady = false;
    });
    try {
      final resolved = await ref
          .read(assetSourceRepositoryProvider)
          .resolve(SourceReference.videos);
      if (resolved.assetIdentifiers.isEmpty) {
        setState(() => _status = l10n.playbackProbeNoAssets);
        return;
      }
      final id = resolved.assetIdentifiers.first;
      await ref.read(mediaDisplayRepositoryProvider).requestPlayableVideo(id);
      final playback = ref.read(playbackRepositoryProvider);
      await playback.setPlaybackPlan(
        PlaybackPlan(
          planId: 'cap73-probe',
          orderedItems: [
            PlaybackItem(
              assetIdentifier: id,
              feedIndex: 0,
              mediaKind: PlaybackMediaKind.video,
            ),
          ],
          currentIndex: 0,
        ),
      );
      await playback.load(
        PlaybackItem(
          assetIdentifier: id,
          feedIndex: 0,
          mediaKind: PlaybackMediaKind.video,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _videoId = id;
        _status = l10n.playbackProbeVideoReady;
      });
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = e.code == 'iCloudDownloadRequired'
            ? l10n.playbackProbeICloudOnly
            : l10n.playbackProbeFailed;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _status = l10n.playbackProbeFailed);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _play() async {
    await ref.read(playbackRepositoryProvider).play();
  }

  Future<void> _pause() async {
    await ref.read(playbackRepositoryProvider).pause();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            l10n.playbackProbeSectionTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.onSurface,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : _loadImage,
                child: Text(l10n.playbackProbeLoadImage),
              ),
              FilledButton(
                onPressed: _busy ? null : _loadVideo,
                child: Text(l10n.playbackProbeLoadVideo),
              ),
              OutlinedButton(
                onPressed: _videoId == null || _busy ? null : _play,
                child: Text(l10n.playbackProbePlay),
              ),
              OutlinedButton(
                onPressed: _videoId == null || _busy ? null : _pause,
                child: Text(l10n.playbackProbePause),
              ),
            ],
          ),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _status!,
              key: const Key('playbackProbeStatus'),
              style: bodyStyle,
            ),
          ),
        if (_imagePath != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ColoredBox(
              color: tokens.feedBackground,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: Image.file(
                  File(_imagePath!),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(l10n.playbackProbeFailed, style: bodyStyle),
                  ),
                ),
              ),
            ),
          ),
        if (_videoId != null && defaultTargetPlatform == TargetPlatform.iOS)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: ColoredBox(
              color: tokens.feedBackground,
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: UiKitView(
                  viewType: PlaybackPipelineProbeSection.playbackViewType,
                  creationParams: _videoId,
                  creationParamsCodec: const StandardMessageCodec(),
                  gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                  onPlatformViewCreated: (_) async {
                    final id = _videoId;
                    if (id == null) {
                      return;
                    }
                    await ref
                        .read(playbackRepositoryProvider)
                        .notifyDisplaySurfaceReady(id);
                    if (mounted) {
                      setState(() => _videoReady = true);
                    }
                  },
                ),
              ),
            ),
          ),
        if (_videoReady)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l10n.playbackProbeSurfaceReady, style: bodyStyle),
          ),
      ],
    );
  }
}
