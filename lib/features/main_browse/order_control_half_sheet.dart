import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/order_control_panel_open.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Bottom-bar short label for the effective order policy (ADR-055).
String orderPolicySlotLabel(AppLocalizations l10n, OrderPolicy policy) {
  return switch (policy) {
    OrderPolicy.newestFirst => l10n.mainBrowseOrderNewest,
    OrderPolicy.oldestFirst => l10n.mainBrowseOrderOldest,
    OrderPolicy.shuffle => l10n.mainBrowseOrderShuffle,
  };
}

/// Half-sheet option label (full wording; not abbreviated like the slot).
String orderPolicySheetLabel(AppLocalizations l10n, OrderPolicy policy) {
  return switch (policy) {
    OrderPolicy.newestFirst => l10n.mainBrowseOrderSheetNewest,
    OrderPolicy.oldestFirst => l10n.mainBrowseOrderSheetOldest,
    OrderPolicy.shuffle => l10n.mainBrowseOrderSheetShuffle,
  };
}

/// Effective process order (`preference ?? shuffle`) — ADR-055 / ADR-056 D6.
OrderPolicy effectiveBrowseOrderPolicy(OrderPolicy? preference) {
  return preference ?? OrderPolicy.shuffle;
}

/// Opens the Cap 27.4 order-control half-sheet (ADR-055 Layer 1 only).
///
/// Stricter than Cap 24 "…": [isDismissible] and [enableDrag] are both false.
/// Confirm / Cancel (and PopScope-blocked system back) are the only exits.
Future<void> showOrderControlHalfSheet(BuildContext context) {
  final darkTheme = waketokTheme(Brightness.dark);
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  final panelOpen = ProviderScope.containerOf(context)
      .read(orderControlPanelOpenProvider.notifier);
  panelOpen.setOpen(true);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    isDismissible: false,
    barrierColor: tokens.feedBackground.withValues(
      alpha: kCap19ActionsHalfSheetBarrierOpacity,
    ),
    backgroundColor: Colors.transparent,
    builder: (context) => Theme(
      data: darkTheme,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: ColoredBox(
          color: tokens.mediaSheetSurface.withValues(
            alpha: kCap19ActionsHalfSheetTintOpacity,
          ),
          child: const OrderControlHalfSheet(),
        ),
      ),
    ),
  ).whenComplete(() => panelOpen.setOpen(false));
}

class OrderControlHalfSheet extends ConsumerStatefulWidget {
  const OrderControlHalfSheet({super.key});

  @override
  ConsumerState<OrderControlHalfSheet> createState() =>
      _OrderControlHalfSheetState();
}

class _OrderControlHalfSheetState extends ConsumerState<OrderControlHalfSheet> {
  late OrderPolicy _draft;

  @override
  void initState() {
    super.initState();
    _draft = effectiveBrowseOrderPolicy(ref.read(browseOrderPreferenceProvider));
  }

  Future<void> _onConfirm() async {
    final applied = await ref
        .read(browseSessionProvider.notifier)
        .applyConfirmedOrderPreference(_draft);
    if (!mounted) {
      return;
    }
    if (applied) {
      // New head at index 0 — reset current-item chrome only (not session L2).
      ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      ref.read(mainBrowseVerticalFeedSettledProvider.notifier).setSettled(true);
      ref
          .read(mainBrowseCurrentAssetHostUnavailableProvider.notifier)
          .setUnavailable(false);
      ref
          .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
          .setReady(false);
      ref
          .read(mainBrowseCurrentLiveMotionMountedProvider.notifier)
          .setMounted(false);
      ref
          .read(mainBrowseCurrentAssetListAvailabilityProvider.notifier)
          .setAvailability(null);
    }
    Navigator.of(context).pop();
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.onMedia,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMedia,
        );

    return PopScope(
      canPop: false,
      child: KeyedSubtree(
        key: const Key('orderControlHalfSheet'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: tokens.onMedia.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(l10n.mainBrowseOrderSheetTitle, style: titleStyle),
              const SizedBox(height: 12),
              for (final policy in OrderPolicy.values)
                RadioListTile<OrderPolicy>(
                  key: Key('orderControlOption_${policy.name}'),
                  value: policy,
                  groupValue: _draft,
                  onChanged: (next) {
                    if (next == null) {
                      return;
                    }
                    setState(() => _draft = next);
                  },
                  activeColor: tokens.accent,
                  title: Text(
                    orderPolicySheetLabel(l10n, policy),
                    style: bodyStyle,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('orderControlCancel'),
                      onPressed: _onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tokens.onMedia,
                        side: BorderSide(
                          color: tokens.onMedia.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(l10n.mainBrowseOrderSheetCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('orderControlConfirm'),
                      onPressed: () => unawaited(_onConfirm()),
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        foregroundColor: tokens.onAccent,
                      ),
                      child: Text(l10n.mainBrowseOrderSheetConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
