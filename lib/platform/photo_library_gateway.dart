import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';

/// Maps Pigeon [AuthStatus] → domain [PhotosAccess].
PhotosAccess photosAccessFromAuthStatus(AuthStatus status) {
  switch (status) {
    case AuthStatus.notDetermined:
      return PhotosAccess.notDetermined;
    case AuthStatus.authorized:
      return PhotosAccess.full;
    case AuthStatus.limited:
      return PhotosAccess.limited;
    case AuthStatus.denied:
      return PhotosAccess.denied;
    case AuthStatus.restricted:
      return PhotosAccess.restricted;
  }
}

/// Pigeon [PhotoLibraryApi] adapter for authorization (ADR-009 platform layer).
class PhotoLibraryGateway implements PhotosAuthorizationRepository {
  PhotoLibraryGateway({PhotoLibraryApi? api})
      : _api = api ?? PhotoLibraryApi();

  final PhotoLibraryApi _api;

  @override
  Future<PhotosAccess> currentStatus() async {
    final status = await _api.authorizationStatus();
    return photosAccessFromAuthStatus(status);
  }

  @override
  Future<PhotosAccess> requestAccess() async {
    final status = await _api.requestAuthorization();
    return photosAccessFromAuthStatus(status);
  }

  @override
  Future<void> presentLimitedLibraryPicker() {
    return _api.presentLimitedLibraryPicker();
  }
}
