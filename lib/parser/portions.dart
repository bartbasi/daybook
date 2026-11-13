// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Reading a food's portions (docs/parser-grammar.md section 4.4). It works on a
// plain list of (label, grams) so it serves the USDA reference foods and the
// user's own foods alike. For a user's own food the second number is the
// amount in the food's base unit, not always grams. Pure Dart: this file does
// not import the database code, so the callers map their rows to pairs.

import 'tokens.dart';

/// The FNDDS portion used as the default amount (grammar 4.4). The same text
/// as `defaultPortionLabel` in lib/data/food_reference.dart, which this pure
/// Dart folder cannot import.
const defaultPortionText = 'Quantity not specified';

/// One portion row, read as `<amount> <unit phrase>[, <modifier> | (<note>)]`.
class Portion {
  const Portion({
    required this.label,
    required this.grams,
    required this.amount,
    required this.rest,
    required this.phrase,
    required this.unit,
    required this.unitLead,
    required this.plain,
  });

  /// The label as stored, for example `1 cup, cooked`.
  final String label;

  /// The gram weight of the whole portion (the amount in the food's base unit
  /// for a user's food).
  final double grams;

  /// The leading number, always above zero.
  final double amount;

  /// The label after the amount: `cup, cooked`.
  final String rest;

  /// The unit phrase: the words after the amount up to the first comma or
  /// opening bracket, as written: `medium or regular slice`.
  final String phrase;

  /// The unit when the phrase starts with `fl oz` or its first word is in the
  /// unit tables (4.1), otherwise null. A household word such as `slice` is a
  /// unit of kind count here.
  final UnitDef? unit;

  /// The part of [phrase] that named [unit]: `tablespoon` or `fl oz`.
  final String unitLead;

  /// True when nothing follows the unit phrase.
  final bool plain;

  double get gramsPerUnit => grams / amount;

  /// What a line shows and stores as its unit when this portion is the amount
  /// (4.7): the label after the amount, with a leading unit word written as
  /// the canonical label (`tablespoon` becomes `tbsp`), and any descriptor
  /// kept: `cup, cooked`, `small`, `drink (12 fl oz)`.
  String get unitLabel {
    final u = unit;
    if (u == null) return rest;
    return u.label + rest.substring(unitLead.length);
  }

  /// The lower case words of the unit phrase, split at anything that is not a
  /// letter or digit: `small or thin/very thin slice` gives small, or, thin,
  /// very, thin, slice.
  List<String> get phraseWords => wordsOf(phrase);

