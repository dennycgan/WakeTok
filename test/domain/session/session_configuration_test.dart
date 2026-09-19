import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';

void main() {
  test('CFG-1 OrderPolicy / AdvanceMode / RepeatPolicy names and lengths', () {
    expect(OrderPolicy.newestFirst.name, 'newestFirst');
    expect(OrderPolicy.oldestFirst.name, 'oldestFirst');
    expect(OrderPolicy.shuffle.name, 'shuffle');
    expect(OrderPolicy.values, hasLength(3));

    expect(AdvanceMode.manual.name, 'manual');
    expect(AdvanceMode.auto.name, 'auto');
    expect(AdvanceMode.values, hasLength(2));

    expect(RepeatPolicy.stopAtEnd.name, 'stopAtEnd');
    expect(RepeatPolicy.repeatAll.name, 'repeatAll');
    expect(RepeatPolicy.repeatOne.name, 'repeatOne');
    expect(RepeatPolicy.values, hasLength(3));
  });

  test(
    'CFG-2 OrderPolicy must include newestFirst, oldestFirst, shuffle (ADR-056 D1)',
    () {
      expect(OrderPolicy.values, contains(OrderPolicy.newestFirst));
      expect(OrderPolicy.values, contains(OrderPolicy.oldestFirst));
      expect(OrderPolicy.values, contains(OrderPolicy.shuffle));
      expect(OrderPolicy.values, hasLength(3));
    },
  );

  test('CFG-3 any Order × Advance × Repeat combo is constructible', () {
    const mixedDefault = SessionConfiguration(
      orderPolicy: OrderPolicy.shuffle,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    expect(mixedDefault.orderPolicy, OrderPolicy.shuffle);
    expect(mixedDefault.advanceMode, AdvanceMode.manual);
    expect(mixedDefault.repeatPolicy, RepeatPolicy.repeatAll);

    const pureClipDefault = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    expect(pureClipDefault.orderPolicy, OrderPolicy.newestFirst);

    const playOnceShape = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.stopAtEnd,
    );
    expect(playOnceShape.advanceMode, AdvanceMode.auto);
    expect(playOnceShape.repeatPolicy, RepeatPolicy.stopAtEnd);
  });

  test('CFG-4 SessionConfiguration equality / hashCode', () {
    const a = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    const b = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    const orderChanged = SessionConfiguration(
      orderPolicy: OrderPolicy.shuffle,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    expect(a, isNot(orderChanged));

    const advanceChanged = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.auto,
      repeatPolicy: RepeatPolicy.repeatAll,
    );
    expect(a, isNot(advanceChanged));

    const repeatChanged = SessionConfiguration(
      orderPolicy: OrderPolicy.newestFirst,
      advanceMode: AdvanceMode.manual,
      repeatPolicy: RepeatPolicy.repeatOne,
    );
    expect(a, isNot(repeatChanged));
  });

  test('CFG-5 enum switches are exhaustive (smoke)', () {
    String orderName(OrderPolicy p) => switch (p) {
          OrderPolicy.newestFirst => 'newestFirst',
          OrderPolicy.oldestFirst => 'oldestFirst',
          OrderPolicy.shuffle => 'shuffle',
        };
    String advanceName(AdvanceMode m) => switch (m) {
          AdvanceMode.manual => 'manual',
          AdvanceMode.auto => 'auto',
        };
    String repeatName(RepeatPolicy r) => switch (r) {
          RepeatPolicy.stopAtEnd => 'stopAtEnd',
          RepeatPolicy.repeatAll => 'repeatAll',
          RepeatPolicy.repeatOne => 'repeatOne',
        };

    for (final p in OrderPolicy.values) {
      expect(orderName(p), p.name);
    }
    for (final m in AdvanceMode.values) {
      expect(advanceName(m), m.name);
    }
    for (final r in RepeatPolicy.values) {
      expect(repeatName(r), r.name);
    }
  });
}
