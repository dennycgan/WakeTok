import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/main_browse/cap19_album_picker_list.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_favorites_row.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/cap19_panel_host_context.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Opens the Cap 19 Add-to-Album half-sheet (ADR-040 D15 / STATE D4).
Future<void> showCap19ActionsHalfSheet(
  BuildContext context, {
  required PhotosAccess access,
}) {
  final darkTheme = waketokTheme(Brightness.dark);
  final tokens = darkTheme.extension<WakeTokTokens>()!;
  final hostContext = context;
  final panelOpen = ProviderScope.containerOf(context)
      .read(cap19ActionsPanelOpenProvider.notifier);
  panelOpen.state = true;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: tokens.feedBackground.withValues(
      alpha: kCap19ActionsHalfSheetBarrierOpacity,
    ),
    backgroundColor: Colors.transparent,
    builder: (context) => Cap19PanelHostContext(
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
              child: Cap19ActionsHalfSheet(access: access),
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() => panelOpen.state = false);
}

class Cap19ActionsHalfSheet extends ConsumerWidget {
  const Cap19ActionsHalfSheet({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.onMedia,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onMediaMuted,
        );
    final maxSheetHeight =
        MediaQuery.sizeOf(context).height * kCap19ActionsHalfSheetMaxHeightFactor;

    return KeyedSubtree(
      key: const Key('cap19ActionsHalfSheet'),
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
              Text(l10n.cap19PanelAddToAlbumTitle, style: titleStyle),
              const SizedBox(height: 16),
              if (access == PhotosAccess.limited) ...[
                AbsorbPointer(
                  child: Column(
                    key: const Key('cap19PanelAddToAlbumLimitedRow'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.cap19PanelAddToAlbumLimitedMessage,
                        style: bodyStyle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    key: const Key('cap19PanelOpenSettings'),
                    onPressed: () => ref.read(openAppSettingsProvider)(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.onMedia,
                      side: BorderSide(
                        color: tokens.onMedia.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(l10n.permissionOpenSettings),
                  ),
                ),
              ] else ...[
                const Cap19FavoritesRow(),
                Divider(
                  height: 24,
                  color: tokens.onMedia.withValues(alpha: 0.12),
                ),
                const Cap19AlbumPickerList(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
