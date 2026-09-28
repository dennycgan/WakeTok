import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons that stay legible over a surface of [surfaceBrightness].
SystemUiOverlayStyle statusBarStyleFor(Brightness surfaceBrightness) {
  return surfaceBrightness == Brightness.dark
      ? SystemUiOverlayStyle.light
      : SystemUiOverlayStyle.dark;
}

/// [MaterialApp.builder] baseline: every route follows the app theme's
/// brightness unless a deeper [AnnotatedRegion] (Browse shell, AppBar)
/// overrides it. MaterialApp re-sends its theme default only when the theme
/// changes, so without a baseline a surface with no region reached by
/// navigation keeps the previous surface's style.
Widget statusBarBaselineBuilder(BuildContext context, Widget? child) {
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: statusBarStyleFor(Theme.of(context).brightness),
    child: child ?? const SizedBox.shrink(),
  );
}
