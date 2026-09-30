import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

const _meta = Key('mediaInfoOverlay');

Future<List<String>> _pumpTwoStills(WidgetTester tester) async {
  final display = FakeMediaDisplayRepository();
  seedDecodableStillPaths(display, const ['a1', 'a2']);
  await tester.pumpWidget(
    permissionUiHarness(
      disableBrowseAllPrefetch: true,
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: FakeAssetSourceRepository(
        allIds: const ['a1', 'a2'],
        availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const [
          'a1',
          'a2',
        ]),
      ),
      mediaDisplay: display,
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(VerticalMediaFeed)),
  );
  return (await container.read(browseSessionProvider.future)).orderedAssetIds;
}

void main() {
  testWidgets(
    'W-31.3b-3 Meta hides during peek and returns after a bounce-back',
    (tester) async {
      final ids = await _pumpTwoStills(tester);
      await pumpUntilStillCoverReadyForAsset(tester, ids[0]);
      expect(find.byKey(_meta), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();
      expect(find.byKey(_meta), findsNothing);

      await gesture.moveBy(const Offset(0, 80));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(mediaFeedPageState(tester, ids[0]).widget.isCurrent, isTrue);
      expect(find.byKey(_meta), findsOneWidget);
    },
  );

  testWidgets(
    'W-31.3b-4 Meta stays hidden past the page-change threshold until the '
    'feed lands',
    (tester) async {
      final ids = await _pumpTwoStills(tester);
      await pumpUntilStillCoverReadyForAsset(tester, ids[0]);
      // Neighbour cover ready too, so only the settled gate can hide its Meta.
      await pumpUntilStillCoverReadyForAsset(tester, ids[1]);
      expect(find.byKey(_meta), findsOneWidget);

      final height = tester.getSize(find.byType(PageView)).height;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(Offset(0, -height * 0.1));
        await tester.pump();
      }
      expect(mediaFeedPageState(tester, ids[1]).widget.isCurrent, isTrue);
      expect(find.byKey(_meta), findsNothing);

      await gesture.up();
      await tester.pumpAndSettle();
      await pumpUntilStillCoverReadyForAsset(tester, ids[1]);
      expect(find.byKey(_meta), findsOneWidget);
    },
  );
}
