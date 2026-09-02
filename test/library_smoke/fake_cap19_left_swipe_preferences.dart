import 'package:waketok/domain/library/cap19_left_swipe_preferences.dart';

class FakeCap19LeftSwipePreferences implements Cap19LeftSwipePreferences {
  bool leftSwipeAddEnabled = true;

  /// Default false so existing feed harness tests are not affected by the
  /// 2.5s guide timer. Cap 19.6 guide tests set this true explicitly.
  bool leftSwipeGuideEnabled = false;

  @override
  Future<bool> isLeftSwipeAddEnabled() async => leftSwipeAddEnabled;

  @override
  Future<bool> isLeftSwipeGuideEnabled() async => leftSwipeGuideEnabled;

  @override
  Future<void> setLeftSwipeAddEnabled(bool value) async {
    leftSwipeAddEnabled = value;
  }

  @override
  Future<void> setLeftSwipeGuideEnabled(bool value) async {
    leftSwipeGuideEnabled = value;
  }
}
