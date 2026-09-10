import 'package:waketok/domain/library/album_mutation_repository.dart';

/// Composition-root wrapper (ADR-048 / ADR-010): after a successful album
/// **membership** write, notify so Browse Snapshot cache entries for that
/// album can be dropped. Feature code keeps calling [AlbumMutationRepository]
/// only — no per-call-site cache clears.
class SnapshotInvalidatingAlbumMutationRepository
    implements AlbumMutationRepository {
  SnapshotInvalidatingAlbumMutationRepository({
    required AlbumMutationRepository inner,
    required void Function(String albumIdentifier) onMembershipChanged,
  })  : _inner = inner,
        _onMembershipChanged = onMembershipChanged;

  final AlbumMutationRepository _inner;
  final void Function(String albumIdentifier) _onMembershipChanged;

  @override
  Future<String> createAlbum(String name) => _inner.createAlbum(name);

  @override
  Future<bool> albumContainsAsset(
    String albumIdentifier,
    String assetIdentifier,
  ) =>
      _inner.albumContainsAsset(albumIdentifier, assetIdentifier);

  @override
  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  ) async {
    await _inner.addAssetToAlbum(assetIdentifier, albumIdentifier);
    _onMembershipChanged(albumIdentifier);
  }
}
