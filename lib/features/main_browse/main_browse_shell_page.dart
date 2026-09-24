import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_access_settings_section.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/features/main_browse/bottom_tab_layout.dart';
import 'package:waketok/features/main_browse/browse_card_stack_icon.dart';
import 'package:waketok/features/main_browse/browse_top_chrome.dart';
import 'package:waketok/features/main_browse/cap19_entry_icon.dart';
import 'package:waketok/features/main_browse/cap24_more_entry_icon.dart';
import 'package:waketok/features/main_browse/cap25_share_entry_icon.dart';
import 'package:waketok/features/main_browse/browse_display_settings_section.dart';
import 'package:waketok/features/main_browse/browse_notifications_settings_section.dart';
import 'package:waketok/features/main_browse/cap19_gestures_settings_section.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/cap30_create_pool_tip.dart';
import 'package:waketok/features/main_browse/cap30_vertical_hint_guide.dart';
import 'package:waketok/features/main_browse/cap27_l1_stall_probe_settings.dart';
import 'package:waketok/features/main_browse/cap28_live_probe_settings.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/order_control_half_sheet.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 7.4 Main Browse chrome shell + Cap 7.5 vertical Media Feed (ADR-014).
/// Cap 8.2: immersive forced-dark for Browse content. Cap 8.2 revision
/// (ADR-016): transparent floating top chrome + compact bar.
/// Cap 27.4 / ADR-055: bottom bar is Browse | Order action | Settings.
/// Bottom bar is always dark (even on Settings) so on-media label colors stay
/// legible — Settings *pane* still follows Appearance.
class MainBrowseShellPage extends ConsumerWidget {
  const MainBrowseShellPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cap 27 / ADR-056 D9: post-auth All prefetch (fire-and-forget).
    // watch keeps the binder alive for the shell lifetime (void provider;
    // does not notify / rebuild).
    ref.watch(browseAllPrefetchBinderProvider);

    final destination = ref.watch(mainBrowseDestinationProvider);
    final immersiveContent = destination != MainBrowseDestination.settings;
    final ambientTheme = Theme.of(context);

    // Always wrap IndexedStack in immersive dark Theme. Do not restore a
    // destination-conditional wrap: dropping Theme changes this slot from
    // Theme to IndexedStack, Widget.canUpdate is false, and the whole stack
    // (VerticalMediaFeed + PageController) is disposed while Riverpod
    // feedIndex survives → visible page 0 vs current index N.
    Widget body = Theme(
      data: waketokTheme(Brightness.dark),
      child: IndexedStack(
        index: destination.index,
        sizing: StackFit.expand,
        children: [
          const _BrowsePane(),
          Theme(
            data: ambientTheme,
            child: _SettingsStubPane(access: access),
          ),
        ],
      ),
    );

    // Bottom bar always dark — never inherit Light Appearance (unselected
    // onMediaMuted icons vanish on light surface otherwise).
    final bottomBar = Theme(
      data: waketokTheme(Brightness.dark),
      child: _MainBrowseBottomBar(
        selected: destination,
        onSelect: (next) =>
            ref.read(mainBrowseDestinationProvider.notifier).select(next),
      ),
    );

    final scaffoldTokens = immersiveContent
        ? waketokTheme(Brightness.dark).extension<WakeTokTokens>()!
        : Theme.of(context).extension<WakeTokTokens>()!;

    return Scaffold(
      backgroundColor: scaffoldTokens.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                body,
                if (destination == MainBrowseDestination.browse) ...[
                  const Cap24MoreEntryIconSlot(),
                  const Cap25ShareEntryIconSlot(),
                  Cap19EntryIconSlot(access: access),
                ],
              ],
            ),
          ),
          bottomBar,
        ],
      ),
    );
  }
}

class _BrowsePane extends ConsumerWidget {
  const _BrowsePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stack overlay: feed full-bleed; top chrome floats with transparent
    // Material + on-media text shadows (ADR-016; Column sibling cannot).
    return Stack(
      key: const Key('mainBrowseBrowsePane'),
      fit: StackFit.expand,
      children: [
        const VerticalMediaFeed(),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: BrowseTopChrome(),
        ),
        // Cap 30.4: Vertical Host must stay unconditional (sole sync owner —
        // see Cap30VerticalHintGuideHost class comment). Tip Host observes
        // chrome only; do not gate either mount on activeChrome.
        const Cap30VerticalHintGuideHost(),
        const Cap30CreatePoolTipHost(),
        const Cap19LeftSwipeGuideHost(),
      ],
    );
  }
}

class _MainBrowseBottomBar extends ConsumerWidget {
  const _MainBrowseBottomBar({
    required this.selected,
    required this.onSelect,
  });

  final MainBrowseDestination selected;
  final ValueChanged<MainBrowseDestination> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final contentBottomPad =
        bottomInset == 0 ? kBottomTabContentBottomPadWhenNoSafeArea : 0.0;
    final labelStyle = tokens.labelOnMedia.copyWith(height: 1.0);
    final preference = ref.watch(browseOrderPreferenceProvider);
    final effective = effectiveBrowseOrderPolicy(preference);
    final orderLabel = orderPolicySlotLabel(l10n, effective);

