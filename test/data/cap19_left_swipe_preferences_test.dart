import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/data/preferences/cap19_left_swipe_preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T-19.6-5 KV defaults true and round-trips', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = Cap19LeftSwipePreferencesStore(preferences: prefs);

    expect(await store.isLeftSwipeAddEnabled(), isTrue);
    expect(await store.isLeftSwipeGuideEnabled(), isTrue);

    await store.setLeftSwipeAddEnabled(false);
    await store.setLeftSwipeGuideEnabled(false);
    expect(await store.isLeftSwipeAddEnabled(), isFalse);
    expect(await store.isLeftSwipeGuideEnabled(), isFalse);
  });
}
