part of 'waketok_theme.dart';

/// WakeTok semantic tokens (ADR-009 Decision 5; Cap 7.2 typography + scrim).
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
    required this.accentProvisional,
    required this.feedBackground,
    required this.mediaScrim,
    required this.onMedia,
    required this.onMediaMuted,
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

  /// Provisional accent — frozen in Cap 7.8 (Known debt until then).
  final Color accentProvisional;

  /// Vertical media feed backdrop (same black in both modes).
  final Color feedBackground;

  /// Semi-transparent scrim over media for chrome/controls (L/D same).
  final Color mediaScrim;

  /// High-contrast foreground on media (L/D same).
  final Color onMedia;

  /// Secondary foreground on media (L/D same).
  final Color onMediaMuted;

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

  static const WakeTokTokens _light = WakeTokTokens(
    background: Color(0xFFF4F4F5),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1A1A),
    accentProvisional: Color(0xFF2F6FED),
    feedBackground: Color(0xFF000000),
    mediaScrim: Color(0x99000000),
    onMedia: Color(0xFFFFFFFF),
    onMediaMuted: Color(0xB3FFFFFF),
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
    accentProvisional: Color(0xFF5B8DEF),
    feedBackground: Color(0xFF000000),
    mediaScrim: Color(0x99000000),
    onMedia: Color(0xFFFFFFFF),
    onMediaMuted: Color(0xB3FFFFFF),
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
    Color? accentProvisional,
    Color? feedBackground,
    Color? mediaScrim,
    Color? onMedia,
    Color? onMediaMuted,
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
      accentProvisional: accentProvisional ?? this.accentProvisional,
      feedBackground: feedBackground ?? this.feedBackground,
      mediaScrim: mediaScrim ?? this.mediaScrim,
      onMedia: onMedia ?? this.onMedia,
      onMediaMuted: onMediaMuted ?? this.onMediaMuted,
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
      accentProvisional:
          Color.lerp(accentProvisional, other.accentProvisional, t)!,
      feedBackground: Color.lerp(feedBackground, other.feedBackground, t)!,
      mediaScrim: Color.lerp(mediaScrim, other.mediaScrim, t)!,
      onMedia: Color.lerp(onMedia, other.onMedia, t)!,
      onMediaMuted: Color.lerp(onMediaMuted, other.onMediaMuted, t)!,
      titleChrome: TextStyle.lerp(titleChrome, other.titleChrome, t)!,
      labelChrome: TextStyle.lerp(labelChrome, other.labelChrome, t)!,
      bodyChrome: TextStyle.lerp(bodyChrome, other.bodyChrome, t)!,
      labelOnMedia: TextStyle.lerp(labelOnMedia, other.labelOnMedia, t)!,
      bodyOnMedia: TextStyle.lerp(bodyOnMedia, other.bodyOnMedia, t)!,
    );
  }
}
