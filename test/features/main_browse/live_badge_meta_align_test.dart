import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Local twin of production LIVE badge for geometry checks (private in feed).
class _LiveBadgeTwin extends StatelessWidget {
  const _LiveBadgeTwin({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final labelStyle = tokens.labelOnMedia.copyWith(
      inherit: false,
      height: 1.0,
      shadows: tokens.onMediaLabelShadows,
    );
    return DecoratedBox(
      key: const Key('mainBrowseLiveBadge'),
      decoration: ShapeDecoration(
        color: tokens.mediaScrim.withValues(alpha: kStatusChromeScrimOpacity),
        shape: StadiumBorder(
          side: BorderSide(
            color: tokens.onMedia.withValues(alpha: kStatusChromeBorderOpacity),
            width: kStatusChromeBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kLiveBadgeHorizontalPad,
          vertical: kLiveBadgeVerticalPad,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: kLiveBadgeDotSize,
              height: kLiveBadgeDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.onMedia, width: 1.25),
              ),
            ),
            const SizedBox(width: kLiveBadgeDotLabelGap),
            Text(label, style: labelStyle),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'LIVE capsule is content-sized; left aligns with Temp chip inset',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const paddingTop = 47.0;
      const limitedBand = false;
      final expectedTop = mainBrowseLiveBadgeTopInset(
        mediaQueryPaddingTop: paddingTop,
        limitedCreateHelperBand: limitedBand,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: waketokTheme(Brightness.dark),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: paddingTop),
            ),
            child: const Scaffold(
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: kLiveBadgeLeadingInset,
                    top: paddingTop +
                        kBrowseTopChromeBandHeightFull +
                        kLiveBadgeBelowTopChromeGap,
                    child: _LiveBadgeTwin(label: 'LIVE'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final live = tester.getRect(find.byKey(const Key('mainBrowseLiveBadge')));
      expect(
        live.left,
        moreOrLessEquals(kLiveBadgeLeadingInset, epsilon: 0.5),
        reason: 'LIVE left must match Temp/Saved chip leading inset',
      );
      expect(
        live.top,
        moreOrLessEquals(expectedTop, epsilon: 0.5),
        reason: 'LIVE top = padding.top + band + gap 0',
      );
      expect(
        live.height,
        lessThan(kBrowseTopChromeControlHeight),
        reason: 'LIVE must be content-sized, not Temp 32-tall shell',
      );
      expect(
        expectedTop,
        moreOrLessEquals(
          paddingTop +
              kBrowseTopChromeBandHeightFull +
              kLiveBadgeBelowTopChromeGap,
          epsilon: 0.01,
        ),
      );
      expect(kLiveBadgeBelowTopChromeGap, 0);
    },
  );

  testWidgets(
    'LIVE Limited band uses 70 so top stays below Create helper',
    (tester) async {
      const paddingTop = 47.0;
      final fullTop = mainBrowseLiveBadgeTopInset(
        mediaQueryPaddingTop: paddingTop,
        limitedCreateHelperBand: false,
      );
      final limitedTop = mainBrowseLiveBadgeTopInset(
        mediaQueryPaddingTop: paddingTop,
        limitedCreateHelperBand: true,
      );
      expect(
        limitedTop - fullTop,
        moreOrLessEquals(
          kBrowseTopChromeBandHeightLimited - kBrowseTopChromeBandHeightFull,
          epsilon: 0.01,
        ),
      );
    },
  );
}
