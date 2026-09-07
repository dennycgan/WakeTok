import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/library_smoke/album_cover_providers.dart';

/// Photos-style square album cover for Cap 19.5 picker rows.
class Cap19AlbumCoverThumbnail extends ConsumerStatefulWidget {
  const Cap19AlbumCoverThumbnail({
    super.key,
    required this.albumId,
    required this.size,
  });

  final String albumId;
  final double size;

  @override
  ConsumerState<Cap19AlbumCoverThumbnail> createState() =>
      _Cap19AlbumCoverThumbnailState();
}

class _Cap19AlbumCoverThumbnailState
    extends ConsumerState<Cap19AlbumCoverThumbnail> {
  Uint8List? _jpegBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(covariant Cap19AlbumCoverThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId) {
      _jpegBytes = null;
      _loading = true;
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    final px =
        (widget.size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
              1,
              512,
            );
    // Cap 21.5 P4: deleted / hanging Host cover must not spin forever.
    Uint8List? bytes;
    try {
      bytes = await ref
          .read(albumCoverRepositoryProvider)
          .requestCoverThumbnail(widget.albumId, targetSizePx: px)
          .timeout(const Duration(seconds: 3));
    } on Object {
      bytes = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _jpegBytes = bytes;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final radius = BorderRadius.circular(4);

    Widget child;
    if (_loading) {
      child = ColoredBox(
        color: tokens.onMedia.withValues(alpha: 0.08),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_jpegBytes != null) {
      child = Image.memory(
        _jpegBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else {
      child = ColoredBox(
        color: tokens.onMedia.withValues(alpha: 0.08),
        child: Icon(
          CupertinoIcons.photo_on_rectangle,
          color: tokens.onMedia.withValues(alpha: 0.35),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        key: Key('cap19AlbumCover-${widget.albumId}'),
        width: widget.size,
        height: widget.size,
        child: child,
      ),
    );
  }
}
