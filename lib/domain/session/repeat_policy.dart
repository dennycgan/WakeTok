/// What happens after the finite Session Queue is exhausted (Glossary §9).
///
/// Independent of [OrderPolicy] and [AdvanceMode]. Cap 12 does not expand
/// Repeat into an infinite list — the Queue stays finite (Glossary §11).
enum RepeatPolicy {
  /// Stop when the current Queue ends.
  stopAtEnd,

  /// After the last item, continue with another round of the same Queue
  /// (or a new shuffle round when Order Policy is Shuffle — Cap 13).
  repeatAll,

  /// Keep repeating the current Media Item.
  repeatOne,
}
