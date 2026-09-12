import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap24_minute_landmark.dart';
import 'package:waketok/features/main_browse/cap24_timezone_note_bubble.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
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
  await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
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

      // No tilde honesty mark on EXIF bare path.
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
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
    'W-24.3-16 omit minute row when loader returns null',
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

      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteLibrary')),
          findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsNothing);
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
      final handle = showCap24TimezoneNoteBubble(
        context: sheetContext,
        message: l10n.cap24SoftDeleteSheetMinuteTimezoneNote,
        anchorOverlayRect: const Rect.fromLTWH(280, 520, 44, 44),
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
}
