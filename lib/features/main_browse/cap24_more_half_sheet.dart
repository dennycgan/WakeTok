import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap24_browse_toast.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';
import 'package:waketok/features/main_browse/cap24_more_panel_open.dart';
import 'package:waketok/features/main_browse/cap24_panel_host_context.dart';
import 'package:waketok/features/main_browse/cap24_soft_delete_dialogs.dart';
import 'package:waketok/features/main_browse/cap24_timezone_note_bubble.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/playback_coordinator_provider.dart';
import 'package:waketok/features/main_browse/presentation_size_cache.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Vertical gap between "…" half-sheet meta blocks (Cap 26.4).
const double kCap24MoreSheetMetaBlockGap = 16;

/// Gap between a meta row title and its value line (both File size and
/// Saved time — optical, not inflated by the timezone `i` hit target).
const double kCap24MoreSheetTitleValueGap = 4;

/// Layout width reserved for the timezone `i` control in the value row.
const double kCap24MoreSheetTimezoneInfoLayoutWidth = 36;

/// Minimum tap target for timezone `i` (overflows the value-line height).
const double kCap24MoreSheetTimezoneInfoHit = 44;

/// Opens the Cap 24 more half-sheet (meta rows + Delete; Cap 26.5 Add later).
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
          child: ColoredBox(
            color: tokens.mediaSheetSurface.withValues(
              alpha: kCap19ActionsHalfSheetTintOpacity,
            ),
            child: const Cap24MoreHalfSheet(),
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
  var _sizeRequestGen = 0;
  var _hostBusy = false;
  var _deleteLatch = false;
  Cap24TimezoneNoteBubbleHandle? _timezoneNoteBubble;
  final GlobalKey _timezoneInfoAnchorKey = GlobalKey();
  /// Barrier dismiss + IconButton can both see the same tap (translucent
  /// barrier). Consume one reopen attempt so re-tap i only closes.
  var _suppressTimezoneInfoReopen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadLandmark();
      _requestSizeIfNeeded();
      if (ref.read(mainBrowseCurrentAssetLayer2DisplayReadyProvider)) {
        _requestSizeIfNeeded(refreshResolvedNil: true);
      }
    });
  }

  @override
  void dispose() {
    _dismissTimezoneNoteBubble();
    super.dispose();
  }

  void _dismissTimezoneNoteBubble() {
    _timezoneNoteBubble?.dismiss();
    _timezoneNoteBubble = null;
  }

  void _toggleTimezoneNoteBubble() {
    if (_timezoneNoteBubble?.isShowing == true) {
      _dismissTimezoneNoteBubble();
      setState(() {});
      return;
    }
    if (_suppressTimezoneInfoReopen) {
      _suppressTimezoneInfoReopen = false;
      return;
    }
    // Latch (includes Host busy): never open — avoids bubble vs PopScope fights.
    if (_deleteLatch) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    _timezoneNoteBubble = showCap24TimezoneNoteBubble(
      context: context,
      anchorKey: _timezoneInfoAnchorKey,
      message: l10n.cap24SoftDeleteSheetMinuteTimezoneNote,
      onDismissed: () {
        _timezoneNoteBubble = null;
        _suppressTimezoneInfoReopen = true;
        if (mounted) {
          setState(() {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _suppressTimezoneInfoReopen = false;
        });
      },
    );
    setState(() {});
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

  /// Cap 26.4: request only when shared cache lacks non-null bytes.
  /// Open skips when already [PresentationSizeEntry.resolved] (incl. nil → "—").
  /// L2-ready may set [refreshResolvedNil] to re-ask after a nil resolve.
  /// Results write through [presentationSizeCacheProvider.apply] (keepExisting).
  Future<void> _requestSizeIfNeeded({bool refreshResolvedNil = false}) async {
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      return;
    }
    final existing = ref.read(presentationSizeCacheProvider)[assetId];
    if (existing?.fileSizeBytes != null) {
      return;
    }
    if (existing?.resolved == true && !refreshResolvedNil) {
      return;
    }

    final gen = ++_sizeRequestGen;
    final repo = ref.read(presentationMetadataRepositoryProvider);
    final cache = ref.read(presentationSizeCacheProvider.notifier);
    PresentationFileSize size;
    try {
      size = await repo.requestPresentationFileSize(assetId);
      final raw = size.fileSizeBytes;
      if (raw != null && raw < 0) {
        size = PresentationFileSize(
          assetIdentifier: assetId,
          fileSizeBytes: null,
          fileSizeSemantics: size.fileSizeSemantics,
        );
      }
    } on Object {
      size = PresentationFileSize(assetIdentifier: assetId);
    }
    // Apply even if the sheet was dismissed — session cache outlives the sheet.
    // Do not touch [ref] after the await (widget may be unmounted).
    if (gen != _sizeRequestGen) {
      return;
    }
    cache.apply(assetId, size);
  }

  Future<void> _onDelete() async {
    if (_deleteLatch) {
      return;
    }
    _deleteLatch = true;
    // Close honesty bubble before latch UI; dismiss never pops the sheet.
    _dismissTimezoneNoteBubble();
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

  String _sizeValueText(
    AppLocalizations l10n,
    PresentationSizeEntry? entry,
  ) {
    if (entry == null || !entry.resolved) {
      return '';
    }
    if (entry.fileSizeBytes == null) {
      return l10n.cap24MoreSheetUnavailableValue;
    }
    return formatOverlayFileSize(
      l10n: l10n,
      fileSizeBytes: entry.fileSizeBytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final assetId = ref.watch(mainBrowseCurrentAssetIdProvider);
    final sizeEntry = assetId == null
        ? null
        : ref.watch(presentationSizeCacheProvider)[assetId];
    final titleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.onMediaMuted,
        );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMedia,
        );
    // Match File size / Saved time value-line height to the text metrics only.
    final valueFontSize = valueStyle?.fontSize ?? 14;
    final valueHeightFactor = valueStyle?.height ?? 1.0;
    final valueLineHeight = valueFontSize * valueHeightFactor;
    // Cap 24 half-sheet Delete: outlined destructive (iOS systemRed via
    // tokens.destructive), not brand accent fill. Overturns the brief
    // "accept accent filled" draft. Cap 24 destructive #FF3B30 and Cap 22
    // accent delete-label text (#FC2555 Light) are two independent decisions —
    // coexistence is intentional until a future design-system pass; not a bug.
    final deleteButtonStyle = OutlinedButton.styleFrom(
      foregroundColor: tokens.destructive,
      disabledForegroundColor: tokens.destructive,
      side: BorderSide(color: tokens.destructive),
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height * kCap19ActionsHalfSheetMaxHeightFactor;
    final busy = _hostBusy;
    final latch = _deleteLatch;

    // Cap 26.4: Overlay-equivalent size refresh when L2 becomes ready.
    ref.listen<bool>(mainBrowseCurrentAssetLayer2DisplayReadyProvider,
        (previous, next) {
      if (previous != true && next == true) {
        _requestSizeIfNeeded(refreshResolvedNil: true);
      }
    });

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
                // Cap 26.4: Location content deferred (debt 401); zero-height slot.
                const KeyedSubtree(
                  key: Key('cap24MoreSheetLocationSlot'),
                  child: SizedBox.shrink(),
                ),
                _moreSheetMetaBlock(
                  blockKey: const Key('cap24MoreSheetFileSizeBlock'),
                  titleKey: const Key('cap24MoreSheetFileSizeTitle'),
                  title: l10n.cap24MoreSheetFileSizeTitle,
                  titleStyle: titleStyle,
                  value: Text(
                    _sizeValueText(l10n, sizeEntry),
                    key: const Key('cap24MoreSheetFileSizeValue'),
                    style: valueStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: kCap24MoreSheetMetaBlockGap),
                if (_landmarkResolved && _landmark != null) ...[
                  _moreSheetMetaBlock(
                    blockKey: const Key('cap24MoreSheetSavedTimeBlock'),
                    titleKey: const Key('cap24MoreSheetSavedTimeTitle'),
                    title: l10n.cap24MoreSheetSavedTimeTitle,
                    titleStyle: titleStyle,
                    value: Row(
                      // Icon immediately after the time — not trailing-end.
                      // Keep value-line height = text line (same as File size);
                      // 44pt `i` hit overflows via OverflowBox so title→value
                      // optical gap stays kCap24MoreSheetTitleValueGap.
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: Text(
                            _landmark!.displayText,
                            key: Key(
                              _landmark!.fromLibrary
                                  ? 'cap24SoftDeleteSheetMinuteLibrary'
                                  : 'cap24SoftDeleteSheetMinuteBare',
                            ),
                            style: valueStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Semantics(
                          button: true,
                          label: l10n
                              .cap24SoftDeleteSheetMinuteTimezoneInfoSemantics,
                          child: KeyedSubtree(
                            key: const Key(
                              'cap24SoftDeleteSheetMinuteTimezoneInfo',
                            ),
                            child: SizedBox(
                              width: kCap24MoreSheetTimezoneInfoLayoutWidth,
                              height: valueLineHeight,
                              child: OverflowBox(
                                minWidth: kCap24MoreSheetTimezoneInfoHit,
                                maxWidth: kCap24MoreSheetTimezoneInfoHit,
                                minHeight: kCap24MoreSheetTimezoneInfoHit,
                                maxHeight: kCap24MoreSheetTimezoneInfoHit,
                                alignment: Alignment.center,
                                child: IconButton(
                                  key: _timezoneInfoAnchorKey,
                                  icon: Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: tokens.onMediaMuted,
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(
                                    minWidth: kCap24MoreSheetTimezoneInfoHit,
                                    minHeight: kCap24MoreSheetTimezoneInfoHit,
                                  ),
                                  onPressed:
                                      latch ? null : _toggleTimezoneNoteBubble,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kCap24MoreSheetMetaBlockGap),
                ],
                OutlinedButton(
                  key: const Key('cap24SoftDeleteSheetDelete'),
                  onPressed: latch ? null : _onDelete,
                  style: deleteButtonStyle,
                  child: busy
                      ? SizedBox(
                          key: const Key('cap24SoftDeleteSheetDeleteBusy'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: tokens.destructive,
                          ),
                        )
                      : Text(
                          l10n.cap24SoftDeleteSheetDelete,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: tokens.destructive,
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

/// Shared title + value chrome so File size / Saved time use the same gap.
Widget _moreSheetMetaBlock({
  required Key blockKey,
  required Key titleKey,
  required String title,
  required TextStyle? titleStyle,
  required Widget value,
}) {
  return KeyedSubtree(
    key: blockKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: titleKey,
          style: titleStyle,
        ),
        const SizedBox(height: kCap24MoreSheetTitleValueGap),
        value,
      ],
    ),
  );
}
