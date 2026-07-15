/// Parse a number string supporting both Argentine and standard formats.
///
/// Argentine: period = thousands separator, comma = decimal separator.
///   7.000   → 7000
///   7,50    → 7.50
///   1.500,75 → 1500.75
///
/// When no comma is present, periods are interpreted smartly:
///   7.5     → 7.5   (decimal — not 3 digits after period)
///   7.50    → 7.50  (decimal — not 3 digits after period)
///   7.000   → 7000  (thousands — exactly 3 digits after period)
///   1.500.000 → 1500000 (thousands — all groups are 3 digits)
double? parseArgNumber(String text) {
  var s = text.trim();
  if (s.isEmpty) return null;

  // If comma present: comma is decimal, periods are thousands
  if (s.contains(',')) {
    s = s.replaceAll('.', '');
    s = s.replaceAll(',', '.');
    return double.tryParse(s);
  }

  // No comma — check if periods are thousands separators or decimal
  if (s.contains('.')) {
    final parts = s.split('.');
    // Check if ALL groups after the first have exactly 3 digits → thousands
    final allThousands =
        parts.length > 1 &&
        parts
            .skip(1)
            .every((p) => p.length == 3 && RegExp(r'^\d{3}$').hasMatch(p));
    if (allThousands) {
      // Periods are thousands separators
      s = s.replaceAll('.', '');
      return double.tryParse(s);
    }
    // Otherwise treat the last period as decimal point
    // (e.g. 7.5, 7.50, 1500.75)
  }

  return double.tryParse(s);
}
