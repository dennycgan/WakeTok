import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/features/main_browse/browse_top_chrome.dart';
import 'package:waketok/features/main_browse/cap19_entry_icon.dart';
import 'package:waketok/features/main_browse/cap24_more_entry_icon.dart';
import 'package:waketok/features/main_browse/cap25_share_entry_icon.dart';
import 'package:waketok/features/main_browse/browse_notifications_settings_section.dart';
import 'package:waketok/features/main_browse/cap19_gestures_settings_section.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 7.4 Main Browse chrome shell + Cap 7.5 vertical Media Feed (ADR-014).
/// Cap 8.2: immersive forced-dark for Browse/Clips/Auto content. Cap 8.2
/// revision (ADR-016): transparent floating top chrome + compact bar.
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
    final l10n = AppLocalizations.of(context)!;
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
          _StubPane(
            title: l10n.mainBrowseNavClips,
            body: l10n.mainBrowseStubClipsBody,
          ),
          _StubPane(
            title: l10n.mainBrowseNavAuto,
            body: l10n.mainBrowseStubAutoBody,
          ),
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
        const Cap19LeftSwipeGuideHost(),
      ],
    );
  }
}

class _MainBrowseBottomBar extends StatelessWidget {
  const _MainBrowseBottomBar({
    required this.selected,
    required this.onSelect,
  });

  final MainBrowseDestination selected;
  final ValueChanged<MainBrowseDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // Match top source chrome label size/weight (labelOnMedia 12 / w600);
    // keep compact height for the icon+label strip.
    final labelStyle = tokens.labelOnMedia.copyWith(height: 1.0);


    // Do not use Material 3 [NavigationBar]: its SafeArea lives *inside*
    // Material, so height+Home Indicator paints a tall grey block even when
    // MediaQuery.removePadding is applied (and Profile rebuilds can still
    // look unchanged). Custom row = one icon+label strip; same surface
    // extends under the Home Indicator only.
    final destinations = <(MainBrowseDestination, IconData, IconData, String)>[
      (
        MainBrowseDestination.browse,
        Icons.home_outlined,
        Icons.home,
        l10n.mainBrowseNavBrowse,
      ),
      (
        MainBrowseDestination.clips,
        Icons.movie_outlined,
        Icons.movie,
        l10n.mainBrowseNavClips,
      ),
      (
        MainBrowseDestination.auto,
        Icons.play_circle_outline,
        Icons.play_circle,
        l10n.mainBrowseNavAuto,
      ),
      (
        MainBrowseDestination.settings,
        Icons.settings_outlined,
        Icons.settings,
        l10n.mainBrowseNavSettings,
      ),
    ];

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
                for (final entry in destinations)
                  Expanded(
                    child: _BottomNavCell(
                      selected: selected == entry.$1,
                      outlinedIcon: entry.$2,
                      filledIcon: entry.$3,
                      label: entry.$4,
                      labelStyle: labelStyle,
                      accent: tokens.accent,
                      onMediaMuted: tokens.onMediaMuted,
                      onTap: () => onSelect(entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: bottomInset),
        ],
      ),
    );
  }
}

class _BottomNavCell extends StatelessWidget {
  const _BottomNavCell({
    required this.selected,
    required this.outlinedIcon,
    required this.filledIcon,
    required this.label,
    required this.labelStyle,
    required this.accent,
    required this.onMediaMuted,
    required this.onTap,
  });

  final bool selected;
  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;
  final TextStyle labelStyle;
  final Color accent;
  final Color onMediaMuted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = selected ? accent : onMediaMuted;
    final textColor = selected ? accent : onMediaMuted;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? accent.withValues(alpha: 0.20) : null,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Icon(
                selected ? filledIcon : outlinedIcon,
                size: 22,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _StubPane extends StatelessWidget {
  const _StubPane({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: tokens.titleChrome,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: tokens.bodyChrome.copyWith(color: tokens.onSurface),
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
          const Cap19GesturesSettingsSection(),
          const SizedBox(height: 28),
          const BrowseNotificationsSettingsSection(),
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
        ],
      ),
    );
  }
}

