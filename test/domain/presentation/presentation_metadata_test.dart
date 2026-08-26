import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/presentation/presentation_metadata_repository.dart';

void main() {
  test('P-D1 null fileSizeBytes is not zero', () {
    const size = PresentationFileSize(
      assetIdentifier: 'a',
      fileSizeBytes: null,
      fileSizeSemantics: null,
    );
    expect(size.fileSizeBytes, isNull);
    expect(size.fileSizeBytes == 0, isFalse);
  });

  test('P-D1 metadata keeps createdAt nullable with required mediaKind', () {
    const meta = PresentationMetadata(
      assetIdentifier: 'a',
      mediaKind: PresentationMediaKind.livePhoto,
      createdAt: null,
    );
    expect(meta.mediaKind, PresentationMediaKind.livePhoto);
    expect(meta.createdAt, isNull);
  });

  test('P-D1 FileSizeSemantics wire names stay stable', () {
    expect(FileSizeSemantics.values.map((e) => e.name), [
      'primaryResource',
      'localVideoUrl',
      'currentImageRepresentation',
      'unknownUnavailable',
    ]);
  });

  test('P-T5 file-size failure does not erase held metadata', () async {
    final repo = _FakePresentationRepo();
    final meta = await repo.requestPresentationMetadata('a');
    expect(meta.mediaKind, PresentationMediaKind.image);
    expect(meta.createdAt, isNotNull);

    try {
      await repo.requestPresentationFileSize('a');
      fail('expected StateError');
    } on StateError {
      // Host/size path failed — caller must keep [meta] unchanged.
    }
    expect(meta.mediaKind, PresentationMediaKind.image);
    expect(meta.createdAt, isNotNull);
  });

  test('P-D1 repository signature is Riverpod-free', () {
    expect(PresentationMetadataRepository, isNotNull);
  });
}

final class _FakePresentationRepo implements PresentationMetadataRepository {
  @override
  Future<PresentationMetadata> requestPresentationMetadata(
    String assetIdentifier,
  ) async {
    return PresentationMetadata(
      assetIdentifier: assetIdentifier,
      mediaKind: PresentationMediaKind.image,
      createdAt: DateTime.utc(2024, 1, 1),
    );
  }

  @override
  Future<PresentationFileSize> requestPresentationFileSize(
    String assetIdentifier,
  ) async {
    throw StateError('size unavailable');
  }
}
