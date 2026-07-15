/// Money comparisons must tolerate sub-cent float residue. Displays render
/// at integer-peso precision (no decimal places shown), so a stored value
/// like -0.004 would render as "$0" but a direct `cc < 0` check would
/// flag the cliente as deudor. Use these helpers everywhere we compare a
/// money double to zero or to another money value.
///
/// Epsilon = 0.005 (half-cent), chosen to be tighter than the smallest
/// display precision (1 peso, 0 decimal places) so legitimate sub-peso
/// values are normalized but actual debts in pesos are preserved.
const double moneyEpsilon = 0.005;

bool isMoneyEffectivelyZero(double v) => v.abs() < moneyEpsilon;
bool isMoneyPositive(double v) => v >= moneyEpsilon;
bool isMoneyNegative(double v) => v <= -moneyEpsilon;

/// True when [a] and [b] are within epsilon of each other.
bool moneyEquals(double a, double b) => (a - b).abs() < moneyEpsilon;
