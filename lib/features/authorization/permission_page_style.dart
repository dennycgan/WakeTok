import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';

// Shared by the permission request and blocked pages (Cap 31.4, owner
// 2026-09-28): one flow, one look. Page-local by owner exception — not
// WakeTokTokens roles, and must not follow other pages.

const EdgeInsets kPermissionPagePadding = EdgeInsets.all(24);

const double kPermissionAppNameFontSize = 40;
const FontWeight kPermissionAppNameFontWeight = FontWeight.w600;
const double kPermissionHeadlineFontSize = 24;
const FontWeight kPermissionHeadlineFontWeight = FontWeight.w600;

/// EN is smaller so the longest request-page point fits one line on a
/// 390 pt wide iPhone (13 Pro) at default text size.
const double kPermissionBodyFontSizeEn = 15;
const double kPermissionBodyFontSizeZh = 17;
const FontWeight kPermissionBodyFontWeight = FontWeight.w400;
const double kPermissionBodyLineHeight = 1.5;

const double kPermissionAppNameToHeadlineGap = 12;
const double kPermissionHeadlineToBodyGap = 20;

/// Text group to CTA; the group and CTA sit together at the bottom.
const double kPermissionTextToButtonGap = 36;
const double kPermissionButtonHeight = 60;

/// Narrower than the Material default (24) so the EN request label fits one
/// line on a 375 pt wide iPhone (SE) at default text size. A wrapped label
/// keeps the vertical padding above and below as the button grows.
const double kPermissionButtonPaddingH = 16;
const double kPermissionButtonPaddingV = 12;

/// EN already fills most of the button width at this size; ZH is larger so
/// the short label does not leave the button looking empty.
const double kPermissionButtonFontSizeEn = 20;
const double kPermissionButtonFontSizeZh = 24;
const FontWeight kPermissionButtonFontWeight = FontWeight.w600;

/// Resolved text and button styles for the permission pages.
class PermissionPageStyle {
  const PermissionPageStyle._({
    required this.appName,
    required this.headline,
    required this.body,
    required this.button,
  });

  factory PermissionPageStyle.of(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.extension<WakeTokTokens>()!;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final base = theme.textTheme.bodyLarge!.copyWith(color: tokens.onSurface);
    // The CTA keeps the light-mode accent / onAccent pair in both
    // Appearances (owner choice).
    final buttonTokens =
        waketokTheme(Brightness.light).extension<WakeTokTokens>()!;
    return PermissionPageStyle._(
      appName: base.copyWith(
        fontSize: kPermissionAppNameFontSize,
        fontWeight: kPermissionAppNameFontWeight,
      ),
      headline: base.copyWith(
        fontSize: kPermissionHeadlineFontSize,
        fontWeight: kPermissionHeadlineFontWeight,
      ),
      body: base.copyWith(
        fontSize: isZh ? kPermissionBodyFontSizeZh : kPermissionBodyFontSizeEn,
        fontWeight: kPermissionBodyFontWeight,
        height: kPermissionBodyLineHeight,
      ),
      button: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(kPermissionButtonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: kPermissionButtonPaddingH,
          vertical: kPermissionButtonPaddingV,
        ),
        backgroundColor: buttonTokens.accent,
        foregroundColor: buttonTokens.onAccent,
        textStyle: theme.textTheme.labelLarge!.copyWith(
          fontSize:
              isZh ? kPermissionButtonFontSizeZh : kPermissionButtonFontSizeEn,
          fontWeight: kPermissionButtonFontWeight,
        ),
      ),
    );
  }

  final TextStyle appName;
  final TextStyle headline;
  final TextStyle body;
  final ButtonStyle button;

  /// [appName] at the current text size, scaled down when [name] is wider
  /// than the page so the one-word name never splits mid-word. Text size is
  /// already applied: use it with [TextScaler.noScaling] and
  /// `softWrap: false`. [context] must sit outside the page's [SafeArea].
  TextStyle appNameFitted(BuildContext context, String name) {
    var style = DefaultTextStyle.of(context).style.merge(appName);
    if (MediaQuery.boldTextOf(context)) {
      style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    style = style.copyWith(
      fontSize: MediaQuery.textScalerOf(context).scale(style.fontSize!),
    );
    final pageWidth = MediaQuery.sizeOf(context).width -
        MediaQuery.paddingOf(context).horizontal -
        kPermissionPagePadding.horizontal;
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: Directionality.of(context),
      locale: Localizations.localeOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.maxIntrinsicWidth;
    painter.dispose();
    if (width <= pageWidth) return style;
    final fit = pageWidth / width;
    final letterSpacing = style.letterSpacing;
    return style.copyWith(
      fontSize: style.fontSize! * fit,
      letterSpacing: letterSpacing == null ? null : letterSpacing * fit,
    );
  }
}
