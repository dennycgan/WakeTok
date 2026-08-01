/// Device / iCloud availability for a library asset (Cap 5.4).
///
/// Catalog listing maps only [deviceLocal], [iCloudNotDownloaded], and
/// [unavailable]. [downloading] is reserved for in-flight resource requests
/// and must not be fabricated at list time (decision 2A).
enum AssetAvailability {
  deviceLocal,
  iCloudNotDownloaded,
  downloading,
  unavailable,
}
