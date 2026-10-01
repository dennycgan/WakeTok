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
    required this.onAccent,
    required this.destructive,
    required this.brandGold,
    required this.feedBackground,
    required this.mediaSheetSurface,
    required this.mediaScrim,
    required this.onMediaPillFill,
    required this.onMedia,
    required this.onMediaMuted,
    required this.onMediaLabelShadows,
    required this.immersiveBottomBarHeight,
    required this.scrubProgressTrack,
    required this.scrubProgressPlayed,
    required this.scrubProgressLiveGhost,
    required this.scrubPreviewPlaceholderFill,
    required this.titlePage,
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

  /// Text / icons on an [accent] fill; also `ColorScheme.onPrimary`. An
  /// [accent] fill always takes this, never [onMedia] or another text
  /// token (ADR-069; guard `accent_fill_pairing_test.dart`).
  final Color onAccent;

  /// Irreversible / destructive actions (e.g. Cap 24 soft-delete control).
  /// iOS systemRed `#FF3B30`. Distinct from [accent] (brand CTA / Cap 22
  /// delete-label text `#FC2555` Light) — two independent color decisions;
  /// unifying them is a future design-system discussion, not a Cap 24 bug.
  final Color destructive;

  /// Brand gold for loading indicators (not CTAs). Light/Dark same. Cap 7.8.
  final Color brandGold;

  /// Vertical media feed backdrop (same black in both modes).
  final Color feedBackground;

  /// Large frosted panel fill over the media feed (Cap 19 / Cap 24
  /// bottom half-sheets). Distinct from [surface] (cards / app bars /
  /// banners) and from [feedBackground] (letterbox black) so sheet edges
  /// stay visible on non-full-bleed media. L=D `#1E1E1E` (same hex as Dark
  /// [surface] at intro — independent semantic path). Cap 19/24 sheets
  /// always wrap `Brightness.dark`; the Light preset is unused by that
  /// chrome but required for ThemeExtension completeness.
  final Color mediaSheetSurface;

  /// Semi-transparent scrim over media for chrome/controls (L/D same).
  /// Not used for Browse top source chrome after ADR-016 (transparent +
  /// [onMediaLabelShadows]); retained for other on-media surfaces.
  final Color mediaScrim;

  /// Solid mid-gray fill for on-media pills (Reset). Video-App-B class —
  /// readable on black feed (unlike black [mediaScrim]). L/D same.
  final Color onMediaPillFill;

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

  /// Cap 18.5 video scrubber played fill (idle) and Cap 19.8 live-playhead
  /// ghost while dragging (solid; same color for drag continuity).
  final Color scrubProgressPlayed;

  /// Cap 19.8 finger-target fill while scrub-dragging (above solid live ghost).
  /// Translucent brand-gold so the white live ghost can read through on
  /// forward scrubs; ~65% opacity (`0xA6`) — retune on device if needed.
  final Color scrubProgressLiveGhost;

  /// Cap 18.5 scrub preview bubble non-photographic placeholder.
  final Color scrubPreviewPlaceholderFill;

  /// Page-level heading. Every standalone screen heading must use this
  /// (Settings today; future screens such as Clips). Not bound to any
  /// Material [TextTheme] slot, so retuning it never moves sheets, guides, or
  /// buttons.
  final TextStyle titlePage;

  /// Top bar / AppBar title role. Also [TextTheme.titleMedium], so sheet
  /// titles, guide titles, and some sheet button labels follow it.
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
  static const double _titlePageSize = 24;
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
    onAccent: Color(0xFFFFFFFF),
    destructive: Color(0xFFFF3B30),
    brandGold: Color(0xFFE0C590),
    feedBackground: Color(0xFF000000),
    mediaSheetSurface: Color(0xFF1E1E1E),
    mediaScrim: Color(0x99000000),
    // Video-App-B Reset-class mid gray (~80%): visible on black feed.
    onMediaPillFill: Color(0xCC6E6E6E),
    onMedia: Color(0xFFFFFFFF),
    onMediaMuted: Color(0xB3FFFFFF),
    onMediaLabelShadows: _onMediaLabelShadows,
    immersiveBottomBarHeight: _immersiveBottomBarHeight,
    scrubProgressTrack: Color(0x66FFFFFF),
    scrubProgressPlayed: Color(0xFFFFFFFF),
    // Cap 19.8: ~65% brandGold drag-target (solid live ghost uses played).
    scrubProgressLiveGhost: Color(0xA6E0C590),
    // Opaque — semi-transparent fill lets video show through JPEG decode gaps.
    scrubPreviewPlaceholderFill: Color(0xFF000000),
    titlePage: TextStyle(
      fontSize: _titlePageSize,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: Color(0xFF1A1A1A),
    ),
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
    onAccent: Color(0xFF000000),
    destructive: Color(0xFFFF3B30),
    brandGold: Color(0xFFE0C590),
    feedBackground: Color(0xFF000000),
    mediaSheetSurface: Color(0xFF1E1E1E),
    mediaScrim: Color(0x99000000),
    // Video-App-B Reset-class mid gray (~80%): visible on black feed.
    onMediaPillFill: Color(0xCC6E6E6E),
    onMedia: Color(0xFFFFFFFF),
    onMediaMuted: Color(0xB3FFFFFF),
    onMediaLabelShadows: _onMediaLabelShadows,
    immersiveBottomBarHeight: _immersiveBottomBarHeight,
    scrubProgressTrack: Color(0x66FFFFFF),
    scrubProgressPlayed: Color(0xFFFFFFFF),
    // Cap 19.8: ~65% brandGold drag-target (solid live ghost uses played).
    scrubProgressLiveGhost: Color(0xA6E0C590),
    // Opaque — semi-transparent fill lets video show through JPEG decode gaps.
    scrubPreviewPlaceholderFill: Color(0xFF000000),
    titlePage: TextStyle(
      fontSize: _titlePageSize,
      fontWeight: FontWeight.w700,
      height: 1.25,
      color: Color(0xFFF5F5F5),
    ),
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
    Color? onAccent,
    Color? destructive,
    Color? brandGold,
    Color? feedBackground,
    Color? mediaSheetSurface,
    Color? mediaScrim,
    Color? onMediaPillFill,
    Color? onMedia,
    Color? onMediaMuted,
    List<Shadow>? onMediaLabelShadows,
    double? immersiveBottomBarHeight,
    Color? scrubProgressTrack,
    Color? scrubProgressPlayed,
    Color? scrubProgressLiveGhost,
    Color? scrubPreviewPlaceholderFill,
    TextStyle? titlePage,
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
      onAccent: onAccent ?? this.onAccent,
      destructive: destructive ?? this.destructive,
      brandGold: brandGold ?? this.brandGold,
      feedBackground: feedBackground ?? this.feedBackground,
      mediaSheetSurface: mediaSheetSurface ?? this.mediaSheetSurface,
      mediaScrim: mediaScrim ?? this.mediaScrim,
      onMediaPillFill: onMediaPillFill ?? this.onMediaPillFill,
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
      titlePage: titlePage ?? this.titlePage,
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
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      brandGold: Color.lerp(brandGold, other.brandGold, t)!,
      feedBackground: Color.lerp(feedBackground, other.feedBackground, t)!,
      mediaSheetSurface:
          Color.lerp(mediaSheetSurface, other.mediaSheetSurface, t)!,
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
      onMediaPillFill: Color.lerp(onMediaPillFill, other.onMediaPillFill, t)!,
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
      titlePage: TextStyle.lerp(titlePage, other.titlePage, t)!,
      titleChrome: TextStyle.lerp(titleChrome, other.titleChrome, t)!,
      labelChrome: TextStyle.lerp(labelChrome, other.labelChrome, t)!,
      bodyChrome: TextStyle.lerp(bodyChrome, other.bodyChrome, t)!,
      labelOnMedia: TextStyle.lerp(labelOnMedia, other.labelOnMedia, t)!,
      bodyOnMedia: TextStyle.lerp(bodyOnMedia, other.bodyOnMedia, t)!,
    );
  }
}
