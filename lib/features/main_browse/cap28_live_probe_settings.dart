import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap28_live_probe.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 28.1 live probe controls (Profile/Debug; `!kReleaseMode`).
///
/// Writes [kCap28LiveProbeLogFileName] for Settings round-trip / black-frame
/// diagnosis. Release is a no-op (section hidden).
class Cap28LiveProbeSettingsSection extends ConsumerWidget {
  const Cap28LiveProbeSettingsSection({super.key});

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
      key: const Key('cap28LiveProbeSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.cap28LiveProbeSectionTitle,
          style: tokens.titleChrome,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cap28LiveProbeBlurb,
          style: tokens.bodyChrome.copyWith(color: tokens.onSurface),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('cap28LiveProbeClear'),
          onPressed: () {
            Cap28LiveProbe.clear();
          },
          child: Text(l10n.cap28LiveProbeClear),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('cap28LiveProbeMarkBlack'),
          onPressed: () {
            Cap28LiveProbe.markBlackFrame(extra: _snapshot(ref));
          },
          child: Text(l10n.cap28LiveProbeMarkBlack),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('cap28LiveProbeMarkOk'),
          onPressed: () {
            Cap28LiveProbe.markReturnOk(extra: _snapshot(ref));
          },
          child: Text(l10n.cap28LiveProbeMarkOk),
        ),
      ],
    );
  }
}
