import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/cap29_access_scope_probe.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 29.2 / ADR-059 — Settings Photos Access entry (Debt 421).
///
/// Mounted only inside Settings [ListView] (not above [IndexedStack]).
/// Limited: reuse Limited banner copy + Manage / Open Settings calls.
/// Full: status + Open Settings only. Manage →
/// [PhotosAuthorizationNotifier.presentLimitedLibraryPicker] only (Cap 28.5
/// notify). Open Settings never notifies (ADR-058 D4 Out).
class PhotosAccessSettingsSection extends ConsumerWidget {
  const PhotosAccessSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: tokens.onSurface,
          fontWeight: FontWeight.w600,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );

    final async = ref.watch(photosAuthorizationProvider);
    final access = async.asData?.value;
    final busy = async.isLoading;

    // Shell only mounts for limited|full (PhotosAccessGate). Loading /
    // unexpected states keep the section title so layout does not jump.
    final isLimited = access == PhotosAccess.limited;
    final isFull = access == PhotosAccess.full;

    return Column(
      key: const Key('photosAccessSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.photosAccessSettingsSectionTitle, style: titleStyle),
        const SizedBox(height: 8),
        if (isLimited) ...[
          Text(l10n.limitedAccessBannerMessage, style: bodyStyle),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const Key('photosAccessManageSelection'),
                onPressed: busy
                    ? null
                    : () {
                        _probeTap(
                          ref,
                          event: 'MANAGE_TAP',
                          access: PhotosAccess.limited,
                        );
                        unawaited(
                          ref
                              .read(photosAuthorizationProvider.notifier)
                              .presentLimitedLibraryPicker(),
                        );
                      },
                child: Text(l10n.limitedAccessManageSelection),
              ),
              OutlinedButton(
                key: const Key('photosAccessOpenSettings'),
                onPressed: busy
                    ? null
                    : () {
                        _probeTap(
                          ref,
                          event: 'OPEN_SETTINGS_TAP',
                          access: PhotosAccess.limited,
                        );
                        unawaited(ref.read(openAppSettingsProvider)());
                      },
                child: Text(l10n.permissionOpenSettings),
              ),
            ],
          ),
        ] else if (isFull) ...[
          Text(l10n.photosAccessFullStatusMessage, style: bodyStyle),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              key: const Key('photosAccessOpenSettings'),
              onPressed: busy
                  ? null
                  : () {
                      _probeTap(
                        ref,
                        event: 'OPEN_SETTINGS_TAP',
                        access: PhotosAccess.full,
                      );
                      unawaited(ref.read(openAppSettingsProvider)());
                    },
              child: Text(l10n.permissionOpenSettings),
            ),
          ),
        ],
      ],
    );
  }

  static void _probeTap(
    WidgetRef ref, {
    required String event,
    required PhotosAccess access,
  }) {
    final dest = ref.read(mainBrowseDestinationProvider);
    unawaited(
      Cap29AccessScopeProbe.log(event, {
        'access': access.name,
        'dest': dest.name,
      }),
    );
  }
}
