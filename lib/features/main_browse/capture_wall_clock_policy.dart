/// Cap 17.7 capture-wall-clock Overlay settle + bound-reveal policy.
///
/// - Exact stays blank until Host [requestCaptureWallClock] completes.
/// - Host: local EXIF/TIFF first; if nil, one network-allowed retry (iCloud /
///   Optimize Storage). Still nil → epoch→device-TZ fallback (ADR-038).
/// - Do **not** treat a time budget as "give up on EXIF" — a timeout must
///   never lock in fallback and discard a late wall clock.
/// - Presentation: Overlay rows 1–2 share that settle gate (bound reveal;
///   ADR-038 exception to ADR-015 progressive date rows). Row 3 size stays
///   independently progressive. No UI reveal Timer — gate is Host completion
///   only (`exactDateResolved`). Relative math stays Instant vs device now.
library;

// Policy lives in VerticalMediaFeed._resolveCaptureWallClock; this library
// documents the contract for tests and ADR-038 notes.
