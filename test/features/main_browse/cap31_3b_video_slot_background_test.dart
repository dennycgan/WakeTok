import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

void main() {
  testWidgets('W-31.3b-2 video slot paints no background over the poster', (
    tester,
  ) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    final display = FakeMediaDisplayRepository();
    display.displayErrorById['v1'] = 'unsupportedMedia';
    await tester.pumpWidget(
      permissionUiHarness(
        disableBrowseAllPrefetch: true,
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['v1']),
        mediaDisplay: display,
        playback: FakePlaybackRepository(),
      ),
    );
    await tester.pumpAndSettle();

    final slot = find.byKey(const Key('mainBrowseFeedVideo_v1'));
    expect(slot, findsOneWidget);
    expect(tester.widget(slot), isNot(isA<ColoredBox>()));
    expect(
      find.descendant(of: slot, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: slot,
        matching: find.byKey(const Key('feedVideoOpacity_v1')),
      ),
      findsOneWidget,
    );
  });
}
