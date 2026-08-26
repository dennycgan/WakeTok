import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/feed_activation_coordinator.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2024, 6, 10, 15, 0);

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

  testWidgets('W-O1 rows 1–3 keep height; row 4 collapses without location', (
    tester,
  ) async {
    await tester.pumpWidget(harness(null));
    final emptyH = tester
        .getSize(find.byKey(const Key('mediaInfoOverlay')))
        .height;

    await tester.pumpWidget(
      harness(
        PresentationOverlaySnapshot(
          assetIdentifier: 'a',
          createdAt: DateTime(2024, 6, 10, 12),
          mediaKind: PresentationMediaKind.image,
          fileSizeBytes: 2048,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      ),
    );
    final filledH = tester
        .getSize(find.byKey(const Key('mediaInfoOverlay')))
        .height;
    expect(emptyH, filledH);
    expect(emptyH, MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount);
    expect(find.byKey(const Key('mediaInfoOverlayRow4')), findsNothing);

    await tester.pumpWidget(
      harness(
        const PresentationOverlaySnapshot(
          assetIdentifier: 'a',
          mediaKind: PresentationMediaKind.image,
          locationLabel: 'Auckland',
        ),
      ),
    );
    final withLocH = tester
        .getSize(find.byKey(const Key('mediaInfoOverlay')))
        .height;
    expect(
      withLocH,
      MediaInfoOverlay.rowHeight * (MediaInfoOverlay.baseRowCount + 1),
    );
    expect(find.byKey(const Key('mediaInfoOverlayRow4')), findsOneWidget);
    expect(find.text('Auckland'), findsOneWidget);
  });

  testWidgets(
    'W-O-prog progressive basics then size keep Overlay height stable',
    (tester) async {
      await tester.pumpWidget(harness(null));
      final h0 = tester
          .getSize(find.byKey(const Key('mediaInfoOverlay')))
          .height;

      await tester.pumpWidget(
        harness(
          PresentationOverlaySnapshot(
            assetIdentifier: 'a',
            createdAt: DateTime(2024, 6, 10, 12),
            mediaKind: PresentationMediaKind.image,
          ),
        ),
      );
      final hBasics = tester
          .getSize(find.byKey(const Key('mediaInfoOverlay')))
          .height;
      expect(hBasics, h0);

      await tester.pumpWidget(
        harness(
          PresentationOverlaySnapshot(
            assetIdentifier: 'a',
            createdAt: DateTime(2024, 6, 10, 12),
            mediaKind: PresentationMediaKind.image,
            fileSizeBytes: 2_886_627,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        ),
      );
      final hSized = tester
          .getSize(find.byKey(const Key('mediaInfoOverlay')))
          .height;
      expect(hSized, h0);
      expect(h0, MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount);
      expect(find.byKey(const Key('mediaInfoOverlayRow4')), findsNothing);
    },
  );

  testWidgets('W-Loc1 whitespace-only locationLabel collapses row 4', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const PresentationOverlaySnapshot(
          assetIdentifier: 'a',
          mediaKind: PresentationMediaKind.image,
          locationLabel: '   ',
        ),
      ),
    );
    expect(find.byKey(const Key('mediaInfoOverlayRow4')), findsNothing);
  });

  testWidgets('W-O4 live photo copy joins size on row 3 when both present', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      harness(
        PresentationOverlaySnapshot(
          assetIdentifier: 'live',
          mediaKind: PresentationMediaKind.livePhoto,
          fileSizeBytes: 2_886_627,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      ),
    );
    expect(
      find.text(
        l10n.mediaInfoCharacteristicsJoined(
          l10n.mediaInfoLivePhoto,
          l10n.mediaInfoFileSizeMb('2.9'),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('W-O4b live photo alone when size unavailable', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      harness(
        const PresentationOverlaySnapshot(
          assetIdentifier: 'live',
          mediaKind: PresentationMediaKind.livePhoto,
        ),
      ),
    );
    expect(find.text(l10n.mediaInfoLivePhoto), findsOneWidget);
  });

  testWidgets('W-O5 null file size does not show zero', (tester) async {
    await tester.pumpWidget(
      harness(
        const PresentationOverlaySnapshot(
          assetIdentifier: 'a',
          mediaKind: PresentationMediaKind.image,
        ),
      ),
    );
    expect(find.textContaining('0 B'), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  test('W-O2 formatters: today; days within 30; years/months beyond', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      formatOverlayRelativeDate(
        l10n: l10n,
        createdAt: DateTime(2024, 6, 10, 8),
        now: now,
      ),
      l10n.mediaInfoRelativeToday,
    );
    expect(
      formatOverlayRelativeDate(
        l10n: l10n,
        createdAt: DateTime(2024, 5, 20),
        now: now,
      ),
      l10n.mediaInfoRelativeDaysAgo('21'),
    );
    expect(
      formatOverlayRelativeDate(
        l10n: l10n,
        createdAt: DateTime(2021, 6, 10),
        now: now,
      ),
      l10n.mediaInfoRelativeYearsAgo('3'),
    );
    expect(
      formatOverlayRelativeDate(
        l10n: l10n,
        createdAt: DateTime(2021, 3, 10),
        now: now,
      ),
      l10n.mediaInfoRelativeYearsMonthsAgo('3', '3'),
    );
    expect(
      formatOverlayFileSize(l10n: l10n, fileSizeBytes: 2_000),
      l10n.mediaInfoFileSizeKb('2'),
    );
    expect(
      formatOverlayFileSize(l10n: l10n, fileSizeBytes: 2_886_627),
      l10n.mediaInfoFileSizeMb('2.9'),
    );
    expect(
      formatOverlayFileSize(l10n: l10n, fileSizeBytes: 11_260_685),
      l10n.mediaInfoFileSizeMb('11.3'),
    );
    expect(formatOverlayFileSize(l10n: l10n, fileSizeBytes: null), '');
  });

  test('W-O3 coordinator begins metadata and display together', () {
    final c = FeedActivationCoordinator();
    final gens = c.beginCurrentItem();
    expect(gens.metadata, c.metadataGate.generation);
    expect(gens.display, c.currentDisplayGate.generation);
    expect(gens.metadata, gens.display);
    final next = c.beginCurrentItem();
    expect(next.metadata, gens.metadata + 1);
    expect(next.display, gens.display + 1);
  });

  test('W-O3-meta stale metadata generation is discarded', () async {
    final gate = FeedMediaRequestGate();
    final gen1 = gate.begin();
    final gen2 = gate.begin();
    expect(gate.isCurrent(gen1), isFalse);
    expect(gate.isCurrent(gen2), isTrue);
  });

  test('W-O6 snapshot merge keeps basics when size arrives', () {
    final basics =
        PresentationOverlaySnapshot(
          assetIdentifier: 'a',
          createdAt: DateTime.utc(2024, 1, 1),
          mediaKind: PresentationMediaKind.image,
        ).mergeBasics(
          PresentationMetadata(
            assetIdentifier: 'a',
            mediaKind: PresentationMediaKind.image,
            createdAt: DateTime.utc(2024, 1, 1),
          ),
        );
    final withSize = basics.mergeSize(
      const PresentationFileSize(
        assetIdentifier: 'a',
        fileSizeBytes: 100,
        fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
      ),
    );
    expect(withSize.createdAt, basics.createdAt);
    expect(withSize.mediaKind, PresentationMediaKind.image);
    expect(withSize.fileSizeBytes, 100);
  });

  test('S-6 mergeSize does not let nil clobber existing bytes', () {
    const withBytes = PresentationOverlaySnapshot(
      assetIdentifier: 'a',
      fileSizeBytes: 100,
      fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
    );
    final afterNil = withBytes.mergeSize(
      const PresentationFileSize(assetIdentifier: 'a'),
    );
    expect(afterNil.fileSizeBytes, 100);
    expect(
      afterNil.fileSizeSemantics,
      FileSizeSemantics.currentImageRepresentation,
    );
    final updated = withBytes.mergeSize(
      const PresentationFileSize(
        assetIdentifier: 'a',
        fileSizeBytes: 200,
        fileSizeSemantics: FileSizeSemantics.localVideoUrl,
      ),
    );
    expect(updated.fileSizeBytes, 200);
    expect(updated.fileSizeSemantics, FileSizeSemantics.localVideoUrl);
  });
}
