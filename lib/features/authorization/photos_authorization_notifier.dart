import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';

/// Overridden at the composition root with [PhotoLibraryGateway].
///
/// Features must not construct platform gateways (ADR-010).
final photosAuthorizationRepositoryProvider =
    Provider<PhotosAuthorizationRepository>((ref) {
      throw StateError(
        'photosAuthorizationRepositoryProvider must be overridden at '
        'the composition root (lib/main.dart / lib/app)',
      );
    });

final photosAuthorizationProvider =
    AsyncNotifierProvider<PhotosAuthorizationNotifier, PhotosAccess>(
      PhotosAuthorizationNotifier.new,
    );

class PhotosAuthorizationNotifier extends AsyncNotifier<PhotosAccess> {
  PhotosAuthorizationRepository get _repo =>
      ref.read(photosAuthorizationRepositoryProvider);

  /// True while [requestAccess] is awaiting the system dialog / Limited picker.
  ///
  /// Kafka 14.6: a resume-time [photosAuthorizationProvider] invalidate reads
  /// `.limited` via [currentStatus] and paints Main Browse before
  /// `requestAuthorization` completes. Empty All retries then burn under the
  /// picker. [PhotosAccessGate] skips that invalidate while this is true.
  bool _requestAccessInFlight = false;

  bool get isRequestAccessInFlight => _requestAccessInFlight;

  @override
  Future<PhotosAccess> build() => _repo.currentStatus();

  Future<void> requestAccess() async {
    _requestAccessInFlight = true;
    state = const AsyncLoading();
    try {
      state = await AsyncValue.guard(_repo.requestAccess);
      final access = state.value;
      if (access == PhotosAccess.limited || access == PhotosAccess.full) {
        // Picker may already have painted an empty All (resume path). Reload
        // after the grant completes so PhotoKit's Limited selection is used.
        unawaited(ref.read(browseSessionProvider.notifier).restartSession());
      }
    } finally {
      _requestAccessInFlight = false;
    }
  }

  /// Presents the limited-library picker and refreshes auth + catalog totals
  /// after the host reports dismissal (not at present-time).
  Future<void> presentLimitedLibraryPicker() async {
    await _repo.presentLimitedLibraryPicker();
    state = await AsyncValue.guard(_repo.currentStatus);
    ref.invalidate(libraryTotalsProvider);
  }
}
