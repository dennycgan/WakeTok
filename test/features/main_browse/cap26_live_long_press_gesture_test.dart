import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_arbitration.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_gesture.dart';

/// Hold harness: [mayFire] drops after fire (Path R / S mount), so only
/// [holdingAfterFire] keeps the Listener mounted (Cap 26.5a).
Future<({int Function() fires, int Function() releases})> _pumpHoldHarness(
  WidgetTester tester,
) async {
  var mayFire = true;
  var holdingAfterFire = false;
  var fires = 0;
  var releases = 0;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                Cap26LiveLongPressGesture(
                  enabled: shouldMountLiveLongPressListener(
                    mayFire: mayFire,
                    holdingAfterFire: holdingAfterFire,
                    isCurrent: true,
                  ),
                  onLongPressFire: () {
                    fires += 1;
                    setState(() {
                      holdingAfterFire = true;
                      mayFire = false;
                    });
                  },
                  onLongPressRelease: () {
                    releases += 1;
                    setState(() {
                      holdingAfterFire = false;
                      mayFire = true;
                    });
                  },
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  return (fires: () => fires, releases: () => releases);
}

Future<TestGesture> _fireWithA(WidgetTester tester) async {
  final center = tester.getCenter(
    find.byKey(const Key('cap26LiveLongPressGesture')),
  );
  final a = await tester.startGesture(center, pointer: 1);
  await tester.pump(kLiveLongPressHoldDuration);
  await tester.pump();
  return a;
}

Future<TestGesture> _downB(WidgetTester tester) async {
  final center = tester.getCenter(
    find.byKey(const Key('cap26LiveLongPressGesture')),
  );
  final b = await tester.startGesture(
    center + const Offset(40, 40),
    pointer: 2,
  );
  await tester.pump();
  return b;
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Cap 31.4a hold follows the pointer that fired it', () {
    testWidgets(
      'T-31.4a-G1 after fire, second pointer down / move / up is ignored; '
      'firing pointer up releases once',
      (tester) async {
        final h = await _pumpHoldHarness(tester);
        final a = await _fireWithA(tester);
        expect(h.fires(), 1);

        final b = await _downB(tester);
        await b.moveBy(const Offset(60, 0));
        await tester.pump();
        await b.up();
        await tester.pump();
        expect(h.releases(), 0);
        expect(
          find.byKey(const Key('cap26LiveLongPressGesture')),
          findsOneWidget,
          reason: 'hold must survive the second pointer',
        );

        await a.up();
        await tester.pump();
        expect(h.releases(), 1);
        expect(h.fires(), 1);
      },
    );

    testWidgets(
      'T-31.4a-G2 after fire, firing pointer up releases while second '
      'pointer is still down; second pointer up adds nothing',
      (tester) async {
        final h = await _pumpHoldHarness(tester);
        final a = await _fireWithA(tester);
        final b = await _downB(tester);

        await a.up();
        await tester.pump();
        expect(h.releases(), 1);

        await b.up();
        await tester.pump();
        expect(h.releases(), 1);
        expect(h.fires(), 1);
      },
    );

    testWidgets(
      'T-31.4a-G3 after fire, second pointer cancel is ignored; firing '
      'pointer cancel releases once',
      (tester) async {
        final h = await _pumpHoldHarness(tester);
        final a = await _fireWithA(tester);
        final b = await _downB(tester);

        await b.cancel();
        await tester.pump();
        expect(h.releases(), 0);

        await a.cancel();
        await tester.pump();
        expect(h.releases(), 1);
      },
    );
  });
}
