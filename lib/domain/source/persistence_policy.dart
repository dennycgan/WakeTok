/// Whether a SourcePoolDefinition is a reusable Saved Pool Preset recipe
/// or an ephemeral session recipe (Glossary §6.1 / ADR-020).
///
/// Does **not** mean the Media Item list is frozen — both policies use Live
/// Source Binding on each new Consumption Session.
enum PersistencePolicy {
  ephemeral,
  saved,
}
