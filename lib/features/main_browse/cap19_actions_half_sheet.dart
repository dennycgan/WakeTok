import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Opens the Cap 19 actions half-sheet (ADR-040 D15 / STATE D4).
Future<void> showCap19ActionsHalfSheet(
  BuildContext context, {
  required PhotosAccess access,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).extension<WakeTokTokens>()!.surface,
    builder: (context) => Cap19ActionsHalfSheet(access: access),
  );
}

class Cap19ActionsHalfSheet extends ConsumerWidget {
  const Cap19ActionsHalfSheet({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: tokens.onSurface,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );

    return KeyedSubtree(
      key: const Key('cap19ActionsHalfSheet'),
      child: Padding(
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
                  color: tokens.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(l10n.cap19PanelTitle, style: titleStyle),
            const SizedBox(height: 16),
            if (access == PhotosAccess.limited) ...[
              AbsorbPointer(
                child: Column(
                  key: const Key('cap19PanelAddToAlbumLimitedRow'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.cap19PanelAddToAlbumTitle,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 8),
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
                  child: Text(l10n.permissionOpenSettings),
                ),
              ),
            ] else ...[
              ListTile(
                key: const Key('cap19PanelAddToAlbumFullRow'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.cap19PanelAddToAlbumTitle,
                  style: bodyStyle,
                ),
                subtitle: Text(
                  l10n.cap19PanelAddToAlbumFullPlaceholder,
                  style: bodyStyle,
                ),
                enabled: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
