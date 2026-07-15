String formatPackQty(int rawUnits, int? packSize) {
  if (rawUnits == 0) return '0';
  if (rawUnits < 0) return '$rawUnits';
  if (packSize == null || packSize < 2) return '$rawUnits';
  if (rawUnits % packSize == 0) return '(${rawUnits ~/ packSize})';
  return '(${rawUnits ~/ packSize}) +${rawUnits % packSize}';
}
