import 'package:flutter/material.dart';

part 'waketok_tokens.dart';

/// Builds WakeTok [ThemeData] for the given [brightness] from semantic
/// tokens (ADR-009 Decision 5; Cap 7.2 typography + media scrim).
///
/// Preset token values (`_light` / `_dark`) are library-private so feature
/// code must resolve colors / type roles via [Theme.of] → [WakeTokTokens],
/// not by importing static presets.
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

  final textTheme = TextTheme(
    titleMedium: tokens.titleChrome,
    labelLarge: tokens.labelChrome,
    bodyMedium: tokens.bodyChrome,
    labelSmall: tokens.labelOnMedia,
    bodySmall: tokens.bodyOnMedia,
  );

  return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.background,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface,
      foregroundColor: tokens.onSurface,
      titleTextStyle: tokens.titleChrome,
    ),
    extensions: <ThemeExtension<dynamic>>[tokens],
  );
}
