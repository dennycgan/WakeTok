import 'package:waketok/core/errors/app_error.dart';

/// Contract-only native → [AppError] mapping rules.
///
/// Swift-side execution lands in later capabilities' first real native
/// implementations. Pigeon `ErrorCode` and ErrorCode → AppError mapping
/// land in App Foundation 4.3.
///
/// Rules:
/// - **R1** — PHPhotosError **3164**, or equivalent “network required”
///   while `networkAccessAllowed == false` → [AppError.iCloudDownloadRequired].
/// - **R2** — Network allowed, download request has **entered the transfer
///   phase**, then fails with a non-3164 underlying error →
///   [AppError.iCloudDownloadFailed]. Merely allowing network or issuing a
///   request that never enters transfer does **not** map to Failed.
/// - **R3** — User cancel (system or app cancellation) →
///   [AppError.operationCancelled] (never Failed).
/// - **R4** — Wire `ErrorCode` includes an `unknown` member (4.3) →
///   [AppError.unknown].
/// - **R5** — Channel-layer anomalies (decode failure, missing code,
///   unexpected PlatformException) → [AppError.unknown].
/// - **R6** — Spike name `inCloudUnavailable` is **forbidden** in
///   production contracts.
enum NativeErrorMappingRuleId { r1, r2, r3, r4, r5, r6 }

/// One row of the native error mapping contract table.
final class NativeErrorMappingRule {
  const NativeErrorMappingRule({
    required this.id,
    required this.target,
    required this.summary,
  });

  final NativeErrorMappingRuleId id;

  /// Target [AppError], or `null` for forbid-only rules (R6).
  final AppError? target;

  final String summary;
}

/// Immutable contract table (R1–R6). Not executable Swift mapping.
const List<NativeErrorMappingRule> nativeErrorMappingRules =
    <NativeErrorMappingRule>[
      NativeErrorMappingRule(
        id: NativeErrorMappingRuleId.r1,
        target: AppError.iCloudDownloadRequired,
        summary:
            'PHPhotosError 3164 / network required with '
            'networkAccessAllowed=false → iCloudDownloadRequired',
      ),
      NativeErrorMappingRule(
        id: NativeErrorMappingRuleId.r2,
        target: AppError.iCloudDownloadFailed,
        summary:
            'Network allowed + download entered transfer phase + '
            'non-3164 failure → iCloudDownloadFailed',
      ),
      NativeErrorMappingRule(
        id: NativeErrorMappingRuleId.r3,
        target: AppError.operationCancelled,
        summary: 'User cancel → operationCancelled (never Failed)',
      ),
      NativeErrorMappingRule(
        id: NativeErrorMappingRuleId.r4,
        target: AppError.unknown,
        summary: 'Wire ErrorCode.unknown member → AppError.unknown',
      ),
      NativeErrorMappingRule(
        id: NativeErrorMappingRuleId.r5,
        target: AppError.unknown,
        summary:
            'Channel-layer anomalies (decode / missing code / unexpected '
            'PlatformException) → AppError.unknown',
      ),
      NativeErrorMappingRule(
        id: NativeErrorMappingRuleId.r6,
        target: null,
        summary:
            'Spike name inCloudUnavailable must not appear in production '
            'contracts',
      ),
    ];
