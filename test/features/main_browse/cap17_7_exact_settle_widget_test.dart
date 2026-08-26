import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Cap 17.7 exact settle: Host-complete-only (no timeout fallback lock).
void main() {
  testWidgets(
    'W-17.7-exact slow EXIF stays blank then shows wall — not Auckland fallback',
    (tester) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Epoch path would show 10:10; Photos/EXIF wall is 00:10.
      final created = DateTime(2019, 12, 27, 10, 10);
      const wall = CaptureWallClock(
        year: 2019,
        month: 12,
        day: 27,
        hour: 0,
        minute: 10,
      );
      final exactWall = formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: true,
        captureWallClock: wall,
        createdAt: created,
      );
      final exactFallback = formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: true,
        createdAt: created,
      );
      expect(exactWall, isNot(exactFallback));

      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'tr1': PresentationMetadata(
            assetIdentifier: 'tr1',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
        },
        wallClockById: {'tr1': wall},
        // Longer than the old 150ms timeout race — must still accept EXIF.
        wallClockDelay: const Duration(milliseconds: 400),
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['tr1']),
          mediaDisplay: display,
          presentationMetadata: presentation,
        ),
      );

      var sawWall = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        // Never paint Auckland fallback while waiting / after.
        expect(find.text(exactFallback), findsNothing);
        if (find.text(exactWall).evaluate().isNotEmpty) {
          sawWall = true;
          break;
        }
      }
      expect(sawWall, isTrue, reason: 'slow EXIF must still land as wall clock');
      expect(presentation.wallClockCalls, greaterThanOrEqualTo(1));
    },
  );
}
