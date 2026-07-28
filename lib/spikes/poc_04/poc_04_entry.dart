/// POC-04 spike entry helpers (debug / dart-define only).
///
/// Launch with spike as home:
///   flutter run --dart-define=POC04_SPIKE=true
///
/// Or in a debug session, use the "POC-04" button on the default home page.
library;

const bool kPoc04SpikeAsHome = bool.fromEnvironment(
  'POC04_SPIKE',
  defaultValue: false,
);
