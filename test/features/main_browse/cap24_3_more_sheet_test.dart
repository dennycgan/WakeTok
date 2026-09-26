import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'still_cover_test_helpers.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';
import 'package:waketok/features/main_browse/anchored_info_bubble.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/presentation_size_cache.dart';
import 'package:waketok/features/main_browse/presentation_size_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_soft_delete_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_presentation_metadata_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

FakeAssetSourceRepository _localSources([String id = 'a1']) {
  return FakeAssetSourceRepository(
    allIds: [id],
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds([id]),
  );
}

Future<void> _openMoreSheet(WidgetTester tester) async {
  await ensureShellMediaCoverVisible(tester);
  await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
}

/// Scope finders to the half-sheet — cover-visible also paints Meta Overlay
/// with the same size / ~ minute strings.
Finder _inMoreSheet(Finder matching) {
  return find.descendant(
    of: find.byKey(const Key('cap24MoreHalfSheet')),
    matching: matching,
  );
}

void main() {
  tearDown(hideCap19BrowseToast);

  testWidgets(
    'W-24.3-1 ellipsis at index 0; Share@1; Cap 19 album at index 2',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: _localSources()),
      );
      await tester.pumpAndSettle();

      final tokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
      final lowest = mainBrowseActionColumnLowestBottomInset(tokens);
      final cap19Expected = actionColumnBottomInsetForIndex(2, lowest);

      final more = tester.getRect(find.byKey(const Key('cap24MoreEntryIcon')));
      final share =
          tester.getRect(find.byKey(const Key('cap25ShareEntryIcon')));
      final cap19 = tester.getRect(find.byKey(const Key('cap19EntryIcon')));

      expect(more.bottom, more.top + kActionColumnHitSize);
      // Higher on screen = smaller bottom dy: Album < Share < ….
      expect(cap19.bottom, lessThan(share.bottom));
      expect(share.bottom, lessThan(more.bottom));
      expect(cap19.top, lessThan(share.top));
      expect(share.top, lessThan(more.top));
      expect(
        (cap19Expected -
                lowest -
                2 * (kActionColumnHitSize + kActionColumnItemSpacing))
            .abs(),
        lessThan(0.01),
      );
      expect(find.byKey(const Key('cap24MoreEntryIcon')), findsOneWidget);
      expect(find.byKey(const Key('cap25ShareEntryIcon')), findsOneWidget);
      expect(find.byKey(const Key('cap19EntryIcon')), findsOneWidget);
    },
  );

  testWidgets(
    'W-26.4b-3 empty session: Cap 19 / Share / More share disabled opacity',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const []),
        ),
      );
      await tester.pumpAndSettle();

      Opacity opacityOf(Key key) => tester.widget<Opacity>(
        find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)),
      );

      final moreOpacity = opacityOf(const Key('cap24MoreEntryIcon'));
      final shareOpacity = opacityOf(const Key('cap25ShareEntryIcon'));
      final cap19Opacity = opacityOf(const Key('cap19EntryIcon'));
      expect(moreOpacity.opacity, kActionColumnEntryIconDisabledOpacity);
      expect(shareOpacity.opacity, kActionColumnEntryIconDisabledOpacity);
      expect(cap19Opacity.opacity, kActionColumnEntryIconDisabledOpacity);
      expect(moreOpacity.opacity, shareOpacity.opacity);
      expect(cap19Opacity.opacity, shareOpacity.opacity);
      expect(
        tester.widget<InkWell>(find.byKey(const Key('cap24MoreEntryIcon'))).onTap,
        isNull,
      );
    },
  );

  testWidgets(
    'W-24.3-2 empty session dims more icon like Cap 19 (opacity)',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const []),
        ),
      );
      await tester.pumpAndSettle();

      final moreOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('cap24MoreEntryIcon')),
          matching: find.byType(Opacity),
        ),
      );
      final cap19Opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('cap19EntryIcon')),
          matching: find.byType(Opacity),
        ),
      );
      expect(moreOpacity.opacity, kCap19EntryIconDisabledOpacity);
      expect(cap19Opacity.opacity, kCap19EntryIconDisabledOpacity);
      expect(
        tester.widget<InkWell>(find.byKey(const Key('cap24MoreEntryIcon'))).onTap,
        isNull,
      );
    },
  );

  testWidgets(
    'W-24.3-3 Cap 23 blocks more sheet open when unavailable',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      // Actionable path can still probe unavailable on tap if map flips —
      // use deviceLocal for chrome, then override availabilities mid-tap via
      // Controllable still-in-library: simplest path = start unavailable so
      // chrome dims and tap is null. For gate-before-open, need actionable
      // chrome with probe missing: seed local then mark unavailable for probe.
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById:
            FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      );
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      sources.availabilityById['a1'] = AssetAvailability.unavailable;

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stillInLibraryUnavailableDialog')),
          findsOneWidget);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-5 write-before Cap 23 fail: no softDelete; sheet remains',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById:
            FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: sources,
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      sources.availabilityById['a1'] = AssetAvailability.unavailable;

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 0);
      expect(find.byKey(const Key('stillInLibraryUnavailableDialog')),
          findsOneWidget);

      await tester.tap(
        find.byKey(const Key('stillInLibraryUnavailableDialogDismiss')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('cap24SoftDeleteSheetDelete')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'W-24.3-6 success: softDelete once; sheet gone; no success toast',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 1);
      expect(softDelete.lastAssetId, 'a1');
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-7 operationCancelled: no failure toast; sheet interactive again',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository()
        ..exception = PlatformException(
          code: AppError.operationCancelled.name,
        );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 1);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('cap24SoftDeleteSheetDelete')))
            .onPressed,
        isNotNull,
      );

      // Dismissibility restored after cancel.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-8 Host unknown: failure toast; sheet interactive again',
    (tester) async {
      final softDelete = FakeAssetSoftDeleteRepository()
        ..exception = PlatformException(code: AppError.unknown.name);
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsOneWidget);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('cap24SoftDeleteSheetDelete')))
            .onPressed,
        isNotNull,
      );
      hideCap19BrowseToast();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-9 Instant library minute row; note via i bubble (not persistent)',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            return Cap24MinuteLandmark(
              displayText: l10n.cap24SoftDeleteSheetExactMinuteLibrary(
                '2024',
                '06',
                '01',
                '12',
                '00',
              ),
              fromLibrary: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteLibrary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneInfo')),
        findsOneWidget,
      );
      // Not persisted as a second row.
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneInfo')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNoteBarrier')),
        findsOneWidget,
      );

      // Re-tap i: opaque barrier sits above the icon; tap that point to close.
      final infoCenter = tester.getCenter(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneInfo')),
      );
      await tester.tapAt(infoCenter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneInfo')),
      );
      await tester.pumpAndSettle();
      // Corner tap hits opaque barrier (not the bubble body, not modal barrier).
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsNothing,
      );
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      // Instant time row stays bare (no leading ~); note may cite Browse "~".
      final timeText = tester
          .widget<Text>(
            find.byKey(const Key('cap24SoftDeleteSheetMinuteLibrary')),
          )
          .data!;
      expect(timeText.contains('~'), isFalse);
    },
  );

  testWidgets(
    'W-24.3-10 busy latch: double Delete → softDelete once',
    (tester) async {
      final hold = Completer<void>();
      final softDelete = FakeAssetSoftDeleteRepository()..hold = hold;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pump();
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      // Second tap while busy must not fire another Host call.
      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pump();

      expect(softDelete.callCount, 1);
      hold.complete();
      await tester.pumpAndSettle();
      expect(softDelete.callCount, 1);
    },
  );

  testWidgets(
    'W-24.3-11 L2 never ready: more icon still tappable when actionable',
    (tester) async {
      // Default harness never mints L2-ready; device-local still is enough.
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: _localSources()),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreEntryIcon')), findsOneWidget);
      await _openMoreSheet(tester);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
    },
  );

  testWidgets(
    'W-24.3-12 one-paint: never shows library then bare',
    (tester) async {
      final gate = Completer<void>();
      final texts = <String>[];
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            await gate.future;
            return Cap24MinuteLandmark(
              displayText: l10n.cap24SoftDeleteSheetExactMinuteNoSeconds(
                '2020',
                '01',
                '02',
                '03',
                '04',
              ),
              fromLibrary: false,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pump();
      await tester.pump();

      // While loading: no minute keys yet.
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteLibrary')),
          findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteLibrary')),
          findsNothing);
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneInfo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsNothing,
      );

      // No tilde honesty mark on EXIF bare path (sheet only — Overlay may
      // show library ~ when cover is visible).
      for (final text in tester.widgetList<Text>(
        _inMoreSheet(find.byType(Text)),
      )) {
        final data = text.data;
        if (data != null && data.startsWith('~ ')) {
          texts.add(data);
        }
      }
      expect(texts, isEmpty);
    },
  );

  testWidgets(
    'W-24.3-13 dismiss sheet before landmark resolve: no late setState throw',
    (tester) async {
      final gate = Completer<void>();
      FlutterErrorDetails? caught;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        caught = details;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            await gate.future;
            return const Cap24MinuteLandmark(
              displayText: 'SHOULD_NOT_PAINT',
              fromLibrary: false,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pump();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      Navigator.of(tester.element(find.byKey(const Key('cap24MoreHalfSheet'))))
          .pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(caught, isNull);
      expect(find.text('SHOULD_NOT_PAINT'), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-15 Host in-flight: sheet stays + Delete busy; pop blocked',
    (tester) async {
      final hold = Completer<void>();
      final softDelete = FakeAssetSoftDeleteRepository()..hold = hold;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pump();

      expect(softDelete.callCount, 1);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')),
        findsOneWidget,
      );

      // Host in-flight: system back must not dismiss the sheet.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-16 omit Saved time block when loader returns null; File size stays',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: FakePresentationMetadataRepository(
            basicsById: {
              'a1': const PresentationMetadata(
                assetIdentifier: 'a1',
                mediaKind: PresentationMediaKind.image,
                createdAt: null,
              ),
            },
          ),
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreSheetSavedTimeTitle')), findsNothing);
      expect(find.byKey(const Key('cap24MoreSheetSavedTimeBlock')), findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteLibrary')),
          findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsNothing);
      expect(find.byKey(const Key('cap24MoreSheetFileSizeTitle')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteSheetDelete')), findsOneWidget);
    },
  );

  testWidgets(
    'W-24.3-17 latch: timezone info i is not tappable',
    (tester) async {
      final hold = Completer<void>();
      final softDelete = FakeAssetSoftDeleteRepository()..hold = hold;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            return Cap24MinuteLandmark(
              displayText: l10n.cap24SoftDeleteSheetExactMinuteLibrary(
                '2024',
                '06',
                '01',
                '12',
                '00',
              ),
              fromLibrary: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pump();

      final infoButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneInfo')),
          matching: find.byType(IconButton),
        ),
      );
      expect(infoButton.onPressed, isNull);
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsNothing,
      );

      hold.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'W-24.3-18 bubble dismiss never pops sheet when force-opened under latch',
    (tester) async {
      final hold = Completer<void>();
      final softDelete = FakeAssetSoftDeleteRepository()..hold = hold;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetSoftDelete: softDelete,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            return Cap24MinuteLandmark(
              displayText: l10n.cap24SoftDeleteSheetExactMinuteLibrary(
                '2024',
                '06',
                '01',
                '12',
                '00',
              ),
              fromLibrary: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pump();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetDeleteBusy')),
        findsOneWidget,
      );

      // Simulate latch-guard miss: force-open bubble while Host is in-flight.
      final sheetContext =
          tester.element(find.byKey(const Key('cap24MoreHalfSheet')));
      final l10n = AppLocalizations.of(sheetContext)!;
      final handle = showAnchoredInfoBubble(
        context: sheetContext,
        message: l10n.cap24SoftDeleteSheetMinuteTimezoneNote,
        anchorOverlayRect: const Rect.fromLTWH(280, 520, 44, 44),
        bubbleKey: const Key('cap24SoftDeleteSheetMinuteTimezoneNote'),
        barrierKey: const Key('cap24SoftDeleteSheetMinuteTimezoneNoteBarrier'),
      );
      // Busy spinner animates forever — do not pumpAndSettle.
      await tester.pump();
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsOneWidget,
      );

      handle.dismiss();
      await tester.pump();

      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsNothing,
      );
      // Last line of defense: dismiss is OverlayEntry.remove only.
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(softDelete.callCount, 1);

      hold.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'W-26.4-a File size title always; value formats like Overlay',
    (tester) async {
      final presentation = FakePresentationMetadataRepository(
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 2_886_627,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreSheetLocationSlot')), findsOneWidget);
      expect(find.byKey(const Key('cap24MoreSheetFileSizeTitle')), findsOneWidget);
      final sheetContext =
          tester.element(find.byKey(const Key('cap24MoreHalfSheet')));
      final l10n = AppLocalizations.of(sheetContext)!;
      expect(
        _inMoreSheet(find.text(l10n.cap24MoreSheetFileSizeTitle)),
        findsOneWidget,
      );
      expect(
        _inMoreSheet(
          find.text(
            formatOverlayFileSize(l10n: l10n, fileSizeBytes: 2_886_627),
          ),
        ),
        findsOneWidget,
      );
      expect(presentation.sizeCalls, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'W-26.4-b nil size keeps title; value is em dash; from shared entry',
    (tester) async {
      final presentation = FakePresentationMetadataRepository(
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: null,
            fileSizeSemantics: FileSizeSemantics.unknownUnavailable,
          ),
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
          .setReady(false);
      await tester.pump();
      container.read(presentationSizeCacheProvider.notifier).apply(
            'a1',
            const PresentationFileSize(
              assetIdentifier: 'a1',
              fileSizeBytes: null,
              fileSizeSemantics: FileSizeSemantics.unknownUnavailable,
            ),
          );
      final callsBeforeOpen = presentation.sizeCalls;

      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      final entry = container.read(presentationSizeCacheProvider)['a1'];
      expect(entry, isNotNull);
      expect(entry!.resolved, isTrue);
      expect(entry.fileSizeBytes, isNull);

      expect(find.byKey(const Key('cap24MoreSheetFileSizeTitle')), findsOneWidget);
      expect(find.byKey(const Key('cap24MoreSheetFileSizeBlock')), findsOneWidget);
      final sheetContext =
          tester.element(find.byKey(const Key('cap24MoreHalfSheet')));
      final l10n = AppLocalizations.of(sheetContext)!;
      expect(find.text(l10n.cap24MoreSheetUnavailableValue), findsOneWidget);
      expect(find.text('0 B'), findsNothing);
      expect(presentation.sizeCalls, callsBeforeOpen);
    },
  );

  testWidgets(
    'W-26.4-c in-flight blank while shared unresolved; no em dash; no spinner',
    (tester) async {
      final gate = Completer<void>();
      final presentation = FakePresentationMetadataRepository(
        sizeGate: gate,
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 2048,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      // Do not pumpAndSettle: sizeGate blocks feed Overlay size AND sheet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container.read(presentationSizeCacheProvider)['a1']?.resolved ?? false,
        isFalse,
      );
      expect(presentation.sizeCalls, greaterThanOrEqualTo(1));

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(
        container.read(presentationSizeCacheProvider)['a1']?.resolved ?? false,
        isFalse,
      );
      // Sheet must issue its own Host call while feed's is still gated — not
      // only wait for Overlay to resolve (passive-only would leave sizeCalls
      // at 1 here).
      expect(presentation.sizeCalls, greaterThanOrEqualTo(2));
      expect(find.byKey(const Key('cap24MoreSheetFileSizeTitle')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('cap24MoreSheetFileSizeValue')))
            .data,
        '',
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byKey(const Key('cap24MoreHalfSheet'))),
      )!;
      expect(find.text(l10n.cap24MoreSheetUnavailableValue), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      final after = container.read(presentationSizeCacheProvider)['a1'];
      expect(after?.resolved, isTrue);
      expect(after?.fileSizeBytes, 2048);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('cap24MoreSheetFileSizeValue')))
            .data,
        formatOverlayFileSize(l10n: l10n, fileSizeBytes: 2048),
      );
    },
  );

  testWidgets(
    'W-26.4-d shared non-null size: sheet displays without extra Host call',
    (tester) async {
      final presentation = FakePresentationMetadataRepository(
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 4096,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(presentationSizeCacheProvider.notifier).apply(
            'a1',
            const PresentationFileSize(
              assetIdentifier: 'a1',
              fileSizeBytes: 4096,
              fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
            ),
          );
      final callsBeforeOpen = presentation.sizeCalls;

      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      final sheetContext =
          tester.element(find.byKey(const Key('cap24MoreHalfSheet')));
      final l10n = AppLocalizations.of(sheetContext)!;
      expect(
        _inMoreSheet(
          find.text(
            formatOverlayFileSize(l10n: l10n, fileSizeBytes: 4096),
          ),
        ),
        findsOneWidget,
      );
      expect(presentation.sizeCalls, callsBeforeOpen);
    },
  );

  testWidgets(
    'W-26.4-h sheet apply writes shared cache Overlay can mirror',
    (tester) async {
      final gate = Completer<void>();
      final presentation = FakePresentationMetadataRepository(
        sizeGate: gate,
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 7777,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        container.read(presentationSizeCacheProvider)['a1']?.resolved ?? false,
        isFalse,
      );

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pump();
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      final entry = container.read(presentationSizeCacheProvider)['a1'];
      expect(entry?.resolved, isTrue);
      expect(entry?.fileSizeBytes, 7777);

      final sheetContext =
          tester.element(find.byKey(const Key('cap24MoreHalfSheet')));
      final l10n = AppLocalizations.of(sheetContext)!;
      final sizeCopy =
          formatOverlayFileSize(l10n: l10n, fileSizeBytes: 7777);
      expect(find.text(sizeCopy), findsWidgets);
    },
  );

  testWidgets(
    'W-26.4-i shared keepExisting: nil apply does not clobber bytes',
    (tester) async {
      final presentation = FakePresentationMetadataRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final cache = container.read(presentationSizeCacheProvider.notifier);
      cache.apply(
        'a1',
        const PresentationFileSize(
          assetIdentifier: 'a1',
          fileSizeBytes: 5555,
          fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
        ),
      );
      cache.apply(
        'a1',
        const PresentationFileSize(
          assetIdentifier: 'a1',
          fileSizeBytes: null,
          fileSizeSemantics: FileSizeSemantics.unknownUnavailable,
        ),
      );

      final entry = container.read(presentationSizeCacheProvider)['a1'];
      expect(entry?.fileSizeBytes, 5555);
      expect(entry?.resolved, isTrue);

      final callsBeforeOpen = presentation.sizeCalls;
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      final sheetContext =
          tester.element(find.byKey(const Key('cap24MoreHalfSheet')));
      final l10n = AppLocalizations.of(sheetContext)!;
      expect(
        _inMoreSheet(
          find.text(
            formatOverlayFileSize(l10n: l10n, fileSizeBytes: 5555),
          ),
        ),
        findsOneWidget,
      );
      expect(
        _inMoreSheet(find.text(l10n.cap24MoreSheetUnavailableValue)),
        findsNothing,
      );
      expect(presentation.sizeCalls, callsBeforeOpen);
    },
  );

  testWidgets(
    'W-26.4-e Saved time title shown with landmark; order '
    'Location→Size→Saved→Add→Delete',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            return Cap24MinuteLandmark(
              displayText: l10n.cap24SoftDeleteSheetExactMinuteLibrary(
                '2024',
                '06',
                '01',
                '12',
                '00',
              ),
              fromLibrary: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24MoreSheetSavedTimeTitle')), findsOneWidget);
      final location =
          tester.getTopLeft(find.byKey(const Key('cap24MoreSheetLocationSlot')));
      final size =
          tester.getTopLeft(find.byKey(const Key('cap24MoreSheetFileSizeBlock')));
      final saved =
          tester.getTopLeft(find.byKey(const Key('cap24MoreSheetSavedTimeBlock')));
      final add =
          tester.getTopLeft(find.byKey(const Key('cap24MoreSheetAddToAlbum')));
      final delete =
          tester.getTopLeft(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      expect(location.dy, lessThanOrEqualTo(size.dy));
      expect(size.dy, lessThan(saved.dy));
      expect(saved.dy, lessThan(add.dy));
      expect(add.dy, lessThan(delete.dy));
    },
  );

  testWidgets(
    'W-26.4-f dismiss before size resolve: no late setState throw',
    (tester) async {
      final gate = Completer<void>();
      FlutterErrorDetails? caught;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        caught = details;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      final presentation = FakePresentationMetadataRepository(
        sizeGate: gate,
        sizeById: {
          'a1': const PresentationFileSize(
            assetIdentifier: 'a1',
            fileSizeBytes: 9999,
            fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
          ),
        },
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          presentationMetadata: presentation,
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async =>
              null,
        ),
      );
      await tester.pumpAndSettle();
      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pump();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      Navigator.of(tester.element(find.byKey(const Key('cap24MoreHalfSheet'))))
          .pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(caught, isNull);
    },
  );

  testWidgets(
    'W-26.4-g zh-Hans File size / Saved time titles',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          assetSources: _localSources(),
          minuteLandmarkLoader: ({
            required l10n,
            required assetIdentifier,
          }) async {
            return Cap24MinuteLandmark(
              displayText: l10n.cap24SoftDeleteSheetExactMinuteLibrary(
                '2024',
                '06',
                '01',
                '12',
                '00',
              ),
              fromLibrary: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      expect(find.text('文件大小'), findsOneWidget);
      expect(find.text('保存时间'), findsOneWidget);
    },
  );
}
