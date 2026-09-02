import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/library_smoke/album_cover_providers.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';

/// Favorites smart-album cover in an album-style square frame (Cap 19.5b).
class Cap19FavoritesAlbumThumbnail extends ConsumerStatefulWidget {
  const Cap19FavoritesAlbumThumbnail({
    super.key,
    required this.size,
  });

  final double size;

  @override
  ConsumerState<Cap19FavoritesAlbumThumbnail> createState() =>
      _Cap19FavoritesAlbumThumbnailState();
}

class _Cap19FavoritesAlbumThumbnailState
    extends ConsumerState<Cap19FavoritesAlbumThumbnail> {
  Uint8List? _jpegBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final px =
        (widget.size * MediaQuery.devicePixelRatioOf(context)).round().clamp(
              1,
              512,
            );
    try {
      final bytes = await ref
          .read(albumCoverRepositoryProvider)
          .requestFavoritesSmartAlbumCoverThumbnail(targetSizePx: px);
      if (!mounted) {
        return;
      }
      setState(() {
        _jpegBytes = bytes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _jpegBytes = null;
        _loading = false;
      });
    }
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
          CupertinoIcons.heart_fill,
          color: tokens.onMedia.withValues(alpha: 0.35),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        key: const Key('cap19FavoritesAlbumThumbnail'),
        width: widget.size,
        height: widget.size,
        child: child,
      ),
    );
  }
}
