/// Cap 27 / ADR-056: All Snapshot rank map for multi-source newestFirst.
///
/// Rank = index in All coalesced list (`creationDate` descending). First
/// appearance wins on duplicate ids.
Map<String, int> buildAllRankMap(List<String> allCoalescedNewestFirst) {
  final map = <String, int>{};
  for (var i = 0; i < allCoalescedNewestFirst.length; i++) {
    map.putIfAbsent(allCoalescedNewestFirst[i], () => i);
  }
  return map;
}

/// ADR-056 D4 newestFirst over [workingIds] using [allRanks].
///
/// Known ids sorted by ascending rank (newer first), then
/// `localIdentifier` ascending on ties. Unknown ids (defensive only) sorted
/// by id and appended at the end.
List<String> sortWorkingNewestFirstByAllRank({
  required List<String> workingIds,
  required Map<String, int> allRanks,
}) {
  final known = <String>[];
  final unknown = <String>[];
  for (final id in workingIds) {
    if (allRanks.containsKey(id)) {
      known.add(id);
    } else {
      unknown.add(id);
    }
  }
  known.sort((a, b) {
    final byRank = allRanks[a]!.compareTo(allRanks[b]!);
    if (byRank != 0) {
      return byRank;
    }
    return a.compareTo(b);
  });
  unknown.sort();
  return [...known, ...unknown];
}
