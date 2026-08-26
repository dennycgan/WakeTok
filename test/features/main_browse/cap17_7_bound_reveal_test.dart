import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Cap 17.7 bound reveal: rows 1–2 share [exactDateResolved]; row 3 independent.
void main() {
  final now = DateTime(2024, 6, 10, 15, 0);
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Widget harness(PresentationOverlaySnapshot? snap) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.dark),
      home: Scaffold(
        body: MediaInfoOverlay(snapshot: snap, now: now),
      ),
    );
  }

  testWidgets(
    'T1 basics only: rows 1–2 blank; row 3 size may show (independent)',
    (tester) async {
      final created = DateTime(2024, 6, 8, 12);
      await tester.pumpWidget(
        harness(
          PresentationOverlaySnapshot(
            assetIdentifier: 'a',
            createdAt: created,
            mediaKind: PresentationMediaKind.image,
            fileSizeBytes: 2_048,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
            exactDateResolved: false,
          ),
        ),
      );
      expect(find.text(l10n.mediaInfoRelativeDaysAgo('2')), findsNothing);
      expect(
        find.text(
          formatOverlayExactDateTime(
            l10n: l10n,
            exactDateResolved: true,
            createdAt: created,
          ),
        ),
        findsNothing,
      );
      expect(find.text(l10n.mediaInfoFileSizeKb('2')), findsOneWidget);
    },
  );

  testWidgets(
    'T2 merge wall: rows 1–2 appear together in one build',
    (tester) async {
      final created = DateTime(2024, 6, 8, 12);
      const wall = CaptureWallClock(
        year: 2024,
        month: 6,
        day: 8,
        hour: 9,
        minute: 30,
      );
      final pending = PresentationOverlaySnapshot(
        assetIdentifier: 'a',
        createdAt: created,
        mediaKind: PresentationMediaKind.image,
        exactDateResolved: false,
      );
      await tester.pumpWidget(harness(pending));
      expect(find.text(l10n.mediaInfoRelativeDaysAgo('2')), findsNothing);

      final settled = pending.mergeCaptureWallClock(wallClock: wall);
      await tester.pumpWidget(harness(settled));
      expect(find.text(l10n.mediaInfoRelativeDaysAgo('2')), findsOneWidget);
      expect(
        find.text(
          formatOverlayExactDateTime(
            l10n: l10n,
            exactDateResolved: true,
            captureWallClock: wall,
            createdAt: created,
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('T3 Host nil fallback: rows 1–2 co-appear with epoch exact', (
    tester,
  ) async {
    final created = DateTime(2024, 6, 8, 12, 34);
    final pending = PresentationOverlaySnapshot(
      assetIdentifier: 'a',
      createdAt: created,
      mediaKind: PresentationMediaKind.image,
      exactDateResolved: false,
    );
    final settled = pending.mergeCaptureWallClock(wallClock: null);
    await tester.pumpWidget(harness(settled));
    expect(find.text(l10n.mediaInfoRelativeDaysAgo('2')), findsOneWidget);
    expect(
      find.text(
        formatOverlayExactDateTime(
          l10n: l10n,
          exactDateResolved: true,
          createdAt: created,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'T4 slow wall: never relative-before-exact; then both after settle',
    (tester) async {
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
      final relative = formatOverlayRelativeDate(
        l10n: l10n,
        exactDateResolved: true,
        createdAt: created,
        now: DateTime.now(),
      );

      final presentation = FakePresentationMetadataRepository(
        basicsById: {
          'tr1': PresentationMetadata(
            assetIdentifier: 'tr1',
            mediaKind: PresentationMediaKind.image,
            createdAt: created,
          ),
        },
        wallClockById: {'tr1': wall},
        wallClockDelay: const Duration(milliseconds: 400),
      );

      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(allIds: const ['tr1']),
          mediaDisplay: FakeMediaDisplayRepository(),
          presentationMetadata: presentation,
        ),
      );

      var sawPair = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final hasRelative =
            relative.isNotEmpty && find.text(relative).evaluate().isNotEmpty;
        final hasExact = find.text(exactWall).evaluate().isNotEmpty;
        // Bound reveal: relative must not appear without exact.
        if (hasRelative) {
          expect(hasExact, isTrue, reason: 'relative must not precede exact');
        }
        if (hasRelative && hasExact) {
          sawPair = true;
          break;
        }
      }
      expect(sawPair, isTrue);
    },
  );

  test('T5 computation unchanged: gate open/closed same relative string', () {
    final created = DateTime(2024, 6, 8, 12);
    final open = formatOverlayRelativeDate(
      l10n: l10n,
      exactDateResolved: true,
      createdAt: created,
      now: now,
    );
    expect(open, l10n.mediaInfoRelativeDaysAgo('2'));
    expect(
      formatOverlayRelativeDate(
        l10n: l10n,
        exactDateResolved: false,
        createdAt: created,
        now: now,
      ),
      '',
    );
    // Wall components must not affect relative math.
    expect(
      formatOverlayRelativeDate(
        l10n: l10n,
        exactDateResolved: true,
        createdAt: created,
        now: now,
      ),
      open,
    );
  });

  test('T6 no reveal Timer / Future.delayed in bound-reveal policy path', () {
    // Structural: policy library + formatters have no artificial wait.
    final policy = File(
      'lib/features/main_browse/capture_wall_clock_policy.dart',
    ).readAsStringSync();
    expect(policy.contains('Future.delayed'), isFalse);
    expect(policy.contains('Timer('), isFalse);
    expect(policy.contains('bound reveal'), isTrue);

    final formatSrc = File(
      'lib/features/main_browse/presentation_date_format.dart',
    ).readAsStringSync();
    expect(formatSrc.contains('Future.delayed'), isFalse);
    expect(formatSrc.contains('Timer('), isFalse);
  });
}
