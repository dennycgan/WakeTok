import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/new_round_toast_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 22.5 — Browse notifications preferences (separate from Gestures).
class BrowseNotificationsSettingsSection extends ConsumerStatefulWidget {
  const BrowseNotificationsSettingsSection({super.key});

  @override
  ConsumerState<BrowseNotificationsSettingsSection> createState() =>
      _BrowseNotificationsSettingsSectionState();
}

class _BrowseNotificationsSettingsSectionState
    extends ConsumerState<BrowseNotificationsSettingsSection> {
  bool _loaded = false;
  bool _newRoundEnabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final prefs = ref.read(newRoundToastPreferencesProvider);
    final enabled = await prefs.isNewRoundToastEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _loaded = true;
      _newRoundEnabled = enabled;
    });
  }

  Future<void> _setNewRoundEnabled(bool value) async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _newRoundEnabled = value;
    });
    await ref
        .read(newRoundToastPreferencesProvider)
        .setNewRoundToastEnabled(value);
    ref.read(newRoundToastPrefsRevisionProvider.notifier).bump();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: tokens.onSurface,
          fontWeight: FontWeight.w600,
        );
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: tokens.onSurface,
        );
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: tokens.onSurface.withValues(alpha: 0.65),
        );

    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('browseNotificationsSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.browseSettingsSectionTitle, style: titleStyle),
        const SizedBox(height: 8),
        Row(
          key: const Key('browseSettingsNewRoundToastToggle'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.browseSettingsNewRoundToastTitle,
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.browseSettingsNewRoundToastSubtitle,
                    style: mutedStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CupertinoSwitch(
              value: _newRoundEnabled,
              onChanged: _setNewRoundEnabled,
            ),
          ],
        ),
      ],
    );
  }
}
