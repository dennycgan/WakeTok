import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';
import 'package:waketok/platform/photo_library_gateway.dart';

void main() {
  test('D1 AuthStatus maps to PhotosAccess (authorized → full)', () {
    expect(
      photosAccessFromAuthStatus(AuthStatus.notDetermined),
      PhotosAccess.notDetermined,
    );
    expect(
      photosAccessFromAuthStatus(AuthStatus.authorized),
      PhotosAccess.full,
    );
    expect(
      photosAccessFromAuthStatus(AuthStatus.limited),
      PhotosAccess.limited,
    );
    expect(
      photosAccessFromAuthStatus(AuthStatus.denied),
      PhotosAccess.denied,
    );
    expect(
      photosAccessFromAuthStatus(AuthStatus.restricted),
      PhotosAccess.restricted,
    );
  });

  test('D2 mapping covers every AuthStatus', () {
    for (final status in AuthStatus.values) {
      expect(photosAccessFromAuthStatus(status), isA<PhotosAccess>());
    }
  });
}
