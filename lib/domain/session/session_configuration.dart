import 'package:waketok/domain/session/advance_mode.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/domain/session/repeat_policy.dart';

/// Immutable three-axis session browse/play configuration (Glossary §9).
///
/// Axes are independent — any [OrderPolicy] × [AdvanceMode] ×
/// [RepeatPolicy] combination is constructible (Cap 12 Q1=A). Cap 12 does
/// not implement Auto-play Preset macros, Eligibility, or Queue building.
class SessionConfiguration {
  const SessionConfiguration({
    required this.orderPolicy,
    required this.advanceMode,
    required this.repeatPolicy,
  });

  final OrderPolicy orderPolicy;
  final AdvanceMode advanceMode;
  final RepeatPolicy repeatPolicy;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SessionConfiguration &&
        other.orderPolicy == orderPolicy &&
        other.advanceMode == advanceMode &&
        other.repeatPolicy == repeatPolicy;
  }

  @override
  int get hashCode => Object.hash(orderPolicy, advanceMode, repeatPolicy);
}
