import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/anchored_info_bubble.dart';

/// Vertical gap between Settings sections in the pane ListView.
const double kSettingsSectionGap = 28;

/// Gap under a section title before the first row.
const double kSettingsSectionTitleToRowGap = 12;

/// Layout gap between stacked toggle rows in one section.
///
/// Row layout height includes [CupertinoSwitch] (~31). Do **not** OverflowBox
/// the switch below that height — titles look tight but switches overlap.
/// See `docs/reference/settings-layout-notes.md` §2.
const double kSettingsRowGap = 8;

/// Gap between row title and optional short subtitle (rare; Cap 31.1
/// explanatory copy lives in the info bubble instead).
const double kSettingsTitleSubtitleGap = 2;

/// Horizontal gap between text column and trailing switch.
const double kSettingsRowTrailingGap = 12;

/// Layout width for non-inline `i` slots (half-sheet style). Settings rows
/// inline via [WidgetSpan] and size the span child to
/// [kSettingsInfoIconSize] instead — do not use this to trail a Flexible Text.
const double kSettingsInfoLayoutWidth = 22;

/// Minimum tap target for Settings info `i`.
const double kSettingsInfoHit = 44;

/// Icon glyph size for Settings info `i`.
const double kSettingsInfoIconSize = 18;

/// Gap between the **last title glyph** and the info `i` glyph.
///
/// Must be identical on every row — achieved by inlining the `i` with
/// [WidgetSpan] (not `Flexible(Text)` + trailing icon, which expands Text
/// to the column edge and makes the gap look like a second vertical lane).
const double kSettingsTitleInfoGap = 2;

/// Shared chrome size for section + row titles (Cap 31.1 revision: size is
/// not a hierarchy axis — weight only).
const double kSettingsChromeTitleFontSize = 14;

/// Status / helper body under Photos Access (and similar): muted, never bold.
const double kSettingsStatusBodyOpacity = 0.55;

/// Section header — same size as row title; **not** bold (weight-only ladder).
/// Do **not** use [WakeTokTokens.accent] (reserved for selected / coach focus).
TextStyle settingsSectionTitleStyle(WakeTokTokens tokens) =>
    tokens.bodyChrome.copyWith(
      color: tokens.onSurface,
      fontSize: kSettingsChromeTitleFontSize,
      fontWeight: FontWeight.w400,
      height: 1.25,
    );

/// Row title — same size as section; **bold**.
TextStyle settingsRowTitleStyle(WakeTokTokens tokens) =>
    tokens.bodyChrome.copyWith(
      color: tokens.onSurface,
      fontSize: kSettingsChromeTitleFontSize,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );

/// Optional short list subtitle (muted). Prefer info bubble for explanation.
TextStyle settingsRowSubtitleStyle(WakeTokTokens tokens) =>
    tokens.bodyChrome.copyWith(
      color: tokens.onSurface.withValues(alpha: 0.65),
      fontSize: kSettingsChromeTitleFontSize - 1,
      height: 1.35,
      fontWeight: FontWeight.w400,
    );

/// Photos Access (etc.) live status line — muted, not a title.
TextStyle settingsStatusBodyStyle(WakeTokTokens tokens) =>
    tokens.bodyChrome.copyWith(
      color: tokens.onSurface.withValues(alpha: kSettingsStatusBodyOpacity),
      fontSize: kSettingsChromeTitleFontSize,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );

/// Info bubble body on Settings (chrome role — not on-media labelSmall).
TextStyle settingsInfoBubbleTextStyle(WakeTokTokens tokens) =>
    tokens.bodyChrome.copyWith(
      color: tokens.onSurface,
      fontSize: kSettingsChromeTitleFontSize,
      height: 1.35,
      fontWeight: FontWeight.w400,
    );

/// Settings pane section title.
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Text(title, style: settingsSectionTitleStyle(tokens));
  }
}

/// Toggle row with optional anchored info bubble.
///
/// Cap 31.1: explanatory copy lives in the info bubble — list shows
/// **title + `i` + switch** only. [CupertinoSwitch] participates in row
/// height (~31); info hit overflows via [OverflowBox] so it does not
/// inflate the line box.
class SettingsToggleRow extends StatefulWidget {
  const SettingsToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.infoMessage,
    this.infoSemanticsLabel,
    this.infoButtonKey,
    this.infoBubbleKey,
    this.infoBarrierKey,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  /// Explanatory copy shown in the anchored info bubble.
  final String? infoMessage;
  final String? infoSemanticsLabel;
  final Key? infoButtonKey;
  final Key? infoBubbleKey;
  final Key? infoBarrierKey;