  /// True when the unit phrase contains the size word or words [size]
  /// (`extra large` is two words in a row).
  bool phraseHasSize(String size) {
    final want = wordsOf(size);
    final have = phraseWords;
    if (want.isEmpty) return false;
    for (var i = 0; i + want.length <= have.length; i++) {
      var ok = true;
      for (var j = 0; j < want.length; j++) {
        if (have[i + j] != want[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }

  /// True when a word of the unit phrase is a spelling of the household or
  /// count unit [label] (`slice` matches `slices`).
  bool phraseHasUnit(String label) {
    for (final w in phraseWords) {
      final u = unitForWord(w);
      if (u != null && u.label == label) return true;
    }
    return false;
  }

  /// True for a medium or regular portion (4.5 household rule 2).
  bool get isMediumOrRegular =>
      phraseWords.contains('medium') || phraseWords.contains('regular');

  @override
  String toString() => 'Portion($label = $grams)';
}

/// A food's usable portions in the stored order, and its default portion.
class Portions {
  const Portions(this.usable, this.defaultPortion);

  /// Portions with a readable leading number, in the stored (USDA) order.
  final List<Portion> usable;

  /// The row labeled exactly `Quantity not specified`, or null. Its [Portion]
  /// has amount 1 and is never in [usable], so it is never a typed unit.
  final Portion? defaultPortion;

  /// Reads (label, grams) rows given in the stored order (4.4).
  factory Portions.read(List<(String, double)> rows) {
    final usable = <Portion>[];
    Portion? def;
    for (final (label, grams) in rows) {
      final trimmed = label.trim();
      if (trimmed == defaultPortionText) {
        def ??= Portion(
          label: trimmed,
          grams: grams,
          amount: 1,
          rest: trimmed,
          phrase: trimmed,
          unit: null,
          unitLead: '',
          plain: true,
        );
        continue;
      }
      final p = readPortion(label, grams);
      if (p != null) usable.add(p);
    }
    return Portions(usable, def);
  }

  /// True when some usable portion has the unit `fl oz` (4.2: then a typed
  /// `oz` is a fluid ounce).
  bool get hasFluidOunce => usable.any((p) => p.unit?.label == 'fl oz');
}

final _amountRe = RegExp(r'^(\d+\s+\d+/\d+|\d+/\d+|\d*\.\d+|\d+)(?=\s|$)');
final _flOzRe = RegExp(r'^fl\.?\s*oz\b\.?', caseSensitive: false);

/// Reads one portion label. Null when the label does not start with a number
/// followed by a space or the end (`Skin from 1 medium`, `1-3 ring thin
/// pretzel`, `Quantity not specified, if appetizer`), when the amount is zero
/// or has a zero denominator, or when the weight is below zero.
Portion? readPortion(String label, double grams) {
  final text = label.trim();
  final m = _amountRe.firstMatch(text);
  if (m == null || grams < 0) return null;
  final amount = _amountOf(m.group(1)!);
  if (amount == null || amount <= 0) return null;
  final rest = text.substring(m.end).trim();
  final cut = rest.indexOf(RegExp(r'[,(]'));
  final phrase = (cut < 0 ? rest : rest.substring(0, cut)).trim();
  final plain = cut < 0;

  UnitDef? unit;
  var lead = '';
  final fl = _flOzRe.firstMatch(phrase);
  if (fl != null) {
    unit = unitForWord('fl oz');
    lead = fl.group(0)!;
  } else if (phrase.isNotEmpty) {
    final first = phrase.split(RegExp(r'\s+')).first;
    final word = first.replaceAll(RegExp(r'[^A-Za-z]+$'), '');
    if (word.length > 1) {
      unit = unitForWord(word.toLowerCase());
      if (unit != null) lead = word;
    }
  }
  return Portion(
    label: text,
    grams: grams,
    amount: amount,
    rest: rest,
    phrase: phrase,
    unit: unit,
    unitLead: lead,
    plain: plain,
  );
}

double? _amountOf(String s) {
  final parts = s.split(RegExp(r'\s+'));
  var total = 0.0;
  for (final part in parts) {
    final v = _numberOf(part);
    if (v == null) return null;
    total += v;
  }
  return total;
}

double? _numberOf(String s) {
  final slash = s.indexOf('/');
  if (slash < 0) return double.tryParse(s);
  final n = double.tryParse(s.substring(0, slash));
  final d = double.tryParse(s.substring(slash + 1));
  if (n == null || d == null || d == 0) return null;
  return n / d;
}

/// Lower case words made of letters and digits.
List<String> wordsOf(String s) => [
  for (final w in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (w.isNotEmpty) w,
];

Map<String, UnitDef>? _units;

/// The unit a lower case word spells, or null. Reads the tables of 4.1 for
/// spellings longer than one letter (a single letter in a label is not a
/// unit). `fl oz` is found by that exact text. The household and count units
/// come with `s` and `es`.
UnitDef? unitForWord(String word) {
  final map = _units ??= _buildUnits();
  return map[word];
}

Map<String, UnitDef> _buildUnits() {
  final map = <String, UnitDef>{};
  for (final e in unitTable) {
    for (final s in e.spellings) {
      if (s.length < 2) continue;
      map[s.toLowerCase().replaceAll('.', '').replaceAll(RegExp(r'\s+'), ' ')] =
          e.def;
    }
  }
  for (final (label, extras) in householdUnits) {
    final def = UnitDef(label, UnitKind.count, 0);
    for (final s in [label, ...extras]) {
      map[s] = def;
      map['${s}s'] = def;
      map['${s}es'] = def;
    }
    final irregular = householdIrregularPlurals[label];
    if (irregular != null) map[irregular] = def;
  }
  return map;
}
