import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/cap19_left_swipe_providers.dart';
import 'package:waketok/app/waketok_album_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/bootstrap_waketok_album.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/album_mutation_providers.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

enum Cap19LeftSwipeAppendOutcome {
  success,
  alreadyInAlbum,
  mediaNotReady,
  failed,
  /// Cap 23: probe reported Photos missing — gesture shows shared dialog.
  notInLibrary,
  /// Cap 23: gate busy / stale — silent ignore (no toast).
  ignored,
}

class Cap19LeftSwipeAppendState {
  const Cap19LeftSwipeAppendState({
    this.appending = false,
    this.leftSwipeAddEnabled = true,
  });

  final bool appending;
  final bool leftSwipeAddEnabled;

  Cap19LeftSwipeAppendState copyWith({
    bool? appending,
    bool? leftSwipeAddEnabled,
  }) {
    return Cap19LeftSwipeAppendState(
      appending: appending ?? this.appending,
      leftSwipeAddEnabled: leftSwipeAddEnabled ?? this.leftSwipeAddEnabled,
    );
  }
}

final cap19LeftSwipeAppendProvider =
    NotifierProvider<Cap19LeftSwipeAppendNotifier, Cap19LeftSwipeAppendState>(
      Cap19LeftSwipeAppendNotifier.new,
    );

/// Whether the current feed page may arm the left-swipe recognizer.
final cap19LeftSwipeArmingProvider = Provider<bool>((ref) {
  final appendState = ref.watch(cap19LeftSwipeAppendProvider);
  // Prefer [browseStillMagnifiedProvider] so test harness
  // `forceStillMagnified` override still applies (W-19.6-9).
  final magnified = ref.watch(browseStillMagnifiedProvider);
  final mag = ref.watch(browseMagnificationProvider);
  final panelOpen = ref.watch(cap19ActionsPanelOpenProvider);
  final actionable = ref.watch(mainBrowseCurrentAssetActionableProvider);
  return leftSwipeArmingAllowed(
    leftSwipeAddEnabled: appendState.leftSwipeAddEnabled,
    isCurrentStillMagnified: magnified,
    transientPinchActive: mag.transientPinchActive,
    stillPinchContact: mag.stillPinchContact,
    cap19PanelOpen: panelOpen,
    currentAssetActionable: actionable,
  );
});

class Cap19LeftSwipeAppendNotifier extends Notifier<Cap19LeftSwipeAppendState> {
  @override
  Cap19LeftSwipeAppendState build() {
    ref.listen(cap19LeftSwipePrefsRevisionProvider, (_, __) {
      Future.microtask(reloadPreferences);
    });
    Future.microtask(reloadPreferences);
    return const Cap19LeftSwipeAppendState();
  }

  Future<void> reloadPreferences() async {
    final enabled = await ref
        .read(cap19LeftSwipePreferencesProvider)
        .isLeftSwipeAddEnabled();
    state = state.copyWith(leftSwipeAddEnabled: enabled);
  }

  /// Appends current asset, or reports already-in-album (Cap 19.7 B1).
  Future<Cap19LeftSwipeAppendOutcome> appendCurrentAssetToWakeTokAlbum() async {
    if (!state.leftSwipeAddEnabled || state.appending) {
      return Cap19LeftSwipeAppendOutcome.failed;
    }
    final stillGate = ref.read(
      mainBrowseCurrentAssetStillInLibraryProvider.notifier,
    );
    if (stillGate.isBusy) {
      return Cap19LeftSwipeAppendOutcome.ignored;
    }
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      return Cap19LeftSwipeAppendOutcome.mediaNotReady;
    }
    final stillIn = await stillGate.probeCurrentAssetStillInLibrary();
    if (!stillIn) {
      if (ref.read(mainBrowseCurrentAssetStillInLibraryProvider).status ==
          StillInLibraryStatus.missing) {
        // Arm shared latch before returning so entry cannot re-enter while
        // the gesture awaits showDialog (ADR-049 D6).
        stillGate.setDialogVisible(true);
        return Cap19LeftSwipeAppendOutcome.notInLibrary;
      }
      return Cap19LeftSwipeAppendOutcome.ignored;
    }
    final access = ref.read(photosAuthorizationProvider).value;
    if (access == null) {
      return Cap19LeftSwipeAppendOutcome.failed;
    }
    if (access != PhotosAccess.full && access != PhotosAccess.limited) {
      return Cap19LeftSwipeAppendOutcome.failed;
    }
    final resolvedAccess = access;
    state = state.copyWith(appending: true);
    try {
      final mutations = ref.read(albumMutationRepositoryProvider);
      final bootstrap = await bootstrapWakeTokAlbum(
        access: resolvedAccess,
        store: ref.read(wakeTokAlbumStoreProvider),
        assetSources: ref.read(assetSourceRepositoryProvider),
        albumMutations: mutations,
      );
      final already = await mutations.albumContainsAsset(
        bootstrap.albumId,
        assetId,
      );
      if (already) {
        return Cap19LeftSwipeAppendOutcome.alreadyInAlbum;
      }
      await mutations.addAssetToAlbum(assetId, bootstrap.albumId);
      return Cap19LeftSwipeAppendOutcome.success;
    } on PlatformException {
      return Cap19LeftSwipeAppendOutcome.failed;
    } catch (_) {
      return Cap19LeftSwipeAppendOutcome.failed;
    } finally {
      state = state.copyWith(appending: false);
    }
  }
}
