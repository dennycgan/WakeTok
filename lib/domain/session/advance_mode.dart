/// How the session advances to the next Media Item (Glossary §9).
///
/// Independent of [OrderPolicy] and [RepeatPolicy]. Cap 12 models the
/// axis only — Auto advance behavior is later Auto-play work.
enum AdvanceMode {
  /// User advances by manual swipe / gesture.
  manual,

  /// Advance automatically when the current video ends.
  auto,
}
