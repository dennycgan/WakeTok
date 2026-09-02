import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 19.7 — Gestures preference block (KV owned by 19.6).
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

    final guideInteractive = _addEnabled;

    return Column(
      key: const Key('cap19GesturesSettingsSection'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.cap19SettingsGesturesSectionTitle, style: titleStyle),
        const SizedBox(height: 8),
        _GestureToggleRow(
          key: const Key('cap19SettingsLeftSwipeAddToggle'),
          title: l10n.cap19SettingsLeftSwipeAddTitle,
          subtitle: l10n.cap19SettingsLeftSwipeAddSubtitle,
          value: _addEnabled,
          enabled: true,
          titleStyle: bodyStyle,
          subtitleStyle: mutedStyle,
          onChanged: _setAddEnabled,
        ),
        const SizedBox(height: 4),
        Opacity(
          opacity: guideInteractive ? 1 : 0.45,
          child: _GestureToggleRow(
            key: const Key('cap19SettingsLeftSwipeGuideToggle'),
            title: l10n.cap19SettingsLeftSwipeGuideTitle,
            subtitle: l10n.cap19SettingsLeftSwipeGuideSubtitle,
            value: _guideEnabled,
            enabled: guideInteractive,
            titleStyle: bodyStyle,
            subtitleStyle: mutedStyle,
            onChanged: guideInteractive ? _setGuideEnabled : null,
          ),
        ),
      ],
    );
  }
}

class _GestureToggleRow extends StatelessWidget {
  const _GestureToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(height: 2),
              Text(subtitle, style: subtitleStyle),
            ],
          ),
        ),
        const SizedBox(width: 12),
        CupertinoSwitch(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}
