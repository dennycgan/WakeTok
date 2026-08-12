/// Session order strategy (Glossary §9 Order Policy / ADR-022).
///
/// Three Session Configuration axes are independent; Cap 12 does not
/// validate combinations. Queue construction for [shuffle] is Cap 13
/// (ADR-022 D6).
enum OrderPolicy {
  /// Follow the Resolved Pool Snapshot / Source Reference order.
  sequential,

  /// Random arrangement of eligible items (Endless Shuffle semantics).
  ///
  /// Constructible in Cap 12 so Default Profile derivation (12.3) can
  /// return a type-correct General/Mixed default. Cap 12
  /// `buildSessionQueue` documents a domain refusal for this value
  /// (ADR-022 D6); Cap 13 implements shuffle construction.
  shuffle,
}
