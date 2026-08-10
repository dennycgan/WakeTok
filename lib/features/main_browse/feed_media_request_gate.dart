/// Generation token so in-flight display/playable results for a stale feed
/// index are discarded (Cap 7.5 / W-F7).
class FeedMediaRequestGate {
  int _generation = 0;

  int get generation => _generation;

  /// Bumps generation and returns the new token for the caller to hold.
  int begin() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;
}

/// Cap 9.5 / L-S6: apply a bool flag update only when [generation] is current.
///
/// Stale activations must not clear or set Live motion `preparing` (or similar)
/// for a newer activation. Removing the [FeedMediaRequestGate.isCurrent] check
/// makes L-S6-unit fail.
bool gatedFlagUpdate({
  required FeedMediaRequestGate gate,
  required int generation,
  required bool current,
  required bool next,
}) {
  if (!gate.isCurrent(generation)) {
    return current;
  }
  return next;
}