    // Do not use Material 3 [NavigationBar]: its SafeArea lives *inside*
    // Material, so height+Home Indicator paints a tall grey block even when
    // MediaQuery.removePadding is applied (and Profile rebuilds can still
    // look unchanged). Custom row = one icon+label strip; same surface
    // extends under the Home Indicator only.
    // Order label is permanently one line (Layer 1). Do not reserve a
    // second line for Layer 2/3 — see ADR-055 D2 / layout notes §11.4.7.
    return Material(
      key: const Key('mainBrowseNavigationBar'),
      color: tokens.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: const Key('mainBrowseNavigationBarContent'),
            height: tokens.immersiveBottomBarHeight,
            child: Row(
              children: [
                Expanded(
                  child: _BottomNavCell(
                    slotKey: const Key('mainBrowseNavBrowseSlot'),
                    selected: selected == MainBrowseDestination.browse,
                    label: l10n.mainBrowseNavBrowse,
                    labelStyle: labelStyle,
                    accent: tokens.accent,
                    onMediaMuted: tokens.onMediaMuted,
                    onTap: () => onSelect(MainBrowseDestination.browse),
                    iconBuilder: (color, filled) => BrowseCardStackIcon(
                      key: const Key('mainBrowseNavBrowseGlyph'),
                      color: color,
                      filled: filled,
                    ),
                  ),
                ),
                Expanded(
                  child: _OrderActionCell(
                    label: orderLabel,
                    labelStyle: labelStyle,
                    onMediaMuted: tokens.onMediaMuted,
                    semanticsLabel: l10n.mainBrowseOrderSlotSemantics,
                    onTap: () => showOrderControlHalfSheet(context),
                  ),
                ),
                Expanded(
                  child: _BottomNavCell(
                    slotKey: const Key('mainBrowseNavSettingsSlot'),
                    selected: selected == MainBrowseDestination.settings,
                    label: l10n.mainBrowseNavSettings,
                    labelStyle: labelStyle,
                    accent: tokens.accent,
                    onMediaMuted: tokens.onMediaMuted,
                    onTap: () => onSelect(MainBrowseDestination.settings),
                    iconBuilder: (color, filled) => Icon(
                      filled ? Icons.settings : Icons.settings_outlined,
                      size: kBottomTabIconSize,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Zero-safe-area only (SE / home button). Notched phones keep 0 —
          // do not raise [immersiveBottomBarHeight] for flush-bottom.
          if (contentBottomPad > 0)
            SizedBox(
              key: const Key('mainBrowseNavigationBarContentBottomPad'),
              height: contentBottomPad,
            ),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }
}

class _BottomNavCell extends StatelessWidget {
  const _BottomNavCell({
    required this.slotKey,
    required this.selected,
    required this.label,
    required this.labelStyle,
    required this.accent,
    required this.onMediaMuted,
    required this.onTap,
    required this.iconBuilder,
  });

  final Key slotKey;
  final bool selected;
  final String label;
  final TextStyle labelStyle;
  final Color accent;
  final Color onMediaMuted;
  final VoidCallback onTap;
  final Widget Function(Color color, bool filled) iconBuilder;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? accent : onMediaMuted;
    final textColor = selected ? accent : onMediaMuted;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // §11.4.3: color-only selected — no fill / circle / pill behind icon.
          SizedBox(
            key: slotKey,
            width: kBottomTabIconSlot,
            height: kBottomTabIconSlot,
            child: Center(
              child: iconBuilder(iconColor, selected),
            ),
          ),
          const SizedBox(height: kBottomTabIconLabelGap),
          SizedBox(
            height: kBottomTabLabelBandHeight,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: labelStyle.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cap 27.4 / §11.4.4 Action slot — no shell; thinner swap; never selected.
class _OrderActionCell extends StatelessWidget {
  const _OrderActionCell({
    required this.label,
    required this.labelStyle,
    required this.onMediaMuted,
    required this.semanticsLabel,
    required this.onTap,
  });

  final String label;
  final TextStyle labelStyle;
  final Color onMediaMuted;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('mainBrowseOrderActionSlot'),
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              key: const Key('mainBrowseOrderActionIconSlot'),
              width: kBottomTabIconSlot,
              height: kBottomTabIconSlot,
              child: Center(
                child: OrderSwapIcon(color: onMediaMuted),
              ),
            ),
            const SizedBox(height: kBottomTabIconLabelGap),
            // Height fixed at 12. FittedBox scales the *label text width only*
            // (SE long copy); chevron stays true [kBottomTabExpandIconSize].
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: SizedBox(
                height: kBottomTabLabelBandHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          style: labelStyle.copyWith(color: onMediaMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: kBottomTabExpandGap),
                    Icon(
                      Icons.expand_less,
                      size: kBottomTabExpandIconSize,
                      color: onMediaMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsStubPane extends StatelessWidget {
  const _SettingsStubPane({required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.mainBrowseNavSettings, style: tokens.titleChrome),
          const SizedBox(height: 20),
          // Cap 29.2 / ADR-059: Photos Access first (kickoff §2.8). Add only
          // ListView children — do not unwrap SafeArea (29.1 / 29.2 exit).
          const PhotosAccessSettingsSection(),
          const SizedBox(height: 28),
          const Cap19GesturesSettingsSection(),
          const SizedBox(height: 28),
          const BrowseDisplaySettingsSection(),
          const SizedBox(height: 28),
          const BrowseNotificationsSettingsSection(),
          // After Photos Access (Cap 29): debug smoke may sit below the
          // fold — tests use dragUntilVisible. Release omits the control.
          if (kDebugMode) ...[
            const SizedBox(height: 28),
            FilledButton(
              key: const Key('mainBrowseOpenLibrarySmokeDebug'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LibraryTotalsShellPage(access: access),
                  ),
                );
              },
              child: Text(l10n.mainBrowseOpenLibrarySmokeDebug),
            ),
          ],
          // After library-smoke debug (tests find that key without scrolling).
          if (!kReleaseMode) ...[
            const SizedBox(height: 28),
            const Cap27L1StallProbeSettingsSection(),
            const SizedBox(height: 28),
            const Cap28LiveProbeSettingsSection(),
          ],
        ],
      ),
    );
  }
}
