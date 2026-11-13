// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversion factors are exact', () {
    expect(lbToKg(1), 0.45359237);
    expect(inToCm(1), 2.54);
    expect(milesToMeters(1), 1609.344);
    expect(kmToMeters(1), 1000);
    expect(kgToLb(0.45359237), closeTo(1, 1e-12));
    expect(cmToIn(2.54), closeTo(1, 1e-12));
    expect(metersToMiles(1609.344), closeTo(1, 1e-12));
    expect(metersToKm(2500), 2.5);
  });

  test('181.8 lb typed is shown as 181.8 lb, and as kg when switched', () {
    final kg = weightToKg(181.8, UnitSystem.imperial);
    expect(formatWeight(kg, UnitSystem.imperial), '181.8');
    expect(formatWeight(kg, UnitSystem.metric), '82.5');
    expect(formatWeight(kg, UnitSystem.imperial), '181.8');
  });

  test('every 0.1 lb from 50.0 to 1,000.0 survives store and display', () {
    for (var i = 500; i <= 10000; i++) {
      final typed = (i / 10).toStringAsFixed(1);
      final value = parseWeight(typed)!;
      final stored = weightToKg(value, UnitSystem.imperial);
      expect(formatWeight(stored, UnitSystem.imperial), typed);
    }
  });

  test('every 0.1 kg from 23.0 to 450.0 survives store and display', () {
    for (var i = 230; i <= 4500; i++) {
      final typed = (i / 10).toStringAsFixed(1);
      final value = parseWeight(typed)!;
      final stored = weightToKg(value, UnitSystem.metric);
      expect(formatWeight(stored, UnitSystem.metric), typed);
    }
  });

  test('switching units twice returns the typed number', () {
    for (var i = 500; i <= 10000; i += 7) {
      final typed = (i / 10).toStringAsFixed(1);
      final stored = weightToKg(parseWeight(typed)!, UnitSystem.imperial);
      formatWeight(stored, UnitSystem.metric); // shown in kg in between
      expect(formatWeight(stored, UnitSystem.imperial), typed);
    }
  });

  test('parseWeight reads typed text', () {
    expect(parseWeight('181.8'), 181.8);
    expect(parseWeight(' 182 '), 182.0);
    expect(parseWeight('181,8'), 181.8);
    expect(parseWeight('.5'), 0.5);
    expect(parseWeight('181.'), 181.0);
    expect(parseWeight('181.84'), 181.8);
    expect(parseWeight('181.85'), 181.9);
  });

  test('parseWeight refuses text that is not a plain positive number', () {
    for (final bad in ['', ' ', '.', 'abc', '-5', '1e3', '1.2.3', '1 000', '+5']) {
      expect(parseWeight(bad), isNull, reason: bad);
    }
  });

  test('range is 50 to 1,000 lb and 23 to 450 kg, inclusive', () {
    expect(weightInRange(50.0, UnitSystem.imperial), isTrue);
    expect(weightInRange(1000.0, UnitSystem.imperial), isTrue);
    expect(weightInRange(49.9, UnitSystem.imperial), isFalse);
    expect(weightInRange(1000.1, UnitSystem.imperial), isFalse);
    expect(weightInRange(23.0, UnitSystem.metric), isTrue);
    expect(weightInRange(450.0, UnitSystem.metric), isTrue);
    expect(weightInRange(22.9, UnitSystem.metric), isFalse);
    expect(weightInRange(450.1, UnitSystem.metric), isFalse);
  });
}
