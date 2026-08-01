import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/main.dart';

class _FakePhotosAuthorizationRepository
    implements PhotosAuthorizationRepository {
  @override
  Future<PhotosAccess> currentStatus() async => PhotosAccess.denied;

  @override
  Future<PhotosAccess> requestAccess() async => PhotosAccess.denied;

  @override
  Future<void> presentLimitedLibraryPicker() async {}
}

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      photosAuthorizationRepositoryProvider.overrideWithValue(
        _FakePhotosAuthorizationRepository(),
      ),
    ],
    child: child,
  );
}

void main() {
  testWidgets('WakeTokApp smoke home shows l10n string', (tester) async {
    await tester.pumpWidget(_harness(const WakeTokApp()));
    await tester.pumpAndSettle();
    expect(find.byType(L10nSmokePage), findsOneWidget);
    expect(find.text('Localization OK'), findsWidgets);
    expect(find.textContaining('DEBUG ONLY'), findsOneWidget);
    expect(find.textContaining('denied'), findsOneWidget);
  });
}
