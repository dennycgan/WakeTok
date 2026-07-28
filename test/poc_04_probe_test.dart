import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_04/poc_04_probe.dart';

Poc04ProbeSample _s(int step, {int a = 1, int w = 1, int t = 3}) =>
    Poc04ProbeSample(
      step: step,
      activeCount: a,
      warmingCount: w,
      tempFileCount: t,
    );

void main() {
  test('evaluatePoc04Probe passes bounded pool and non-growing temp', () {
    final samples = <Poc04ProbeSample>[
      for (var i = 0; i <= 100; i++)
        _s(i, a: i.isEven ? 1 : 0, w: i.isEven ? 1 : 0, t: 3),
    ];
    final result = evaluatePoc04Probe(samples: samples, transitions: 100);
    expect(result.passed, isTrue);
    expect(result.summary, startsWith('PASS'));
  });

  test('evaluatePoc04Probe fails when pool exceeds 1+1', () {
    final samples = <Poc04ProbeSample>[
      _s(0),
      _s(1, a: 2, w: 1, t: 3),
    ];
    final result = evaluatePoc04Probe(samples: samples, transitions: 1);
    expect(result.passed, isFalse);
    expect(result.summary, startsWith('FAIL'));
  });

  test('evaluatePoc04Probe fails when last-window temp grows vs first', () {
    final samples = <Poc04ProbeSample>[
      for (var i = 0; i < 10; i++) _s(i, t: 2),
      for (var i = 10; i <= 100; i++) _s(i, t: i < 90 ? 3 : 8),
    ];
    final result = evaluatePoc04Probe(samples: samples, transitions: 100);
    expect(result.passed, isFalse);
    expect(result.lastWindowMaxTemp, greaterThan(result.firstWindowMaxTemp + 2));
  });
}
