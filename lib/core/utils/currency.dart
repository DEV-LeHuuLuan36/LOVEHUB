/// Format a numeric VND amount with thousands separators, e.g. 1500000 -> "1,500,000".
String formatVND(num amount) {
  final str = amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '$str VND';
}

/// Same as [formatVND] but with a leading "+" — used for contribution amounts.
String formatVNDWithSign(num amount) {
  final formatted = formatVND(amount.abs());
  return amount >= 0 ? '+$formatted' : '-$formatted';
}
