/// Cap 6 / ADR-013 All-only quantile indices on an ordered resolve list.
List<int> builtinAllQuantileIndices(int length) {
  if (length <= 0) {
    return const <int>[];
  }
  if (length == 1) {
    return const <int>[0];
  }
  final last = length - 1;
  final raw = <int>{
    0,
    (last * 0.25).floor(),
    (last * 0.50).floor(),
    (last * 0.75).floor(),
    last,
  };
  final sorted = raw.toList()..sort();
  return sorted;
}
