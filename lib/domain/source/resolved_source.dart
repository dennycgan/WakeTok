/// Result of resolving an Asset Source to ordered asset identifiers (D1=A).
class ResolvedSource {
  const ResolvedSource({
    required this.sourceId,
    required this.assetIdentifiers,
  });

  /// Echo of the resolved source id (built-in short id or album local id).
  final String sourceId;

  /// Full ordered list (creationDate descending on host). May be large (~40k).
  final List<String> assetIdentifiers;
}
