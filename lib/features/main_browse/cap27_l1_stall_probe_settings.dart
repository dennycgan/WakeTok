import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap27_l1_stall_probe.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 27 L1-stall probe controls (Profile/Debug; `!kReleaseMode`).
///
/// Kept while debt **478** (non-`deviceLocal` / iCloud remount soft L1 stick)
/// is Open. Same gate as [cap27L1StallProbeEnabled] — Release is a no-op.
class Cap27L1StallProbeSettingsSection extends ConsumerWidget {
  const Cap27L1StallProbeSettingsSection({super.key});

  Map<String, Object?> _snapshot(WidgetRef ref) {
    final view = ref.read(browseSessionProvider).asData?.value;
    final feedIndex = ref.read(mainBrowseFeedIndexProvider);
    final ids = view?.orderedAssetIds ?? const <String>[];
    final headId = ids.isEmpty ? null : ids.first;
    final currentId =
        (feedIndex >= 0 && feedIndex < ids.length) ? ids[feedIndex] : null;
    return {
      'roundEpoch': view?.roundEpoch,
      'orderPolicy': view?.session.queue.configuration.orderPolicy.name,
      'feedIndex': feedIndex,
      'queueLen': ids.length,
      'headId': headId,
      'currentId': currentId,
      'l2ReadyHead': headId == null
          ? null
          : ref.read(browseL2ReadySessionProvider).containsKey(headId),
      'l2ReadyCurrent': currentId == null
          ? null
          : ref.read(browseL2ReadySessionProvider).containsKey(currentId),
      'layer2DisplayReady':
          ref.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider),
      'destination': ref.read(mainBrowseDestinationProvider).name,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.cap27L1StallProbeSectionTitle,
          style: tokens.titleChrome,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cap27L1StallProbeBlurb,
          style: tokens.bodyChrome.copyWith(color: tokens.onSurface),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('cap27L1StallProbeMarkStuck'),
          onPressed: () {
            Cap27L1StallProbe.markStuck(extra: _snapshot(ref));
          },
          child: Text(l10n.cap27L1StallProbeMarkStuck),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('cap27L1StallProbeMarkHealed'),
          onPressed: () {
            Cap27L1StallProbe.markHealed(extra: _snapshot(ref));
          },
          child: Text(l10n.cap27L1StallProbeMarkHealed),
        ),
      ],
    );
  }
}
