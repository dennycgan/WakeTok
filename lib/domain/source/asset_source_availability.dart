/// Runtime availability of an Asset Source (Glossary §16).
///
/// Distinct from asset-level [AssetAvailability] under `domain/library/`.
enum AssetSourceAvailability {
  available,
  empty,
  unavailable,
  unauthorized,
}
