import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/library_smoke/builtin_quantile.dart';

void main() {
  test('builtinAllQuantileIndices empty / single / multi', () {
    expect(builtinAllQuantileIndices(0), isEmpty);
    expect(builtinAllQuantileIndices(1), [0]);
    expect(builtinAllQuantileIndices(4), [0, 1, 2, 3]);
    expect(builtinAllQuantileIndices(5), [0, 1, 2, 3, 4]);
    expect(builtinAllQuantileIndices(100), [0, 24, 49, 74, 99]);
  });
}
