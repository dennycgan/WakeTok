import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap24_browse_toast.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';
import 'package:waketok/features/main_browse/cap24_more_panel_open.dart';
import 'package:waketok/features/main_browse/cap24_panel_host_context.dart';
import 'package:waketok/features/main_browse/cap24_soft_delete_dialogs.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
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
    final hostContext = Cap24PanelHostContext.of(context);
    final outcome = await showCap24SoftDeleteConfirmDialog(
      context: context,
      ref: ref,
    );
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case Cap24SoftDeleteConfirmOutcome.success:
        Navigator.of(context).pop();
      case Cap24SoftDeleteConfirmOutcome.failed:
        final l10n = AppLocalizations.of(context)!;
        showCap24SoftDeleteFailedToast(hostContext, l10n);
      case Cap24SoftDeleteConfirmOutcome.operationCancelled:
      case Cap24SoftDeleteConfirmOutcome.dismissed:
        break;
    }
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

    return KeyedSubtree(
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
                onTap: _onDelete,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    l10n.cap24SoftDeleteSheetDelete,
                    style: deleteStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
