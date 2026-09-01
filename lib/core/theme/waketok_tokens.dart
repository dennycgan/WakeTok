part of 'waketok_theme.dart';

/// WakeTok semantic tokens (ADR-009 Decision 5; Cap 7.2 typography + scrim;
/// Cap 7.8 frozen accent + brandGold; Cap 8.2 revision on-media label
/// shadows + immersive bottom bar height).
///
/// Numeric values live only in code — never in rules or docs.
/// Resolve at runtime via `Theme.of(context).extension<WakeTokTokens>()`.
/// Light/Dark presets are library-private (`_light` / `_dark`) so features
/// cannot bypass [ThemeData] by importing static constants.
@immutable
class WakeTokTokens extends ThemeExtension<WakeTokTokens> {
  const WakeTokTokens({
    required this.background,
    required this.surface,
    required this.onSurface,
    required this.accent,
    required this.brandGold,
    required this.feedBackground,
    required this.mediaScrim,
    required this.onMedia,
    required this.onMediaMuted,
    required this.onMediaLabelShadows,
    required this.immersiveBottomBarHeight,
    required this.scrubProgressTrack,
    required this.scrubProgressPlayed,
    required this.scrubProgressLiveGhost,
    required this.scrubPreviewPlaceholderFill,
    required this.titleChrome,
    required this.labelChrome,
    required this.bodyChrome,
    required this.labelOnMedia,
    required this.bodyOnMedia,
  });

  /// Non-feed scaffold backdrop.
  final Color background;

  /// Cards, app bars, banners.
  final Color surface;

  /// Primary text and icons on [surface] / [background].
  final Color onSurface;

  /// Formal brand accent (CTA, selected chrome). Cap 7.8 freeze.
  final Color accent;

  /// Brand gold for loading indicators (not CTAs). Light/Dark same. Cap 7.8.
  final Color brandGold;

  /// Vertical media feed backdrop (same black in both modes).
  final Color feedBackground;

  /// Semi-transparent scrim over media for chrome/controls (L/D same).
  /// Not used for Browse top source chrome after ADR-016 (transparent +
  /// [onMediaLabelShadows]); retained for other on-media surfaces.
  final Color mediaScrim;

  /// High-contrast foreground on media (L/D same).
  final Color onMedia;

  /// Secondary foreground on media (L/D same).
  final Color onMediaMuted;

  /// Text shadows for floating on-media labels (L/D same). ADR-016.
  final List<Shadow> onMediaLabelShadows;

  /// Compact Main Browse destination row height (L/D same). ADR-016.
  /// Excludes the Home Indicator inset — that zone is painted separately
  /// in the same [surface] so M3 [NavigationBar]'s inner SafeArea does not
  /// inflate the grey bar into a two-row-tall block.
  final double immersiveBottomBarHeight;

  /// Cap 18.5 video scrubber track (unfilled portion).
  final Color scrubProgressTrack;

  /// Cap 18.5 video scrubber played fill.
  final Color scrubProgressPlayed;

  /// Cap 19.2d live playhead ghost while scrub-dragging (under primary fill).
  /// Initial alpha ~30% white — pending device visual confirm; may retune.
  final Color scrubProgressLiveGhost;

  /// Cap 18.5 scrub preview bubble non-photographic placeholder.
  final Color scrubPreviewPlaceholderFill;

  /// Top bar / AppBar title role.
  final TextStyle titleChrome;

  /// Top tabs / bottom bar labels.
  final TextStyle labelChrome;

  /// Secondary chrome copy (stubs, hints).
  final TextStyle bodyChrome;

  /// Short on-media labels (e.g. LIVE badge).
  final TextStyle labelOnMedia;

  /// Secondary on-media copy (overlay reserve).
  final TextStyle bodyOnMedia;

