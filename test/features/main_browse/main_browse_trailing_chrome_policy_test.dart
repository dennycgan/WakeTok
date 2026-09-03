import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/main_browse_trailing_chrome_policy.dart';

void main() {
  group('mainBrowseTrailingMutationChromeVisible', () {
    test('positive: actionable + settled + !covering → visible', () {
      expect(
        mainBrowseTrailingMutationChromeVisible(
          actionable: true,
          verticalFeedSettled: true,
          transitionCovering: false,
        ),
        isTrue,
      );
    });

    test('peek only: !settled hides', () {
      expect(
        mainBrowseTrailingMutationChromeVisible(
          actionable: true,
          verticalFeedSettled: false,
          transitionCovering: false,
        ),
        isFalse,
      );
    });

    test('covering only: covering hides', () {
      expect(
        mainBrowseTrailingMutationChromeVisible(
          actionable: true,
          verticalFeedSettled: true,
          transitionCovering: true,
        ),
        isFalse,
      );
    });

    test('not-actionable only: gate closed (UI Decision 7 still dims)', () {
      expect(
        mainBrowseTrailingMutationChromeVisible(
          actionable: false,
          verticalFeedSettled: true,
          transitionCovering: false,
        ),
        isFalse,
      );
    });

    test('peek + covering both false', () {
      expect(
        mainBrowseTrailingMutationChromeVisible(
          actionable: true,
          verticalFeedSettled: false,
          transitionCovering: true,
        ),
        isFalse,
      );
    });
  });
}
