import 'package:flutter/material.dart';

/// App Foundation 4.4 / kickoff ADR-U §10 device-language resolution.
///
/// Inspects only the **first** preferred locale. Does not scan later entries
/// for a Chinese match. Manual language preference is out of scope (Settings).
Locale resolveAppLocale(List<Locale>? preferredLocales) {
  if (preferredLocales == null || preferredLocales.isEmpty) {
    return const Locale('en');
  }
  final first = preferredLocales.first;
  if (first.languageCode == 'zh') {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
  }
  return const Locale('en');
}
