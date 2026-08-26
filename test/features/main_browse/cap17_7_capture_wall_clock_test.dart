import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('U-17.7 exact EXIF wall clock ignores createdAt timezone skew', () {
    // DIFF case: epoch→device-local would show a different hour than Photos.
    final skewedCreatedAt = DateTime.utc(2023, 9, 9, 14, 53);
    const wall = CaptureWallClock(
      year: 2023,
      month: 9,
      day: 9,
      hour: 22,
      minute: 53,
    );
    final exact = formatOverlayExactDateTime(
      l10n: l10n,
      exactDateResolved: true,
      captureWallClock: wall,
      createdAt: skewedCreatedAt,
    );
    expect(exact, l10n.mediaInfoExactDateTime('2023', '09', '09', '22', '53'));
    // Must not equal a toLocal() formatting of skewedCreatedAt on any TZ.
    final fallbackOnly = formatOverlayExactDateTime(
      l10n: l10n,
      exactDateResolved: true,
      createdAt: skewedCreatedAt,
    );
    expect(exact, isNot(fallbackOnly));
  });

  test('U-17.7 exact unresolved stays blank', () {
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: false,
        captureWallClock: const CaptureWallClock(
          year: 2024,
          month: 1,
          day: 1,
          hour: 12,
          minute: 0,
        ),
        createdAt: DateTime(2024, 1, 1, 12),
      ),
      '',
    );
  });

  test('U-17.7 NO_EXIF fallback uses createdAt device-local components', () {
    // Fixed local DateTime — no dependence on runner TZ for the assertion
    // when we pass a non-UTC DateTime already in local fields.
    final created = DateTime(2019, 11, 8, 19, 0);
    final exact = formatOverlayExactDateTime(
      l10n: l10n,
      exactDateResolved: true,
      captureWallClock: null,
      createdAt: created,
    );
    expect(exact, l10n.mediaInfoExactDateTime('2019', '11', '08', '19', '00'));
  });

  test('U-17.7 Istanbul DIFF: EXIF 00:10 wins over Auckland-skewed createdAt', () {
    // Photos: 2019-12-27 00:10; epoch→NZDT can show 10:10 — must not win.
    final aucklandSkewed = DateTime(2019, 12, 27, 10, 10);
    const istanbulWall = CaptureWallClock(
      year: 2019,
      month: 12,
      day: 27,
      hour: 0,
      minute: 10,
    );
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: true,
        captureWallClock: istanbulWall,
        createdAt: aucklandSkewed,
      ),
      l10n.mediaInfoExactDateTime('2019', '12', '27', '00', '10'),
    );
  });

  test('U-17.7 blank then Host EXIF is empty→correct (not wrong→correct)', () {
    final created = DateTime(2019, 12, 27, 10, 10);
    const wall = CaptureWallClock(
      year: 2019,
      month: 12,
      day: 27,
      hour: 0,
      minute: 10,
    );
    final pending = PresentationOverlaySnapshot(
      assetIdentifier: 'tr',
      createdAt: created,
      exactDateResolved: false,
    );
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: pending.exactDateResolved,
        createdAt: pending.createdAt,
      ),
      '',
    );
    final filled = pending.mergeCaptureWallClock(wallClock: wall);
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: filled.exactDateResolved,
        captureWallClock: filled.captureWallClock,
        createdAt: filled.createdAt,
      ),
      l10n.mediaInfoExactDateTime('2019', '12', '27', '00', '10'),
    );
  });

  test('U-17.7 relative uses fixed Instant + fixed now (not wall clock)', () {
    final now = DateTime(2024, 6, 10, 15, 0);
    // Wall clock would be "today" locally; Instant is 2 days ago.
    final created = DateTime(2024, 6, 8, 12, 0);
    expect(
      formatOverlayRelativeDate(l10n: l10n, exactDateResolved: true, createdAt: created, now: now),
      l10n.mediaInfoRelativeDaysAgo('2'),
    );
  });

  test('U-17.7 MATCH: wall clock equals local createdAt fields', () {
    const wall = CaptureWallClock(
      year: 2026,
      month: 8,
      day: 26,
      hour: 15,
      minute: 35,
    );
    final created = DateTime(2026, 8, 26, 15, 35);
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: true,
        captureWallClock: wall,
        createdAt: created,
      ),
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: true,
        createdAt: created,
      ),
    );
  });

  test('U-17.7 video/NO_EXIF snapshot settles exact via mergeCaptureWallClock', () {
    final snap = PresentationOverlaySnapshot(
      assetIdentifier: 'v1',
      createdAt: DateTime(2024, 1, 2, 3, 4),
      exactDateResolved: false,
    );
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: snap.exactDateResolved,
        createdAt: snap.createdAt,
      ),
      '',
    );
    final settled = snap.mergeCaptureWallClock(wallClock: null);
    expect(settled.exactDateResolved, isTrue);
    expect(settled.captureWallClock, isNull);
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: settled.exactDateResolved,
        captureWallClock: settled.captureWallClock,
        createdAt: settled.createdAt,
      ),
      l10n.mediaInfoExactDateTime('2024', '01', '02', '03', '04'),
    );
  });

  test('U-17.7 mergeBasics preserves resolved wall clock on same asset', () {
    final withWall = const PresentationOverlaySnapshot(
      assetIdentifier: 'a',
      exactDateResolved: true,
      captureWallClock: CaptureWallClock(
        year: 2021,
        month: 10,
        day: 13,
        hour: 8,
        minute: 18,
      ),
    ).mergeBasics(
      PresentationMetadata(
        assetIdentifier: 'a',
        mediaKind: PresentationMediaKind.image,
        createdAt: DateTime(2021, 10, 13, 13, 18),
      ),
    );
    expect(withWall.exactDateResolved, isTrue);
    expect(withWall.captureWallClock?.hour, 8);
  });

  test('U-17.7-policy Host-complete-only: no timeout-fallback lock constant', () {
    // Timeout must not settle epoch fallback; policy file documents that.
    // (Former kCaptureWallClockAttemptTimeout removed.)
    expect(
      formatOverlayExactDateTime(
        l10n: l10n,
        exactDateResolved: false,
        createdAt: DateTime(2019, 12, 27, 10, 10),
      ),
      isEmpty,
      reason: 'unresolved must stay blank — never premature Auckland fallback',
    );
  });
}
