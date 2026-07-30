import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/result/result.dart';

void main() {
  group('Ok / Err flags', () {
    test('Ok is ok and not err', () {
      const Result<int, String> r = Ok(1);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
    });

    test('Err is err and not ok', () {
      const Result<int, String> r = Err('e');
      expect(r.isOk, isFalse);
      expect(r.isErr, isTrue);
    });
  });

  group('map', () {
    test('transforms Ok value', () {
      const Result<int, String> r = Ok(2);
      expect(r.map((v) => v * 3), isA<Ok<int, String>>());
      expect((r.map((v) => v * 3) as Ok<int, String>).value, 6);
    });

    test('passes Err through', () {
      const Result<int, String> r = Err('e');
      final mapped = r.map((v) => v * 3);
      expect(mapped, isA<Err<int, String>>());
      expect((mapped as Err<int, String>).error, 'e');
    });
  });

  group('mapError', () {
    test('transforms Err', () {
      const Result<int, String> r = Err('e');
      final mapped = r.mapError((e) => e.length);
      expect(mapped, isA<Err<int, int>>());
      expect((mapped as Err<int, int>).error, 1);
    });

    test('passes Ok through', () {
      const Result<int, String> r = Ok(2);
      final mapped = r.mapError((e) => e.length);
      expect(mapped, isA<Ok<int, int>>());
      expect((mapped as Ok<int, int>).value, 2);
    });
  });

  group('flatMap', () {
    test('Ok to Ok', () {
      const Result<int, String> r = Ok(2);
      final next = r.flatMap((v) => Ok<String, String>('$v'));
      expect((next as Ok<String, String>).value, '2');
    });

    test('Ok to Err', () {
      const Result<int, String> r = Ok(2);
      final next = r.flatMap((_) => const Err<String, String>('nope'));
      expect((next as Err<String, String>).error, 'nope');
    });

    test('Err short-circuits', () {
      const Result<int, String> r = Err('e');
      final next = r.flatMap((v) => Ok<String, String>('$v'));
      expect((next as Err<String, String>).error, 'e');
    });
  });

  group('fold / getOrElse', () {
    test('fold Ok', () {
      const Result<int, String> r = Ok(2);
      expect(r.fold(onErr: (_) => -1, onOk: (v) => v), 2);
    });

    test('fold Err', () {
      const Result<int, String> r = Err('e');
      expect(r.fold(onErr: (e) => e.length, onOk: (_) => -1), 1);
    });

    test('getOrElse Ok', () {
      const Result<int, String> r = Ok(2);
      expect(r.getOrElse((_) => 0), 2);
    });

    test('getOrElse Err', () {
      const Result<int, String> r = Err('e');
      expect(r.getOrElse((e) => e.length), 1);
    });
  });
}