  @override
  State<SettingsToggleRow> createState() => _SettingsToggleRowState();
}

class _SettingsToggleRowState extends State<SettingsToggleRow> {
  final GlobalKey _infoAnchorKey = GlobalKey();
  AnchoredInfoBubbleHandle? _bubble;
  bool _suppressInfoReopen = false;

  @override
  void dispose() {
    _bubble?.dismiss(notify: false);
    _bubble = null;
    super.dispose();
  }

  void _dismissBubble() {
    _bubble?.dismiss();
    _bubble = null;
  }

  void _toggleInfoBubble() {
    if (_bubble?.isShowing == true) {
      _dismissBubble();
      setState(() {});
      return;
    }
    if (_suppressInfoReopen) {
      _suppressInfoReopen = false;
      return;
    }
    final message = widget.infoMessage;
    if (message == null || message.isEmpty) {
      return;
    }
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    _bubble = showAnchoredInfoBubble(
      context: context,
      anchorKey: _infoAnchorKey,
      message: message,
      textStyle: settingsInfoBubbleTextStyle(tokens),
      bubbleKey: widget.infoBubbleKey,
      barrierKey: widget.infoBarrierKey,
      onDismissed: () {
        _bubble = null;
        _suppressInfoReopen = true;
        if (mounted) {
          setState(() {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _suppressInfoReopen = false;
        });
      },
    );
    setState(() {});
  }

  Widget _infoControl(WakeTokTokens tokens) {
    // Layout width/height = glyph so WidgetSpan does not insert a 44-tall
    // line box (that was stacking with CupertinoSwitch height and blowing
    // optical row gaps far past [kSettingsRowGap]).
    return Semantics(
      button: true,
      label: widget.infoSemanticsLabel,
      child: KeyedSubtree(
        key: widget.infoButtonKey,
        child: SizedBox(
          width: kSettingsInfoIconSize,
          height: kSettingsInfoIconSize,
          child: OverflowBox(
            minWidth: kSettingsInfoHit,
            maxWidth: kSettingsInfoHit,
            minHeight: kSettingsInfoHit,
            maxHeight: kSettingsInfoHit,
            alignment: Alignment.center,
            child: IconButton(
              key: _infoAnchorKey,
              icon: Icon(
                Icons.info_outline,
                size: kSettingsInfoIconSize,
                color: tokens.onSurface.withValues(alpha: 0.55),
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(
                minWidth: kSettingsInfoHit,
                minHeight: kSettingsInfoHit,
              ),
              onPressed: widget.enabled ? _toggleInfoBubble : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = settingsRowTitleStyle(tokens);
    final subtitleStyle = settingsRowSubtitleStyle(tokens);
    final hasInfo = widget.infoMessage != null && widget.infoMessage!.isNotEmpty;
    final subtitle = widget.subtitle;

    // HARD RULE: info `i` is inlined after the title glyphs via WidgetSpan.
    // Do NOT use Flexible/Expanded(Text) + trailing Icon — Text expands to the
    // max width and shoves `i` to the far edge of the text column. See
    // docs/reference/settings-layout-notes.md §3.
    final titleLine = hasInfo
        ? Text.rich(
            TextSpan(
              style: titleStyle,
              children: [
                TextSpan(text: widget.title),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(left: kSettingsTitleInfoGap),
                    child: _infoControl(tokens),
                  ),
                ),
              ],
            ),
          )
        : Text(widget.title, style: titleStyle);

    // CupertinoSwitch (~31) must participate in row layout height. Shrinking
    // the row to title-line height and OverflowBox-ing the switch made Gestures
    // switches stack into a figure-8 (Cap 31.1 device fail).
    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleLine,
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: kSettingsTitleSubtitleGap),
                  Text(subtitle, style: subtitleStyle),
                ],
              ],
            ),
          ),
          const SizedBox(width: kSettingsRowTrailingGap),
          CupertinoSwitch(
            value: widget.value,
            onChanged: widget.enabled ? widget.onChanged : null,
          ),
        ],
      ),
    );
  }
}
