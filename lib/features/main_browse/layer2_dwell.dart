/// Remaining wait before current-item Layer 2 (Cap 16.4 / ADR-029).
///
/// Clock starts when the item becomes current, not when Layer 1 returns.
Duration remainingLayer2Dwell({
  required Duration n,
  required Duration elapsed,
}) {
  if (n <= Duration.zero || elapsed >= n) {
    return Duration.zero;
  }
  return n - elapsed;
}
