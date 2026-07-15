/// Returns the current date/time in Argentina (UTC-3).
/// Argentina does not observe daylight saving time.
DateTime argentinaTime() {
  return DateTime.now().toUtc().subtract(const Duration(hours: 3));
}

/// Formats an Argentina calendar date in yyyy-MM-dd form.
String argFecha(DateTime date) {
  return '${date.year}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Today's Argentina date in yyyy-MM-dd form.
String argTodayFecha() {
  return argFecha(argentinaTime());
}

/// ISO week string for [at] (or today in Argentina time) in `YYYY-WNN` form.
/// Used as the `semana` key on entregas / pagos / carga / resumenes.
String argentinaWeekString({DateTime? at}) {
  final now = at ?? argentinaTime();
  // Use UTC DateTimes so subtraction never crosses a DST boundary on the
  // host system. Argentina itself doesn't observe DST, but tests + dev
  // machines do. Without UTC, a Jan→Mar difference can be 69d23h and
  // round down to the wrong ISO week number.
  final dateOnly = DateTime.utc(now.year, now.month, now.day);
  final monday = dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  final thursday = monday.add(const Duration(days: 3));
  final isoYear = thursday.year;
  final jan4 = DateTime.utc(isoYear, 1, 4);
  final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
  final weekNum = ((monday.difference(week1Monday).inDays) ~/ 7) + 1;
  return '$isoYear-W${weekNum.toString().padLeft(2, '0')}';
}

/// Canonical display-date function for a (semana, diaSemana) pair.
///
/// This uses the ISO 8601 jan-4 rule: week 1 is the week containing jan 4.
/// It matches the date reconstruction already used by historial and detail
/// views. It is not a guaranteed inverse of [argentinaWeekString] until that
/// forward helper is fixed in the later ISO-week wave.
String fechaFromDisplayedSemana(String semana, int diaSemana) {
  if (semana.isEmpty) return '';
  final parts = semana.split('-W');
  if (parts.length != 2) return '';
  final year = int.tryParse(parts[0]);
  final week = int.tryParse(parts[1]);
  if (year == null || week == null) return '';
  if (week < 1 || week > 53) return '';
  if (diaSemana < 0 || diaSemana > 6) return '';
  try {
    // UTC for the same DST-safety reason as argentinaWeekString.
    final jan4 = DateTime.utc(year, 1, 4);
    final monday = jan4
        .subtract(Duration(days: jan4.weekday - 1))
        .add(Duration(days: (week - 1) * 7));
    final fecha = monday.add(Duration(days: diaSemana));
    return '${fecha.year}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}
