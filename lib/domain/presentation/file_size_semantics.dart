/// Cap 8 file-size provenance (ADR-015). Not a kickoff/GLOSSARY term.
///
/// Wire twin: Pigeon [FileSizeSemantics]. Cap 8 host paths use
/// [localVideoUrl] / [currentImageRepresentation] only.
enum FileSizeSemantics {
  primaryResource,
  localVideoUrl,
  currentImageRepresentation,
  unknownUnavailable,
}
