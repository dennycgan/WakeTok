import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-process guide shown flag (resets on cold start).
class Cap19LeftSwipeGuideSession {
  Cap19LeftSwipeGuideSession._();

  static bool guideShownThisLaunch = false;

  static void markGuideShown() => guideShownThisLaunch = true;

  @visibleForTesting
  static void resetForTest() => guideShownThisLaunch = false;
}

class Cap19ActionsPanelOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

/// True while Cap 19 actions half-sheet is presented.
final cap19ActionsPanelOpenProvider =
    NotifierProvider<Cap19ActionsPanelOpenNotifier, bool>(
      Cap19ActionsPanelOpenNotifier.new,
    );

class Cap19LeftSwipePrefsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Bumped when Settings writes left-swipe KV so Browse reloads without kill.
final cap19LeftSwipePrefsRevisionProvider =
    NotifierProvider<Cap19LeftSwipePrefsRevisionNotifier, int>(
      Cap19LeftSwipePrefsRevisionNotifier.new,
    );
