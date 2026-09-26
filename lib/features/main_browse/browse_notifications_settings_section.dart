import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/new_round_toast_providers.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 22.5 — Browse notifications preferences (separate from Gestures).
/// Cap 31.1 — explanatory copy in info bubble (list = title+i only).
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

    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const Key('browseNotificationsSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: l10n.browseSettingsSectionTitle),
        const SizedBox(height: kSettingsSectionTitleToRowGap),
        SettingsToggleRow(
          key: const Key('browseSettingsNewRoundToastToggle'),
          title: l10n.browseSettingsNewRoundToastTitle,
          value: _newRoundEnabled,
          onChanged: _setNewRoundEnabled,
          // Full explanation (place + duration + dismiss) in the bubble.
          infoMessage: l10n.browseSettingsNewRoundToastInfo,
          infoSemanticsLabel: l10n.settingsInfoBubbleSemantics,
          infoButtonKey: const Key('browseSettingsNewRoundToastInfo'),
          infoBubbleKey: const Key('browseSettingsNewRoundToastInfoBubble'),
          infoBarrierKey: const Key('browseSettingsNewRoundToastInfoBarrier'),
        ),
      ],
    );
  }
}
