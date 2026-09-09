import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';

void main() {
  testWidgets(
    'U-22.5 toast top inset matches inside vs outside SafeArea',
    (tester) async {
      // Test binding view has no status-bar padding; inject via MediaQuery
      // and assert SafeArea still zeroes inherited paddings (the trap).
      const injectedTop = 59.0;
      late double outsideInset;
      late double insideInset;
      late double insidePaddingTop;
      late double insideViewPaddingTop;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: injectedTop),
              viewPadding: EdgeInsets.only(top: injectedTop),
            ),
            child: Builder(
              builder: (outsideContext) {
                outsideInset = cap19BrowseToastTopInset(outsideContext);
                return SafeArea(
                  child: Builder(
                    builder: (insideContext) {
                      insidePaddingTop =
                          MediaQuery.paddingOf(insideContext).top;
                      insideViewPaddingTop =
                          MediaQuery.viewPaddingOf(insideContext).top;
                      insideInset = cap19BrowseToastTopInset(insideContext);
                      return const SizedBox.shrink();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Trap still present: SafeArea zeroes inherited padding AND viewPadding.
      expect(insidePaddingTop, 0);
      expect(insideViewPaddingTop, 0);

      // fromView-based inset ignores those zeroes; inside == outside.
      expect(insideInset, outsideInset);

      // And matches the chrome formula against the real FlutterView padding
      // (test View is typically 0; injected MediaQuery alone is not the
      // fromView source — assert equality + non-negative chrome stack).
      expect(
        outsideInset,
        greaterThanOrEqualTo(
          kCap19BrowseTopChromeBodyHeight + kCap19BrowseToastBelowTopChromeGap,
        ),
      );
    },
  );

  testWidgets(
    'U-22.5 toast top inset uses FlutterView padding (not SafeArea MQ)',
    (tester) async {
      late double fromViewTop;
      late double inset;

      await tester.pumpWidget(
        MaterialApp(
          home: SafeArea(
            child: Builder(
              builder: (context) {
                fromViewTop =
                    MediaQueryData.fromView(View.of(context)).viewPadding.top;
                inset = cap19BrowseToastTopInset(context);
                // Inherited paddings are zero under SafeArea in tests too.
                expect(MediaQuery.paddingOf(context).top, 0);
                expect(MediaQuery.viewPaddingOf(context).top, 0);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(
        inset,
        fromViewTop +
            kCap19BrowseTopChromeBodyHeight +
            kCap19BrowseToastBelowTopChromeGap,
      );
    },
  );
}
