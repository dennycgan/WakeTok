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
import 'package:waketok/features/main_browse/cap19_still_magnification_stub.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

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
  final magnified = ref.watch(cap19StillMagnificationStubProvider);
  final panelOpen = ref.watch(cap19ActionsPanelOpenProvider);
  return leftSwipeArmingAllowed(
    leftSwipeAddEnabled: appendState.leftSwipeAddEnabled,
    isCurrentStillMagnified: magnified,
    cap19PanelOpen: panelOpen,
  );
});

class Cap19LeftSwipeAppendNotifier extends Notifier<Cap19LeftSwipeAppendState> {
  @override
  Cap19LeftSwipeAppendState build() {
    Future.microtask(_loadPreference);
    return const Cap19LeftSwipeAppendState();
  }

  Future<void> _loadPreference() async {
    final enabled = await ref
        .read(cap19LeftSwipePreferencesProvider)
        .isLeftSwipeAddEnabled();
    state = state.copyWith(leftSwipeAddEnabled: enabled);
  }

  /// Returns `true` when append succeeds. Does not touch Session/Snapshot.
  Future<bool> appendCurrentAssetToWakeTokAlbum() async {
    if (!state.leftSwipeAddEnabled || state.appending) {
      return false;
    }
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      return false;
    }
    final access = ref.read(photosAuthorizationProvider).value;
    if (access == null) {
      return false;
    }
    if (access != PhotosAccess.full && access != PhotosAccess.limited) {
      return false;
    }
    final resolvedAccess = access;
    state = state.copyWith(appending: true);
    try {
      final bootstrap = await bootstrapWakeTokAlbum(
        access: resolvedAccess,
        store: ref.read(wakeTokAlbumStoreProvider),
        assetSources: ref.read(assetSourceRepositoryProvider),
        albumMutations: ref.read(albumMutationRepositoryProvider),
      );
      await ref.read(albumMutationRepositoryProvider).addAssetToAlbum(
            assetId,
            bootstrap.albumId,
          );
      return true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(appending: false);
    }
  }
}
