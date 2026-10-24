import 'package:flutter_test/flutter_test.dart';

/// Temporary CI red-light probe for debt 449. Must not land on main.
void main() {
  test('ci red probe must fail', () {
    expect(1, 2);
  });
}
