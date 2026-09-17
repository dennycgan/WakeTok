import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_live_motion_watchdog.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/source/source_reference.dart';

void main() {
  test('kLiveMotionEndedWatchdog is 6s (post-startPlayback budget)', () {
    expect(kLiveMotionEndedWatchdog, const Duration(seconds: 6));
  });

  test('watchdog skip set: add / contains / clear', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final skip = container.read(
      browseLiveMotionWatchdogSkipIdsProvider.notifier,
    );
    expect(skip.contains('a'), isFalse);
    skip.add('a');
    expect(container.read(browseLiveMotionWatchdogSkipIdsProvider), {'a'});
    skip.add('a');
    expect(container.read(browseLiveMotionWatchdogSkipIdsProvider), {'a'});
    skip.clear();
    expect(container.read(browseLiveMotionWatchdogSkipIdsProvider), isEmpty);
  });

  test('watchdog skip set clears on Origin change', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(browseLiveMotionWatchdogSkipIdsProvider.notifier)
        .add('stuck');
    expect(
      container.read(browseLiveMotionWatchdogSkipIdsProvider).contains('stuck'),
      isTrue,
    );
    container
        .read(browseChromeStateProvider.notifier)
        .selectBuiltIn(SourceReference.photos);
    expect(container.read(browseLiveMotionWatchdogSkipIdsProvider), isEmpty);
  });
}
