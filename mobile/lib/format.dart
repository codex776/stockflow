// ====================================================================
// Formatting helpers — port of src/ui.js formatters (en-US, USD).
// Note: the public `num()` formatter intentionally shadows the built-in
// `num` type name, so we never reference that type here — parameters
// are `dynamic` with runtime guards instead.
// ====================================================================

double _asDouble(dynamic n) {
  if (n is int) return n.toDouble();
  if (n is double) return n;
  return 0;
}

String money(dynamic n) {
  final v = _asDouble(n);
  final neg = v < 0;
  final abs = v.abs();
  final fixed = abs.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = _group(parts[0]);
  return '${neg ? '-' : ''}\$$whole.${parts[1]}';
}

String money0(dynamic n) {
  final v = _asDouble(n);
  final neg = v < 0;
  final whole = _group(v.abs().round().toString());
  return '${neg ? '-' : ''}\$$whole';
}

String num(dynamic n) => _group(_asDouble(n).round().toString());

String _group(String s) {
  final sb = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) sb.write(',');
    sb.write(s[i]);
  }
  return sb.toString();
}

String dShort(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}';
}

String dMed(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${m[d.month - 1]} ${d.day}, ${d.year}';
}

String dTime(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
}

String dInputVal(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  final y = d.year.toString();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String rel(int ts) {
  final diff = DateTime.now().millisecondsSinceEpoch - ts;
  if (diff < 0) return 'just now';
  final s = diff ~/ 1000;
  if (s < 60) return 'just now';
  final m = s ~/ 60;
  if (m < 60) return '$m min ago';
  final h = m ~/ 60;
  if (h < 24) return '${h}h ago';
  final d = h ~/ 24;
  if (d < 7) return d == 1 ? 'yesterday' : '$d days ago';
  final w = d ~/ 7;
  if (w < 5) return '${w}w ago';
  return dMed(ts);
}

String csvCell(dynamic v) {
  final s = v == null ? '' : v.toString();
  if (s.contains(RegExp(r'[",\n]'))) return '"${s.replaceAll('"', '""')}"';
  return s;
}

String csvRow(List<dynamic> row) => row.map(csvCell).join(',');