import 'package:flutter/material.dart';

import 'package:waketok/core/theme/status_bar_style.dart';

/// [MaterialApp.builder] for the app: [appTextBaselineBuilder] around
/// [statusBarBaselineBuilder].
Widget appRootBuilder(BuildContext context, Widget? child) {
  return appTextBaselineBuilder(
    context,
    statusBarBaselineBuilder(context, child),
  );
}

/// Text below [MaterialApp.builder] (every route, dialog, sheet and overlay)
/// draws at the iOS default text size with Bold Text off, whatever the
/// system Text Size and Bold Text settings are. Layout sizes in
/// `WakeTokTokens` assume this baseline: do not restore the system text
/// scale or Bold Text below it.
Widget appTextBaselineBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.noScaling, boldText: false),
    child: child ?? const SizedBox.shrink(),
  );
}