  // Shared type sizes (L/D identical); colors differ per mode for chrome.
  static const double _titleChromeSize = 20;
  static const double _labelChromeSize = 14;
  static const double _bodyChromeSize = 14;
  static const double _labelOnMediaSize = 12;
  static const double _bodyOnMediaSize = 13;
  static const double _immersiveBottomBarHeight = 48;

  /// Single-layer shadow: black ~54% alpha, blur 6, offset (0, 1).
  static const List<Shadow> _onMediaLabelShadows = <Shadow>[
    Shadow(
      color: Color(0x8A000000),
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  static const WakeTokTokens _light = WakeTokTokens(
    background: Color(0xFFF4F4F5),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1A1A),
    accent: Color(0xFFFC2555),
    brandGold: Color(0xFFE0C590),
    feedBackground: Color(0xFF000000),
    mediaScrim: Color(0x99000000),
    onMedia: Color(0xFFFFFFFF),
    onMediaMuted: Color(0xB3FFFFFF),
    onMediaLabelShadows: _onMediaLabelShadows,
    immersiveBottomBarHeight: _immersiveBottomBarHeight,
    scrubProgressTrack: Color(0x66FFFFFF),
    scrubProgressPlayed: Color(0xFFFFFFFF),
    // Initial ~30% white — Cap 19.2d; retune after device smoke if needed.
    scrubProgressLiveGhost: Color(0x4DFFFFFF),
    // Opaque — semi-transparent fill lets video show through JPEG decode gaps.
    scrubPreviewPlaceholderFill: Color(0xFF000000),
    titleChrome: TextStyle(
      fontSize: _titleChromeSize,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: Color(0xFF1A1A1A),
    ),
    labelChrome: TextStyle(
      fontSize: _labelChromeSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: Color(0xFF1A1A1A),
    ),
    bodyChrome: TextStyle(
      fontSize: _bodyChromeSize,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: Color(0xFF1A1A1A),
    ),
    labelOnMedia: TextStyle(
      fontSize: _labelOnMediaSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: Color(0xFFFFFFFF),
    ),
    bodyOnMedia: TextStyle(
      fontSize: _bodyOnMediaSize,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: Color(0xB3FFFFFF),
    ),
  );

  static const WakeTokTokens _dark = WakeTokTokens(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFF5F5F5),
    accent: Color(0xFFFF6B8A),
    brandGold: Color(0xFFE0C590),
    feedBackground: Color(0xFF000000),
    mediaScrim: Color(0x99000000),
    onMedia: Color(0xFFFFFFFF),
    onMediaMuted: Color(0xB3FFFFFF),
    onMediaLabelShadows: _onMediaLabelShadows,
    immersiveBottomBarHeight: _immersiveBottomBarHeight,
    scrubProgressTrack: Color(0x66FFFFFF),
    scrubProgressPlayed: Color(0xFFFFFFFF),
    // Initial ~30% white — Cap 19.2d; retune after device smoke if needed.
    scrubProgressLiveGhost: Color(0x4DFFFFFF),
    // Opaque — semi-transparent fill lets video show through JPEG decode gaps.
    scrubPreviewPlaceholderFill: Color(0xFF000000),
    titleChrome: TextStyle(
      fontSize: _titleChromeSize,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: Color(0xFFF5F5F5),
    ),
    labelChrome: TextStyle(
      fontSize: _labelChromeSize,
      fontWeight: FontWeight.w500,
      height: 1.2,
      color: Color(0xFFF5F5F5),
    ),
    bodyChrome: TextStyle(
      fontSize: _bodyChromeSize,
      fontWeight: FontWeight.w400,
      height: 1.35,
      color: Color(0xFFF5F5F5),
    ),
    labelOnMedia: TextStyle(
      fontSize: _labelOnMediaSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: Color(0xFFFFFFFF),
    ),
    bodyOnMedia: TextStyle(
      fontSize: _bodyOnMediaSize,
      fontWeight: FontWeight.w400,
      height: 1.3,
      color: Color(0xB3FFFFFF),
    ),
  );

