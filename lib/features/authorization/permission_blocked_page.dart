import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/open_app_settings.dart';
import 'package:waketok/features/authorization/permission_page_style.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Denied / restricted gate — does not enter normal browse (ADR-K §5).
class PermissionBlockedPage extends ConsumerWidget {
  const PermissionBlockedPage({super.key, required this.access});

  final PhotosAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final style = PermissionPageStyle.of(context);
    final title = access == PhotosAccess.restricted
        ? l10n.permissionBlockedTitleRestricted
        : l10n.permissionBlockedTitleDenied;

    return Scaffold(
      backgroundColor: tokens.background,
      body: SafeArea(
        // Not primary: when the content fits, the page must not drag or
        // bounce; it scrolls only when large text makes it overflow.
        child: CustomScrollView(
          primary: false,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: kPermissionPagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Text(l10n.appTitle, style: style.appName),
                    const SizedBox(height: kPermissionAppNameToHeadlineGap),
                    Text(title, style: style.headline),
                    const SizedBox(height: kPermissionHeadlineToBodyGap),
                    Text(l10n.permissionBlockedBody, style: style.body),
                    const SizedBox(height: kPermissionTextToButtonGap),
                    FilledButton(
                      style: style.button,
                      onPressed: () => ref.read(openAppSettingsProvider)(),
                      child: Text(
                        l10n.permissionOpenSettings,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
