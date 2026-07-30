part of 'waketok_theme.dart';

/// WakeTok semantic color tokens (ADR-009 Decision 5; 5.1 minimal set).
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
  });

  /// Non-feed scaffold backdrop.
  final Color background;

  /// Cards, app bars, banners.
  final Color surface;

  /// Primary text and icons on [surface] / [background].
  final Color onSurface;

  /// Provisional accent — final accent freezes with the app icon
  /// (Known debt, before Main Browse Screen closes).
  final Color accentProvisional;

  /// Vertical media feed backdrop (same black in both modes).
  final Color feedBackground;

  static const WakeTokTokens _light = WakeTokTokens(
    background: Color(0xFFF4F4F5),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1A1A),
    accentProvisional: Color(0xFF2F6FED),
    feedBackground: Color(0xFF000000),
  );

  static const WakeTokTokens _dark = WakeTokTokens(
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFF5F5F5),
    accentProvisional: Color(0xFF5B8DEF),
    feedBackground: Color(0xFF000000),
  );

  @override
  WakeTokTokens copyWith({
    Color? background,
    Color? surface,
    Color? onSurface,
    Color? accentProvisional,
    Color? feedBackground,
  }) {
    return WakeTokTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      accentProvisional: accentProvisional ?? this.accentProvisional,
      feedBackground: feedBackground ?? this.feedBackground,
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
    );
  }
}
