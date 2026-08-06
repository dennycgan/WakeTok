/// Generation token so in-flight display/playable results for a stale feed
/// index are discarded (Cap 7.5 / W-F7).
class FeedMediaRequestGate {
  int _generation = 0;

  int get generation => _generation;

  /// Bumps generation and returns the new token for the caller to hold.
  int begin() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;
}
