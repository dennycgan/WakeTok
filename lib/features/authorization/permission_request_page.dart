import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/authorization/permission_page_style.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/l10n/app_localizations.dart';

const double _kPointGap = 8;
const double _kBulletSize = 5;
const double _kBulletGap = 10;

/// First-launch Photos permission explanation (system prompt follows CTA).
class PermissionRequestPage extends ConsumerWidget {
  const PermissionRequestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final style = PermissionPageStyle.of(context);
    // Empty in zh on purpose (see the ARB description): hide the line.
    final rediscover = l10n.permissionRequestPointRediscover.trim();
    final async = ref.watch(photosAuthorizationProvider);
    final busy = async.isLoading;

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
                    Text(
                      l10n.appTitle,
                      style: style.appNameFitted(context, l10n.appTitle),
                      textScaler: TextScaler.noScaling,
                      softWrap: false,
                    ),
                    const SizedBox(height: kPermissionAppNameToHeadlineGap),
                    Text(l10n.permissionRequestTitle, style: style.headline),
                    const SizedBox(height: kPermissionHeadlineToBodyGap),
                    if (rediscover.isNotEmpty) ...[
                      _BulletPoint(
                        text: rediscover,
                        style: style.body,
                        color: tokens.onSurface,
                      ),
                      const SizedBox(height: _kPointGap),
                    ],
                    _BulletPoint(
                      text: l10n.permissionRequestPointNoAccount,
                      style: style.body,
                      color: tokens.onSurface,
                    ),
                    const SizedBox(height: _kPointGap),
                    _BulletPoint(
                      text: l10n.permissionRequestPointChooseOrder,
                      style: style.body,
                      color: tokens.onSurface,
                    ),
                    const SizedBox(height: kPermissionTextToButtonGap),
                    FilledButton(
                      style: style.button,
                      onPressed: busy
                          ? null
                          : () => ref
                                .read(photosAuthorizationProvider.notifier)
                                .requestAccess(),
                      child: Text(
                        l10n.permissionRequestContinue,
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

/// Solid dot + text; the dot is centered on the first line.
class _BulletPoint extends StatelessWidget {
  const _BulletPoint({
    required this.text,
    required this.style,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final lineHeight = MediaQuery.textScalerOf(context)
            .scale(style.fontSize!) *
        style.height!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: (lineHeight - _kBulletSize) / 2),
          child: Container(
            width: _kBulletSize,
            height: _kBulletSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: _kBulletGap),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
