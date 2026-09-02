import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Resolved platform Favorites glyph (icon + stable widget-test key).
class Cap19FavoritesIconData {
  const Cap19FavoritesIconData({
    required this.icon,
    required this.testKey,
  });

  final IconData icon;
  final String testKey;
}

/// Cap 19.5b: platform slot for Favorites row trailing glyph.
///
/// iOS/macOS → Photos-aligned heart. Other platforms → star (Android future).
Cap19FavoritesIconData cap19FavoritesIconData({required bool isFavorite}) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return Cap19FavoritesIconData(
        icon: isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
        testKey: isFavorite
            ? 'cap19FavoritesPlatformIconFilled'
            : 'cap19FavoritesPlatformIconOutline',
      );
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return Cap19FavoritesIconData(
        icon: isFavorite ? Icons.star : Icons.star_border,
        testKey: isFavorite
            ? 'cap19FavoritesPlatformIconFilled'
            : 'cap19FavoritesPlatformIconOutline',
      );
  }
}

/// Small platform Favorites glyph beside the row thumbnail.
class Cap19FavoritesPlatformIcon extends StatelessWidget {
  const Cap19FavoritesPlatformIcon({
    super.key,
    required this.isFavorite,
    required this.color,
    this.size = 22,
  });

  final bool isFavorite;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = cap19FavoritesIconData(isFavorite: isFavorite);
    return Icon(
      data.icon,
      key: Key(data.testKey),
      color: color,
      size: size,
    );
  }
}
