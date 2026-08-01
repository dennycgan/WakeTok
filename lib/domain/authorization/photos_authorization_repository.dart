import 'package:waketok/domain/authorization/photos_access.dart';

/// Domain port for Photos library authorization (ADR-009 / Cap 5.2).
///
/// Implementations live under `lib/platform/`. Signatures use only
/// [Future] / [Stream] — no Riverpod types (ADR-010).
abstract class PhotosAuthorizationRepository {
  Future<PhotosAccess> currentStatus();

  Future<PhotosAccess> requestAccess();

  Future<void> presentLimitedLibraryPicker();
}
