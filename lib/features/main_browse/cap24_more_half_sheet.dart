import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap24_browse_toast.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';
import 'package:waketok/features/main_browse/cap24_more_panel_open.dart';
import 'package:waketok/features/main_browse/cap24_panel_host_context.dart';
import 'package:waketok/features/main_browse/cap24_soft_delete_dialogs.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/playback_coordinator_provider.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Opens the Cap 24 more half-sheet (Delete + minute landmark).
Future<void> showCap24MoreHalfSheet(BuildContext context) {
  final darkTheme = waketokTheme(Brightness.dark);
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  final hostContext = context;
  final panelOpen = ProviderScope.containerOf(context)
      .read(cap24MorePanelOpenProvider.notifier);
  panelOpen.setOpen(true);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // Drag-dismiss off: PopScope on the sheet owns Host-busy non-dismiss.
    // Idle dismiss = barrier tap / system back (when !hostBusy).
    enableDrag: false,
    isDismissible: true,
    barrierColor: tokens.feedBackground.withValues(
      alpha: kCap19ActionsHalfSheetBarrierOpacity,
    ),
    backgroundColor: Colors.transparent,
    builder: (context) => Cap24PanelHostContext(
      hostContext: hostContext,
      child: Theme(
        data: darkTheme,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: kCap19ActionsHalfSheetBlurSigma,
              sigmaY: kCap19ActionsHalfSheetBlurSigma,
            ),
            child: ColoredBox(
              color: tokens.feedBackground.withValues(
                alpha: kCap19ActionsHalfSheetTintOpacity,
              ),
              child: const Cap24MoreHalfSheet(),
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() => panelOpen.setOpen(false));
}

class Cap24MoreHalfSheet extends ConsumerStatefulWidget {
  const Cap24MoreHalfSheet({super.key});

  @override
  ConsumerState<Cap24MoreHalfSheet> createState() => _Cap24MoreHalfSheetState();
}

class _Cap24MoreHalfSheetState extends ConsumerState<Cap24MoreHalfSheet> {
  Cap24MinuteLandmark? _landmark;
  var _landmarkResolved = false;
  var _hostBusy = false;
  var _deleteLatch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLandmark());
  }

  Future<void> _loadLandmark() async {
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _landmark = null;
        _landmarkResolved = true;
      });
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final loader = ref.read(cap24MinuteLandmarkLoaderProvider);
    Cap24MinuteLandmark? result;
    try {
      result = await loader(
        l10n: l10n,
        assetIdentifier: assetId,
      );
    } on Object {
      result = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _landmark = result;
      _landmarkResolved = true;
    });
  }

  Future<void> _onDelete() async {
    if (_deleteLatch) {
      return;
    }
    _deleteLatch = true;
    // Latch alone blocks dismiss during Cap 23 gate; busy spinner only for Host.
    setState(() {});

    final hostContext = Cap24PanelHostContext.of(context);
    var clearBusy = true;
    try {
      final outcome = await runCap24SoftDelete(
        context: context,
        ref: ref,
        onHostStarting: () {
          if (mounted) {
            setState(() => _hostBusy = true);
          }
        },
      );
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case Cap24SoftDeleteOutcome.success:
          await _applySuccessQueueKick();
          if (!mounted) {
            return;
          }
          // Keep busy through pop so dismiss cannot race the kick.
          clearBusy = false;
          Navigator.of(context).pop();
        case Cap24SoftDeleteOutcome.failed:
          final l10n = AppLocalizations.of(context)!;
          showCap24SoftDeleteFailedToast(hostContext, l10n);
        case Cap24SoftDeleteOutcome.operationCancelled:
        case Cap24SoftDeleteOutcome.dismissed:
          break;
      }
    } finally {
      _deleteLatch = false;
      if (clearBusy && mounted) {
        setState(() => _hostBusy = false);
      }
    }
  }

  /// Cap 24.4: Host already succeeded — remove id from Queue and land playhead.
  Future<void> _applySuccessQueueKick() async {
    final deletedId = ref.read(mainBrowseCurrentAssetIdProvider);
    final feedIndex = ref.read(mainBrowseFeedIndexProvider);
    if (deletedId == null || deletedId.isEmpty) {
      return;
    }

    unawaited(ref.read(playbackCoordinatorProvider).onLeaveCurrent());

    final landed = ref.read(browseSessionProvider.notifier).removeAssetAndLand(
          assetId: deletedId,
          feedIndex: feedIndex,
        );
    if (landed == null) {
      return;
    }

    ref.read(browseL2ReadySessionProvider.notifier).evict(deletedId);
    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(landed);
    // Cap 24.4 / ADR-042 D8: intentional unconditional settled=true — not a
    // TODO. Mid-list land keeps the same feedIndex so setIndex is a no-op and
    // no gesture ScrollEnd / settle event will fire. Do not "fix" this by
    // waiting for PageController settle; that needs a separate mid-list signal
    // first — deleting this line alone would strand trailing chrome.
    ref.read(mainBrowseVerticalFeedSettledProvider.notifier).setSettled(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMediaMuted,
        );
    final deleteStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.accent,
        );
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height * kCap19ActionsHalfSheetMaxHeightFactor;
    final busy = _hostBusy;
    final latch = _deleteLatch;

    return PopScope(
      canPop: !latch,
      child: KeyedSubtree(
        key: const Key('cap24MoreHalfSheet'),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
                if (_landmarkResolved && _landmark != null) ...[
                  Text(
                    _landmark!.displayText,
                    key: Key(
                      _landmark!.isApproximate
                          ? 'cap24SoftDeleteSheetMinuteApprox'
                          : 'cap24SoftDeleteSheetMinuteBare',
                    ),
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.cap24SoftDeleteSheetMinuteTimezoneNote,
                    key: const Key('cap24SoftDeleteSheetMinuteTimezoneNote'),
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 16),
                ],
                InkWell(
                  key: const Key('cap24SoftDeleteSheetDelete'),
                  onTap: latch ? null : _onDelete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: busy
                        ? Center(
                            child: SizedBox(
                              key: const Key('cap24SoftDeleteSheetDeleteBusy'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.accent,
                              ),
                            ),
                          )
                        : Text(
                            l10n.cap24SoftDeleteSheetDelete,
                            style: deleteStyle,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
