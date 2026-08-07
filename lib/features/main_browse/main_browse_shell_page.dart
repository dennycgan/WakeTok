import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/authorization/limited_access_banner.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 7.4 Main Browse chrome shell + Cap 7.5 vertical Media Feed (ADR-014).
/// Cap 8.2: immersive forced-dark (Browse/Clips/Auto + bar). Cap 8.2
/// revision (ADR-016): transparent floating top chrome + compact bar height.
class MainBrowseShellPage extends ConsumerWidget {
  const MainBrowseShellPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(mainBrowseDestinationProvider);
    final immersive = destination != MainBrowseDestination.settings;

    // Theme override wraps Builder so Scaffold.backgroundColor (and all
    // descendants) resolve tokens after dark Theme is applied — not from
    // a precomputed ambient Color (Cap 8.2 Scaffold leak fix).
    Widget shell = Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final tokens = Theme.of(context).extension<WakeTokTokens>()!;

        return Scaffold(
          backgroundColor: tokens.background,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (access == PhotosAccess.limited) const LimitedAccessBanner(),
              Expanded(
                // IndexedStack keeps Browse (feed index / PageController) alive
                // when switching bottom destinations (Cap 7.5 Q4=A).
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
                    _SettingsStubPane(access: access),
                  ],
                ),
              ),
              _MainBrowseBottomBar(
                selected: destination,
                onSelect: (next) => ref
                    .read(mainBrowseDestinationProvider.notifier)
                    .select(next),
              ),
            ],
          ),
        );
      },
    );

    if (immersive) {
      shell = Theme(
        data: waketokTheme(Brightness.dark),
        child: shell,
      );
    }
    return shell;
  }
}

class _BrowsePane extends ConsumerWidget {
  const _BrowsePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mainBrowseSelectedSourceProvider);

    // Stack overlay: feed full-bleed; top chrome floats with transparent
    // Material + on-media text shadows (ADR-016; Column sibling cannot).
    return Stack(
      key: const Key('mainBrowseBrowsePane'),
      fit: StackFit.expand,
      children: [
        const VerticalMediaFeed(),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopSourceChrome(
            selected: selected,
            onSelect: (next) =>
                ref.read(mainBrowseSelectedSourceProvider.notifier).select(next),
          ),
        ),
      ],
    );
  }
}

/// Custom four-cell top chrome — avoids Material SegmentedButton defaults
/// (secondaryContainer). Selected uses [WakeTokTokens.accent]; unselected
/// uses on-media tokens; both use [WakeTokTokens.onMediaLabelShadows].
class _TopSourceChrome extends StatelessWidget {
  const _TopSourceChrome({
    required this.selected,
    required this.onSelect,
  });

  final SourceReference selected;
  final ValueChanged<SourceReference> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      key: const Key('mainBrowseTopSourceChrome'),
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: _SourceCell(
                  key: const Key('mainBrowseSourceAll'),
                  label: l10n.libraryRowAll,
                  selected: selected == SourceReference.all,
                  onTap: () => onSelect(SourceReference.all),
                ),
              ),
              Expanded(
                child: _SourceCell(
                  key: const Key('mainBrowseSourcePhotos'),
                  label: l10n.libraryRowPhotos,
                  selected: selected == SourceReference.photos,
                  onTap: () => onSelect(SourceReference.photos),
                ),
              ),
              Expanded(
                child: _SourceCell(
                  key: const Key('mainBrowseSourceVideos'),
                  label: l10n.libraryRowVideos,
                  selected: selected == SourceReference.videos,
                  onTap: () => onSelect(SourceReference.videos),
                ),
              ),
              Expanded(
                child: _PoolsCell(
                  key: const Key('mainBrowseSourcePools'),
                  title: l10n.mainBrowsePoolsTab,
                  subtitle: l10n.mainBrowsePoolsComingSoon,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceCell extends StatelessWidget {
  const _SourceCell({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final color = selected ? tokens.accent : tokens.onMediaMuted;
    final style = tokens.labelOnMedia.copyWith(
      color: color,
      shadows: tokens.onMediaLabelShadows,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: style,
        ),
      ),
    );
  }
}

/// Visible + disabled Pools tab with on-cell "Coming soon" ARB (no SnackBar).
class _PoolsCell extends StatelessWidget {
  const _PoolsCell({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final muted = tokens.onMediaMuted.withValues(alpha: 0.55);
    final shadows = tokens.onMediaLabelShadows;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: tokens.labelOnMedia.copyWith(
              color: muted,
              shadows: shadows,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: tokens.bodyOnMedia.copyWith(
              color: muted,
              fontSize: 11,
              height: 1.1,
              shadows: shadows,
            ),
            key: const Key('mainBrowsePoolsComingSoon'),
          ),
        ],
      ),
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
    final labelStyle = tokens.labelChrome.copyWith(fontSize: 11, height: 1.0);

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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.mainBrowseNavSettings, style: tokens.titleChrome),
            const SizedBox(height: 12),
            Text(
              l10n.mainBrowseStubSettingsBody,
              style: tokens.bodyChrome.copyWith(color: tokens.onSurface),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 24),
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
      ),
    );
  }
}
