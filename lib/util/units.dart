// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Stored values are metric (see docs/data-model.md). These functions convert
// for display and for typing. Display follows the 'units' setting.

const kgPerLb = 0.45359237;
const cmPerIn = 2.54;
const metersPerMile = 1609.344;
const metersPerKm = 1000.0;

enum UnitSystem { imperial, metric }

double lbToKg(double lb) => lb * kgPerLb;
double kgToLb(double kg) => kg / kgPerLb;
double inToCm(double inches) => inches * cmPerIn;
double cmToIn(double cm) => cm / cmPerIn;
double milesToMeters(double miles) => miles * metersPerMile;
double metersToMiles(double meters) => meters / metersPerMile;
double kmToMeters(double km) => km * metersPerKm;
double metersToKm(double meters) => meters / metersPerKm;

/// Rounds to one decimal, the precision weights are typed and shown in.
double roundToTenth(double v) => (v * 10).round() / 10;

/// A weight typed in the display unit, to kilograms for storing.
double weightToKg(double value, UnitSystem units) =>
    units == UnitSystem.imperial ? lbToKg(value) : value;

/// Stored kilograms as a number in the display unit, to one decimal.
double kgToWeight(double kg, UnitSystem units) =>
    roundToTenth(units == UnitSystem.imperial ? kgToLb(kg) : kg);

/// Stored kilograms as the text shown on screen, e.g. '181.8'. No unit word.
String formatWeight(double kg, UnitSystem units) =>
    kgToWeight(kg, units).toStringAsFixed(1);

final _number = RegExp(r'^(\d+\.?\d*|\.\d+)$');

/// Reads a typed weight (a comma counts as the decimal point). Returns the
/// number in the display unit rounded to one decimal, or null if the text is
/// not a plain positive number.
double? parseWeight(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (!_number.hasMatch(t)) return null;
  final v = double.parse(t);
  if (!v.isFinite || v > 100000) return null;
  return roundToTenth(v);
}

/// The accepted range: 50.0 to 1,000.0 lb, which is 22.7 to 453.6 kg as
/// shown, so a weight at either edge is in range in both units. Inclusive.
bool weightInRange(double value, UnitSystem units) =>
    units == UnitSystem.imperial
    ? value >= 50.0 && value <= 1000.0
    : value >= 22.7 && value <= 453.6;
