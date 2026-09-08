import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_display_name.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/l10n/app_localizations.dart';

sealed class SavedPoolNamingOutcome {
  const SavedPoolNamingOutcome();
}

final class SavedPoolNamingCancelled extends SavedPoolNamingOutcome {
  const SavedPoolNamingCancelled();
}

final class SavedPoolNamingSaved extends SavedPoolNamingOutcome {
  const SavedPoolNamingSaved(this.record);
  final SavedPoolRecord record;
}

final class SavedPoolNamingAtCapacity extends SavedPoolNamingOutcome {
  const SavedPoolNamingAtCapacity();
}

/// Shared naming dialog (Build Save, peek Save; Rename uses [renamePoolId]).
Future<SavedPoolNamingOutcome> showSavedPoolNamingDialog({
  required BuildContext context,
  required SavedPoolRepository repository,
  List<SourceReference> orderedSourceReferences = const [],
  String? excludePoolId,
  String? initialDisplayName,
  String? renamePoolId,
}) async {
  final outcome = await showDialog<SavedPoolNamingOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _SavedPoolNamingDialog(
        repository: repository,
        orderedSourceReferences: orderedSourceReferences,
        excludePoolId: excludePoolId ?? renamePoolId,
        initialDisplayName: initialDisplayName,
        renamePoolId: renamePoolId,
      );
    },
  );
  return outcome ?? const SavedPoolNamingCancelled();
}

Future<bool> showSavedPoolDeleteConfirmDialog({
  required BuildContext context,
  required String displayName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final tokens = Theme.of(context).extension<WakeTokTokens>()!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('mainBrowseSavedPoolDeleteDialog'),
        backgroundColor: tokens.surface,
        title: Text(
          l10n.mainBrowseSavedPoolDeleteTitle,
          style: tokens.labelOnMedia.copyWith(color: tokens.onMedia),
        ),
        content: Text(
          l10n.mainBrowseSavedPoolDeleteBody(displayName),
          style: tokens.bodyOnMedia.copyWith(color: tokens.onMediaMuted),
        ),
        actions: [
          TextButton(
            key: const Key('mainBrowseSavedPoolDeleteCancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.mainBrowseSavedPoolDeleteCancel,
              style: tokens.labelOnMedia.copyWith(color: tokens.onMediaMuted),
            ),
          ),
          TextButton(
            key: const Key('mainBrowseSavedPoolDeleteConfirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.mainBrowseSavedPoolDeleteConfirm,
              style: tokens.labelOnMedia.copyWith(color: tokens.accent),
            ),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

Future<void> showSavedPoolCapacityDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final tokens = Theme.of(context).extension<WakeTokTokens>()!;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('mainBrowseSavedPoolCapacityDialog'),
        backgroundColor: tokens.surface,
        title: Text(
          l10n.mainBrowseSavedPoolCapacityTitle,
          style: tokens.labelOnMedia.copyWith(color: tokens.onMedia),
        ),
        content: Text(
          l10n.mainBrowseSavedPoolCapacityBody,
          style: tokens.bodyOnMedia.copyWith(color: tokens.onMediaMuted),
        ),
        actions: [
          TextButton(
            key: const Key('mainBrowseSavedPoolCapacityConfirm'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              l10n.mainBrowseSavedPoolCapacityConfirm,
              style: tokens.labelOnMedia.copyWith(color: tokens.accent),
            ),
          ),
        ],
      );
    },
  );
}

class _SavedPoolNamingDialog extends StatefulWidget {
  const _SavedPoolNamingDialog({
    required this.repository,
    required this.orderedSourceReferences,
    this.excludePoolId,
    this.initialDisplayName,
    this.renamePoolId,
  });

  final SavedPoolRepository repository;
  final List<SourceReference> orderedSourceReferences;
  final String? excludePoolId;
  final String? initialDisplayName;
  final String? renamePoolId;

  @override
  State<_SavedPoolNamingDialog> createState() => _SavedPoolNamingDialogState();
}

class _SavedPoolNamingDialogState extends State<_SavedPoolNamingDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDisplayName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_submitting) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final trimmed = normalizeSavedPoolDisplayName(_controller.text);
    if (trimmed == null) {
      setState(() => _error = l10n.mainBrowseSavedPoolNamingEmpty);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final existing = await widget.repository.loadAll();
      final renaming = widget.renamePoolId != null;
      if (!renaming && existing.length >= PoolCapacity.maxSavedPoolPresets) {
        if (mounted) {
          Navigator.of(context).pop(const SavedPoolNamingAtCapacity());
        }
        return;
      }
      if (savedPoolDisplayNameTaken(
        trimmedName: trimmed,
        existing: existing,
        excludeId: widget.excludePoolId,
      )) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = l10n.mainBrowseSavedPoolNamingDuplicate;
          });
        }
        return;
      }
      final record = renaming
          ? await widget.repository.rename(
              id: widget.renamePoolId!,
              displayName: trimmed,
            )
          : await widget.repository.save(
              displayName: trimmed,
              orderedSourceReferences: widget.orderedSourceReferences,
            );
      if (mounted) {
        Navigator.of(context).pop(SavedPoolNamingSaved(record));
      }
    } on SavedPoolDuplicateName {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = l10n.mainBrowseSavedPoolNamingDuplicate;
        });
      }
    } on SavedPoolCapacityExceeded {
      if (mounted) {
        Navigator.of(context).pop(const SavedPoolNamingAtCapacity());
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return AlertDialog(
      key: const Key('mainBrowseSavedPoolNamingDialog'),
      backgroundColor: tokens.surface,
      title: Text(
        l10n.mainBrowseSavedPoolNamingTitle,
        style: tokens.labelOnMedia.copyWith(color: tokens.onMedia),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('mainBrowseSavedPoolNamingField'),
            controller: _controller,
            enabled: !_submitting,
            autofocus: true,
            style: tokens.bodyOnMedia.copyWith(color: tokens.onMedia),
            cursorColor: tokens.accent,
            decoration: InputDecoration(
              hintText: l10n.mainBrowseSavedPoolNamingHint,
              hintStyle: tokens.bodyOnMedia.copyWith(
                color: tokens.onMediaMuted,
              ),
              errorText: _error,
              errorStyle: tokens.bodyOnMedia.copyWith(color: tokens.accent),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tokens.onMediaMuted),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tokens.accent),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('mainBrowseSavedPoolNamingCancel'),
          onPressed: _submitting
              ? null
              : () =>
                    Navigator.of(context).pop(const SavedPoolNamingCancelled()),
          child: Text(
            l10n.mainBrowseSavedPoolNamingCancel,
            style: tokens.labelOnMedia.copyWith(color: tokens.onMediaMuted),
          ),
        ),
        TextButton(
          key: const Key('mainBrowseSavedPoolNamingConfirm'),
          onPressed: _submitting ? null : _confirm,
          child: Text(
            l10n.mainBrowseSavedPoolNamingConfirm,
            style: tokens.labelOnMedia.copyWith(color: tokens.accent),
          ),
        ),
      ],
    );
  }
}
