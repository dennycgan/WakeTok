import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/features/library_smoke/asset_soft_delete_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/still_in_library_gate.dart';

/// Cap 24 soft-delete Host outcome (system consent is the only confirm UI).
enum Cap24SoftDeleteOutcome {
  /// Cap 23 gate denied, missing id, or widget unmounted mid-flight.
  dismissed,

  /// Host soft-delete succeeded.
  success,

  /// Host returned `operationCancelled` (system confirm cancel) — no failure toast.
  operationCancelled,

  /// Host / probe failure that should show failure toast (Cap 23 may already
  /// have shown its unavailable dialog).
  failed,
}

/// Cap 23 still-in-library gate, then Host soft-delete. No App AlertDialog.
///
/// [onHostStarting] fires after the gate passes and before the Host await so
/// the half-sheet can show busy only for the system-consent / Host window
/// (not during the Cap 23 dialog, which would keep a spinner animating).
Future<Cap24SoftDeleteOutcome> runCap24SoftDelete({
  required BuildContext context,
  required WidgetRef ref,
  VoidCallback? onHostStarting,
}) async {
  final allowed = await ensureCurrentAssetStillInLibraryForMutation(
    ref: ref,
    context: context,
  );
  if (!context.mounted) {
    return Cap24SoftDeleteOutcome.dismissed;
  }
  if (!allowed) {
    return Cap24SoftDeleteOutcome.dismissed;
  }

  final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
  if (assetId == null || assetId.isEmpty) {
    return Cap24SoftDeleteOutcome.dismissed;
  }

  onHostStarting?.call();

  try {
    await ref.read(assetSoftDeleteRepositoryProvider).softDeleteAsset(assetId);
    return Cap24SoftDeleteOutcome.success;
  } on PlatformException catch (e) {
    if (e.code == AppError.operationCancelled.name) {
      return Cap24SoftDeleteOutcome.operationCancelled;
    }
    return Cap24SoftDeleteOutcome.failed;
  } on Object {
    return Cap24SoftDeleteOutcome.failed;
  }
}
