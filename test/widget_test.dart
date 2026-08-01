import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/photos_access_gate.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/main.dart';

import 'features/authorization/permission_ui_test_harness.dart';

void main() {
  testWidgets('WakeTokApp opens PhotosAccessGate', (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photosAuthorizationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const WakeTokApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PhotosAccessGate), findsOneWidget);
  });
}
