import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/platform/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';

void main() {
  test('T1 ErrorCode names match AppError 1:1', () {
    expect(
      ErrorCode.values.map((e) => e.name).toSet(),
      equals(AppError.values.map((e) => e.name).toSet()),
    );
    expect(ErrorCode.values, hasLength(AppError.values.length));
    expect(
      ErrorCode.values.map((e) => e.name),
      isNot(contains('inCloudUnavailable')),
    );
  });

  test('T2 appErrorFromErrorCode covers every ErrorCode', () {
    for (final code in ErrorCode.values) {
      final app = appErrorFromErrorCode(code);
      expect(app.name, code.name, reason: 'mapping for $code');
    }
  });

  test('T3 appErrorFromPlatformException R5 / known codes', () {
    expect(
      appErrorFromPlatformException(
        PlatformException(code: 'albumUnavailable'),
      ),
      AppError.albumUnavailable,
    );
    expect(
      appErrorFromPlatformException(PlatformException(code: '')),
      AppError.unknown,
    );
    expect(
      appErrorFromPlatformException(
        PlatformException(code: 'not-a-real-code'),
      ),
      AppError.unknown,
    );
  });
}
