/// Compares strings so that numbers sort by value: `Ep 2` < `Ep 10`.
/// Case-insensitive.
int compareNatural(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a.toLowerCase()).toList();
  final pb = re.allMatches(b.toLowerCase()).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final x = pa[i].group(0)!;
    final y = pb[i].group(0)!;
    final nx = int.tryParse(x);
    final ny = int.tryParse(y);
    final c = nx != null && ny != null ? nx.compareTo(ny) : x.compareTo(y);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}
