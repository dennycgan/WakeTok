import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/settings_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 19.7 — Gestures preference block (KV owned by 19.6).
/// Cap 31.1 — hierarchy; explanatory copy in info bubbles (list = title+i).
class Cap19GesturesSettingsSection extends ConsumerStatefulWidget {
  const Cap19GesturesSettingsSection({super.key});

  @override
  ConsumerState<Cap19GesturesSettingsSection> createState() =>
      _Cap19GesturesSettingsSectionState();
}

class _Cap19GesturesSettingsSectionState
    extends ConsumerState<Cap19GesturesSettingsSection> {
  bool _loaded = false;
  bool _addEnabled = true;
  bool _guideEnabled = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final prefs = ref.read(cap19LeftSwipePreferencesProvider);
    final add = await prefs.isLeftSwipeAddEnabled();
    final guide = await prefs.isLeftSwipeGuideEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _loaded = true;
      _addEnabled = add;
      _guideEnabled = guide;
    });
  }

  Future<void> _setAddEnabled(bool value) async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _addEnabled = value;
      // Settings UX: master change syncs tip switch once (UI + KV).
      _guideEnabled = value;
    });
    final prefs = ref.read(cap19LeftSwipePreferencesProvider);
    await prefs.setLeftSwipeAddEnabled(value);
    await prefs.setLeftSwipeGuideEnabled(value);
    ref.read(cap19LeftSwipePrefsRevisionProvider.notifier).bump();
    if (mounted) {
      setState(() => _saving = false);
    }
  }

  Future<void> _setGuideEnabled(bool value) async {
    if (_saving || !_addEnabled) {
      return;
    }
    setState(() {
      _saving = true;
      _guideEnabled = value;
    });
    await ref
        .read(cap19LeftSwipePreferencesProvider)
        .setLeftSwipeGuideEnabled(value);
    ref.read(cap19LeftSwipePrefsRevisionProvider.notifier).bump();
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

    final guideInteractive = _addEnabled;

    return Column(
      key: const Key('cap19GesturesSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: l10n.cap19SettingsGesturesSectionTitle),
        const SizedBox(height: kSettingsSectionTitleToRowGap),
        SettingsToggleRow(
          key: const Key('cap19SettingsLeftSwipeAddToggle'),
          title: l10n.cap19SettingsLeftSwipeAddTitle,
          value: _addEnabled,
          enabled: true,
          onChanged: _setAddEnabled,
          infoMessage: l10n.cap19SettingsLeftSwipeAddSubtitle,
          infoSemanticsLabel: l10n.settingsInfoBubbleSemantics,
          infoButtonKey: const Key('cap19SettingsLeftSwipeAddInfo'),
          infoBubbleKey: const Key('cap19SettingsLeftSwipeAddInfoBubble'),
          infoBarrierKey: const Key('cap19SettingsLeftSwipeAddInfoBarrier'),
        ),
        const SizedBox(height: kSettingsRowGap),
        SettingsToggleRow(
          key: const Key('cap19SettingsLeftSwipeGuideToggle'),
          title: l10n.cap19SettingsLeftSwipeGuideTitle,
          value: _guideEnabled,
          enabled: guideInteractive,
          onChanged: guideInteractive ? _setGuideEnabled : null,
          infoMessage: l10n.cap19SettingsLeftSwipeGuideSubtitle,
          infoSemanticsLabel: l10n.settingsInfoBubbleSemantics,
          infoButtonKey: const Key('cap19SettingsLeftSwipeGuideInfo'),
          infoBubbleKey: const Key('cap19SettingsLeftSwipeGuideInfoBubble'),
          infoBarrierKey: const Key('cap19SettingsLeftSwipeGuideInfoBarrier'),
        ),
      ],
    );
  }
}
