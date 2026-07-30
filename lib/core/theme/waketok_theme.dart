import 'package:flutter/material.dart';

part 'waketok_tokens.dart';

/// Builds WakeTok [ThemeData] for the given [brightness] from semantic
/// tokens (ADR-009 Decision 5). TextTheme stays Material 3 default in 5.1
/// (typography tokens are Known debt).
///
/// Preset token values (`_light` / `_dark`) are library-private so feature
/// code must resolve colors via [Theme.of] → [WakeTokTokens], not by
/// importing static presets.
ThemeData waketokTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? WakeTokTokens._dark
      : WakeTokTokens._light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: tokens.accentProvisional,
    brightness: brightness,
  ).copyWith(
    primary: tokens.accentProvisional,
    surface: tokens.surface,
    onSurface: tokens.onSurface,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.background,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface,
      foregroundColor: tokens.onSurface,
    ),
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
}
