/// POC-09 spike entry helpers (debug / dart-define only).
///
/// Launch with spike as home:
///   flutter run --dart-define=POC09_SPIKE=true
///
/// Or in a debug session, use the "POC-09" button on the default home page.
library;

const bool kPoc09SpikeAsHome = bool.fromEnvironment(
  'POC09_SPIKE',
  defaultValue: false,
);
