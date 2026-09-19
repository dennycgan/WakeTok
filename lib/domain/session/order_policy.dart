/// Session order strategy (Glossary §9 Order Policy / ADR-022 / ADR-056).
///
/// Cap 27: `{ newestFirst, oldestFirst, shuffle }` replaces former
/// `sequential`. Three Session Configuration axes remain independent.
enum OrderPolicy {
  /// Global / Snapshot creation-date descending (All-rank for multi-source).
  ///
  /// Single-source: same as former `sequential` (working / coalesced order).
  newestFirst,

  /// Full reverse of [newestFirst] (ADR-056 Decision 2 — one comparator).
  oldestFirst,

  /// Random arrangement of eligible items (Endless Shuffle semantics).
  shuffle,
}
