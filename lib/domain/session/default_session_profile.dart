import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/repeat_policy.dart';
import 'package:waketok/domain/session/session_configuration.dart';

/// Kickoff Default Session Profile constants (Glossary §9 / ADR-N / ADR-022).
///
/// Named static fields (same pattern as `PoolCapacity`) so Pure config is
/// unit-testable without a live Pure pool. Cap 12 derivation always selects
/// [generalMixed]; product Main Browse remains Sequential until Cap 13
/// (ADR-022 D2 derive ≠ apply).
abstract final class DefaultSessionProfile {
  /// General / Mixed Pool default.
  static const SessionConfiguration generalMixed = SessionConfiguration(
    orderPolicy: OrderPolicy.shuffle,
    advanceMode: AdvanceMode.manual,
    repeatPolicy: RepeatPolicy.repeatAll,
  );

  /// Pure Generated Clip Pool default (reserved until Generated Clip Cap).
  static const SessionConfiguration pureGeneratedClip = SessionConfiguration(
    orderPolicy: OrderPolicy.sequential,
    advanceMode: AdvanceMode.manual,
    repeatPolicy: RepeatPolicy.repeatAll,
  );
}
