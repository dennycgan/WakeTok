import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/authorization/permission_blocked_page.dart';
import 'package:waketok/features/authorization/permission_request_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import 'permission_ui_test_harness.dart';

const _en = Locale('en');
const _zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

Future<AppLocalizations> _pumpRequestPage(
  WidgetTester tester,
  Locale locale,
) async {
  final repo = ControllablePhotosAuthorizationRepository(
    PhotosAccess.notDetermined,
  );
  await tester.pumpWidget(permissionUiHarness(repo: repo, locale: locale));
  await tester.pumpAndSettle();
  expect(find.byType(PermissionRequestPage), findsOneWidget);
  return AppLocalizations.delegate.load(locale);
}

Finder _bulletDots() => find.descendant(
      of: find.byType(PermissionRequestPage),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );

double _gapBelowHeadline(WidgetTester tester, String headline, String first) {
  return tester.getTopLeft(find.text(first)).dy -
      tester.getBottomLeft(find.text(headline)).dy;
}

void main() {
  testWidgets(
      'W-31.4-perm-1 EN shows three points with the rediscover line first',
      (tester) async {
    final l10n = await _pumpRequestPage(tester, _en);

    expect(l10n.permissionRequestPointRediscover.trim(), isNotEmpty);
    final rediscover = find.text(l10n.permissionRequestPointRediscover);
    final noAccount = find.text(l10n.permissionRequestPointNoAccount);
    final chooseOrder = find.text(l10n.permissionRequestPointChooseOrder);
    expect(rediscover, findsOneWidget);
    expect(noAccount, findsOneWidget);
    expect(chooseOrder, findsOneWidget);
    expect(_bulletDots(), findsNWidgets(3));

    final headlineBottom =
        tester.getBottomLeft(find.text(l10n.permissionRequestTitle)).dy;
    final rediscoverTop = tester.getTopLeft(rediscover).dy;
    expect(rediscoverTop, greaterThan(headlineBottom));
    expect(rediscoverTop, lessThan(tester.getTopLeft(noAccount).dy));
    expect(
      tester.getTopLeft(noAccount).dy,
      lessThan(tester.getTopLeft(chooseOrder).dy),
    );
  });

  testWidgets('W-31.4-perm-2 zh shows only two points and no empty line',
      (tester) async {
    final en = await _pumpRequestPage(tester, _en);
    final enGap = _gapBelowHeadline(
      tester,
      en.permissionRequestTitle,
      en.permissionRequestPointRediscover,
    );

    final zh = await _pumpRequestPage(tester, _zhHans);

    expect(zh.permissionRequestPointRediscover.trim(), isEmpty);
    expect(_bulletDots(), findsNWidgets(2));
    expect(find.text(zh.permissionRequestPointNoAccount), findsOneWidget);
    expect(find.text(zh.permissionRequestPointChooseOrder), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PermissionRequestPage),
        matching: find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').trim().isEmpty,
        ),
      ),
      findsNothing,
    );
    expect(
      _gapBelowHeadline(
        tester,
        zh.permissionRequestTitle,
        zh.permissionRequestPointNoAccount,
      ),
      moreOrLessEquals(enGap),
    );
  });

  testWidgets(
      'W-31.4-perm-3 CTA uses the light accent fill and white text in both '
      'Appearances on the request and blocked pages', (tester) async {
    final lightAccent =
        waketokTheme(Brightness.light).extension<WakeTokTokens>()!.accent;
    const cases = <(PhotosAccess, Type)>[
      (PhotosAccess.notDetermined, PermissionRequestPage),
      (PhotosAccess.denied, PermissionBlockedPage),
    ];

    for (final (access, pageType) in cases) {
      final colors = <Brightness, (Color?, Color?)>{};
      for (final (mode, brightness) in const [
        (ThemeMode.light, Brightness.light),
        (ThemeMode.dark, Brightness.dark),
      ]) {
        // Fresh ProviderScope per case; otherwise the prior access sticks.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          permissionUiHarness(
            repo: ControllablePhotosAuthorizationRepository(access),
            locale: _en,
            themeMode: mode,
          ),
        );
        await tester.pumpAndSettle();

        final page = find.byType(pageType);
        expect(page, findsOneWidget);
        expect(Theme.of(tester.element(page)).brightness, brightness);

        final style = tester
            .widget<FilledButton>(
              find.descendant(of: page, matching: find.byType(FilledButton)),
            )
            .style!;
        final fill = style.backgroundColor!.resolve(<WidgetState>{});
        final text = style.foregroundColor!.resolve(<WidgetState>{});
        expect(fill, lightAccent, reason: '$pageType $brightness fill');
        expect(text, Colors.white, reason: '$pageType $brightness text');
        colors[brightness] = (fill, text);
      }
      expect(colors[Brightness.dark], colors[Brightness.light]);
    }
  });
}
