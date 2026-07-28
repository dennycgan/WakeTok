/// POC-03 spike entry helpers (debug / dart-define only).
///
/// Launch with spike as home:
///   flutter run --dart-define=POC03_SPIKE=true
///
/// Or in a debug session, use the "POC-03" button on the default home page.
library;

const bool kPoc03SpikeAsHome = bool.fromEnvironment(
  'POC03_SPIKE',
  defaultValue: false,
);
