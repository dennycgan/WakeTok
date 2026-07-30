import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/errors/native_error_mapping_spec.dart';

void main() {
  test('native mapping spec has R1–R6 with locked targets', () {
    expect(nativeErrorMappingRules, hasLength(6));
    expect(
      nativeErrorMappingRules.map((r) => r.id).toSet(),
      equals(NativeErrorMappingRuleId.values.toSet()),
    );

    AppError? targetOf(NativeErrorMappingRuleId id) =>
        nativeErrorMappingRules.firstWhere((r) => r.id == id).target;

    expect(targetOf(NativeErrorMappingRuleId.r1), AppError.iCloudDownloadRequired);
    expect(targetOf(NativeErrorMappingRuleId.r2), AppError.iCloudDownloadFailed);
    expect(targetOf(NativeErrorMappingRuleId.r3), AppError.operationCancelled);
    expect(targetOf(NativeErrorMappingRuleId.r4), AppError.unknown);
    expect(targetOf(NativeErrorMappingRuleId.r5), AppError.unknown);
    expect(targetOf(NativeErrorMappingRuleId.r6), isNull);

    final r2 = nativeErrorMappingRules
        .firstWhere((r) => r.id == NativeErrorMappingRuleId.r2);
    expect(r2.summary, contains('transfer phase'));
    expect(r2.summary, contains('non-3164'));

    final r1 = nativeErrorMappingRules
        .firstWhere((r) => r.id == NativeErrorMappingRuleId.r1);
    expect(r1.summary, contains('3164'));

    final r6 = nativeErrorMappingRules
        .firstWhere((r) => r.id == NativeErrorMappingRuleId.r6);
    expect(r6.summary, contains('inCloudUnavailable'));
  });
}
