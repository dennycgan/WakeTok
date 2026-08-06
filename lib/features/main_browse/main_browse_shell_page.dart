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
class MainBrowseShellPage extends ConsumerWidget {
  const MainBrowseShellPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final destination = ref.watch(mainBrowseDestinationProvider);

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
            onSelect: (next) =>
                ref.read(mainBrowseDestinationProvider.notifier).select(next),
          ),
        ],
      ),
    );
  }
}

class _BrowsePane extends ConsumerWidget {
  const _BrowsePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(mainBrowseSelectedSourceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopSourceChrome(
          selected: selected,
          onSelect: (next) =>
              ref.read(mainBrowseSelectedSourceProvider.notifier).select(next),
        ),
        const Expanded(child: VerticalMediaFeed()),
      ],
    );
  }
}

/// Custom four-cell top chrome — avoids Material SegmentedButton defaults
/// (secondaryContainer). Selected label uses [WakeTokTokens.accent].
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
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    return Material(
      color: tokens.surface,
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
    final color =
        selected ? tokens.accent : tokens.onSurface.withValues(alpha: 0.55);
    final style = tokens.labelChrome.copyWith(color: color);

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
    final muted = tokens.onSurface.withValues(alpha: 0.38);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: tokens.labelChrome.copyWith(color: muted),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: tokens.bodyChrome.copyWith(
              color: muted,
              fontSize: 11,
              height: 1.1,
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

    // Explicit indicatorColor — must not rely on ColorScheme.secondaryContainer.
    return NavigationBar(
      key: const Key('mainBrowseNavigationBar'),
      backgroundColor: tokens.surface,
      indicatorColor: tokens.accent.withValues(alpha: 0.20),
      selectedIndex: selected.index,
      onDestinationSelected: (i) => onSelect(MainBrowseDestination.values[i]),
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home, color: tokens.accent),
          label: l10n.mainBrowseNavBrowse,
        ),
        NavigationDestination(
          icon: const Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie, color: tokens.accent),
          label: l10n.mainBrowseNavClips,
        ),
        NavigationDestination(
          icon: const Icon(Icons.play_circle_outline),
          selectedIcon: Icon(Icons.play_circle, color: tokens.accent),
          label: l10n.mainBrowseNavAuto,
        ),
        NavigationDestination(
          icon: const Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: tokens.accent),
          label: l10n.mainBrowseNavSettings,
        ),
      ],
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
