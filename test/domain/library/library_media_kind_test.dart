import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/library_media_kind.dart';

void main() {
  test('U1 Live Photo and image count as photos; video separate', () {
    expect(LibraryMediaKind.image.countsAsPhoto, isTrue);
    expect(LibraryMediaKind.livePhoto.countsAsPhoto, isTrue);
    expect(LibraryMediaKind.video.countsAsPhoto, isFalse);
    expect(LibraryMediaKind.unknown.countsAsPhoto, isFalse);

    expect(LibraryMediaKind.video.countsAsVideo, isTrue);
    expect(LibraryMediaKind.image.countsAsVideo, isFalse);
    expect(LibraryMediaKind.livePhoto.countsAsVideo, isFalse);
  });
}
