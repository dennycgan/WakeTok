import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/presentation_date_format.dart';
import 'package:waketok/l10n/app_localizations.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations zh;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    zh = await AppLocalizations.delegate.load(const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    ));
  });

  test('U1 fixed Instant → ~ calendar date (EN and zh-Hans)', () {
    // Construct as local civil clock so device TZ does not skew the fixture.
    final created = DateTime(2021, 6, 6, 10, 31);
    expect(
      formatOverlayExactDateTime(l10n: en, createdAt: created),
      en.mediaInfoExactDateApprox('2021', '06', '06'),
    );
    expect(
      formatOverlayExactDateTime(l10n: zh, createdAt: created),
      zh.mediaInfoExactDateApprox('2021', '06', '06'),
    );
    expect(
      formatOverlayExactDateTime(l10n: en, createdAt: created),
      '~ 2021-06-06',
    );
    expect(
      formatOverlayExactDateTime(l10n: zh, createdAt: created),
      '~ 2021-06-06',
    );
  });

  test('U2 null createdAt → blank', () {
    expect(formatOverlayExactDateTime(l10n: en, createdAt: null), '');
  });

  test('U3 output has no hour:minute colon form', () {
    final created = DateTime(2019, 11, 8, 19, 0);
    final exact = formatOverlayExactDateTime(l10n: en, createdAt: created);
    expect(exact, isNot(contains(RegExp(r'\d{2}:\d{2}'))));
    expect(exact, isNot(contains('19:00')));
  });

  test('U4 relative short band: diffDays 2 → within 3 days', () {
    final now = DateTime(2024, 6, 10, 15, 0);
    final created = DateTime(2024, 6, 8, 12, 0);
    expect(
      formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
      en.mediaInfoRelativeWithin3Days,
    );
    expect(
      formatOverlayRelativeDate(l10n: zh, createdAt: created, now: now),
      zh.mediaInfoRelativeWithin3Days,
    );
  });

  group('Cap 17.7 relative coarse bands (R-A..R-future)', () {
    final now = DateTime(2024, 6, 10, 15, 0);

    test('R-A0 diffDays 0', () {
      final created = DateTime(2024, 6, 10, 8);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        'Within the past 3 days',
      );
      expect(
        formatOverlayRelativeDate(l10n: zh, createdAt: created, now: now),
        '3天内',
      );
    });

    test('R-A1 diffDays 1', () {
      final created = DateTime(2024, 6, 9, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeWithin3Days,
      );
    });

    test('R-A2 diffDays 2 (A|B boundary low)', () {
      final created = DateTime(2024, 6, 8, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeWithin3Days,
      );
    });

    test('R-B3 diffDays 3 (A|B boundary high)', () {
      final created = DateTime(2024, 6, 7, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeWithinWeek,
      );
      expect(
        formatOverlayRelativeDate(l10n: zh, createdAt: created, now: now),
        '一周内',
      );
    });

    test('R-B7 diffDays 7 (B|C boundary low)', () {
      final created = DateTime(2024, 6, 3, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeWithinWeek,
      );
    });

    test('R-C8 diffDays 8 (B|C boundary high)', () {
      final created = DateTime(2024, 6, 2, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeDaysAgo('8'),
      );
    });

    test('R-C30 diffDays 30', () {
      final created = DateTime(2024, 5, 11, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeDaysAgo('30'),
      );
    });

    test('R-D31 diffDays 31 → months', () {
      final created = DateTime(2024, 5, 10, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeMonthsAgo(1),
      );
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        '1 month ago',
      );
    });

    test('R-future diffDays negative', () {
      final created = DateTime(2024, 6, 11, 12);
      expect(
        formatOverlayRelativeDate(l10n: en, createdAt: created, now: now),
        en.mediaInfoRelativeWithin3Days,
      );
    });
  });
}
