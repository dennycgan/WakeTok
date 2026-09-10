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
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';

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

  testWidgets('W-24.3-1 ellipsis at index 0; Cap 19 above at index 1',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(repo: repo, assetSources: _localSources()),
    );
    await tester.pumpAndSettle();

    final tokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
    final lowest = mainBrowseActionColumnLowestBottomInset(tokens);
    final cap19Expected = actionColumnBottomInsetForIndex(1, lowest);

    final more = tester.getRect(find.byKey(const Key('cap24MoreEntryIcon')));
    final cap19 = tester.getRect(find.byKey(const Key('cap19EntryIcon')));

    expect(more.bottom, more.top + kActionColumnHitSize);
    // Positioned bottom inset: distance from stack bottom to widget bottom.
    final stackBottom = tester.getBottomLeft(find.byType(Scaffold)).dy +
        tester.getSize(find.byType(Scaffold)).height;
    // Prefer comparing Cap19 bottom > More bottom (higher on screen = smaller dy).
    expect(cap19.bottom, lessThan(more.bottom));
    expect(cap19.top, lessThan(more.top));
    expect(
      (cap19Expected - lowest - (kActionColumnHitSize + kActionColumnItemSpacing))
          .abs(),
      lessThan(0.01),
    );
    expect(find.byKey(const Key('cap24MoreEntryIcon')), findsOneWidget);
    expect(find.byKey(const Key('cap19EntryIcon')), findsOneWidget);
    // Touch stackBottom to avoid unused warning if layout asserts evolve.
    expect(stackBottom, greaterThan(0));
  });

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
    'W-24.3-4 Cancel confirm does not call softDelete; sheet remains',
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
      expect(
        find.byKey(const Key('cap24SoftDeleteConfirmDialog')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirmCancel')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 0);
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();

      sources.availabilityById['a1'] = AssetAvailability.unavailable;

      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 0);
      expect(find.byKey(const Key('stillInLibraryUnavailableDialog')),
          findsOneWidget);
      // Confirm stays until Cap 23 dialog is dismissed (ensure awaits it).
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('stillInLibraryUnavailableDialogDismiss')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-6 success: softDelete once; sheet+dialog gone; no success toast',
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
      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 1);
      expect(softDelete.lastAssetId, 'a1');
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-7 operationCancelled: no failure toast; sheet remains',
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
      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
      await tester.pumpAndSettle();

      expect(softDelete.callCount, 1);
      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsNothing);
    },
  );

  testWidgets(
    'W-24.3-8 Host unknown: failure toast; sheet remains',
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
      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24SoftDeleteFailedToast')), findsOneWidget);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);
      hideCap19BrowseToast();
    },
  );

  testWidgets(
    'W-24.3-9 Instant approx minute row when loader returns approximate',
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
              displayText: l10n.cap24SoftDeleteSheetExactMinuteApprox(
                '2024',
                '06',
                '01',
                '12',
                '00',
              ),
              isApproximate: true,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await _openMoreSheet(tester);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteApprox')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cap24SoftDeleteSheetMinuteTimezoneNote')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'W-24.3-10 busy latch: double Confirm → softDelete once',
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
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
      await tester.pump();
      expect(find.byKey(const Key('cap24SoftDeleteConfirmBusy')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
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
    'W-24.3-12 one-paint: never shows approx then bare',
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
              isApproximate: false,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cap24MoreEntryIcon')));
      await tester.pump();
      await tester.pump();

      // While loading: no minute keys yet.
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteApprox')),
          findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteApprox')),
          findsNothing);

      // Scan all Text under sheet — no approx prefix appeared.
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
              isApproximate: false,
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
    'W-24.3-14 dual modal: Cancel pops dialog only; popRoute order',
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
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsOneWidget);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      // Simulated Android back — first pop closes dialog only.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsNothing);
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cap24SoftDeleteSheetDelete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirmCancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsOneWidget);

      // Second back closes sheet.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24MoreHalfSheet')), findsNothing);
      expect(softDelete.callCount, 0);
    },
  );

  testWidgets(
    'W-24.3-15 Host in-flight: confirm dialog Key still present (Q6=A)',
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
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cap24SoftDeleteConfirm')));
      await tester.pump();

      expect(softDelete.callCount, 1);
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsOneWidget);
      expect(find.byKey(const Key('cap24SoftDeleteConfirmBusy')), findsOneWidget);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap24SoftDeleteConfirmDialog')), findsNothing);
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

      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteApprox')),
          findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetMinuteBare')), findsNothing);
      expect(find.byKey(const Key('cap24SoftDeleteSheetDelete')), findsOneWidget);
    },
  );
}
