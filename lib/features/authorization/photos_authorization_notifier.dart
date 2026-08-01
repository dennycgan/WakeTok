import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';

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

  @override
  Future<PhotosAccess> build() => _repo.currentStatus();

  Future<void> requestAccess() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.requestAccess);
  }

  Future<void> presentLimitedLibraryPicker() async {
    await _repo.presentLimitedLibraryPicker();
    state = await AsyncValue.guard(_repo.currentStatus);
  }
}