  @override
  WakeTokTokens copyWith({
    Color? background,
    Color? surface,
    Color? onSurface,
    Color? accent,
    Color? brandGold,
    Color? feedBackground,
    Color? mediaScrim,
    Color? onMedia,
    Color? onMediaMuted,
    List<Shadow>? onMediaLabelShadows,
    double? immersiveBottomBarHeight,
    Color? scrubProgressTrack,
    Color? scrubProgressPlayed,
    Color? scrubProgressLiveGhost,
    Color? scrubPreviewPlaceholderFill,
    TextStyle? titleChrome,
    TextStyle? labelChrome,
    TextStyle? bodyChrome,
    TextStyle? labelOnMedia,
    TextStyle? bodyOnMedia,
  }) {
    return WakeTokTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      accent: accent ?? this.accent,
      brandGold: brandGold ?? this.brandGold,
      feedBackground: feedBackground ?? this.feedBackground,
      mediaScrim: mediaScrim ?? this.mediaScrim,
      onMedia: onMedia ?? this.onMedia,
      onMediaMuted: onMediaMuted ?? this.onMediaMuted,
      onMediaLabelShadows: onMediaLabelShadows ?? this.onMediaLabelShadows,
      immersiveBottomBarHeight:
          immersiveBottomBarHeight ?? this.immersiveBottomBarHeight,
      scrubProgressTrack: scrubProgressTrack ?? this.scrubProgressTrack,
      scrubProgressPlayed: scrubProgressPlayed ?? this.scrubProgressPlayed,
      scrubProgressLiveGhost:
          scrubProgressLiveGhost ?? this.scrubProgressLiveGhost,
      scrubPreviewPlaceholderFill:
          scrubPreviewPlaceholderFill ?? this.scrubPreviewPlaceholderFill,
      titleChrome: titleChrome ?? this.titleChrome,
      labelChrome: labelChrome ?? this.labelChrome,
      bodyChrome: bodyChrome ?? this.bodyChrome,
      labelOnMedia: labelOnMedia ?? this.labelOnMedia,
      bodyOnMedia: bodyOnMedia ?? this.bodyOnMedia,
    );
  }

  @override
  WakeTokTokens lerp(ThemeExtension<WakeTokTokens>? other, double t) {
    if (other is! WakeTokTokens) {
      return this;
    }
    return WakeTokTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      brandGold: Color.lerp(brandGold, other.brandGold, t)!,
      feedBackground: Color.lerp(feedBackground, other.feedBackground, t)!,
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      onMediaMuted: Color.lerp(onMediaMuted, other.onMediaMuted, t)!,
      onMediaLabelShadows:
          t < 0.5 ? onMediaLabelShadows : other.onMediaLabelShadows,
      immersiveBottomBarHeight: lerpDouble(
            immersiveBottomBarHeight,
            other.immersiveBottomBarHeight,
            t,
          )!,
      scrubProgressTrack:
          Color.lerp(scrubProgressTrack, other.scrubProgressTrack, t)!,
      scrubProgressPlayed:
          Color.lerp(scrubProgressPlayed, other.scrubProgressPlayed, t)!,
      scrubProgressLiveGhost:
          Color.lerp(scrubProgressLiveGhost, other.scrubProgressLiveGhost, t)!,
      scrubPreviewPlaceholderFill: Color.lerp(
        scrubPreviewPlaceholderFill,
        other.scrubPreviewPlaceholderFill,
        t,
      )!,
      titleChrome: TextStyle.lerp(titleChrome, other.titleChrome, t)!,
      labelChrome: TextStyle.lerp(labelChrome, other.labelChrome, t)!,
      bodyChrome: TextStyle.lerp(bodyChrome, other.bodyChrome, t)!,
      labelOnMedia: TextStyle.lerp(labelOnMedia, other.labelOnMedia, t)!,
      bodyOnMedia: TextStyle.lerp(bodyOnMedia, other.bodyOnMedia, t)!,
    );
  }
}
