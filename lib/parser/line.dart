// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'tokens.dart';

/// A range of characters in the text the user typed: [start] included, [end]
/// not. Always an index into the original text, not the cleaned text.
class Span {
  const Span(this.start, this.end);

  final int start;
  final int end;

  @override
  bool operator ==(Object other) =>
      other is Span && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'Span($start, $end)';
}

/// An item that has been split out of the text and had its amount read, but is
/// not yet matched to a food (grammar 2.2 to 2.7, 3 and 4.1 to 4.3).
class ItemDraft {
  const ItemDraft({
    required this.span,
    required this.foodText,
    required this.hasFoodWords,
    this.quantity,
    this.multiplier,
    this.isRange = false,
    this.unit,
    this.size,
    this.amountSpans = const [],
    this.negationProtected = false,
    String? matchText,
  }) : matchText = matchText ?? foodText;

  /// Where the whole item came from in the typed text.
  final Span span;

  /// The item's words that are not part of its amount, in order, joined by
  /// single spaces. Filler words are kept (the alias match of 6.1 needs "my"),
  /// except filler that comes before the amount. Case is as typed.
  final String foodText;

  /// True when at least one word of [foodText] is not a filler word. An item
  /// with an amount and no food words is "not found" (8.1).
  final bool hasFoodWords;

  /// The quantity after any multiplier, or null when none was typed (the
  /// default amount applies). A size word or a unit followed by "of" with no
  /// number is 1. A range gives its midpoint. A multiplier alone is the
  /// quantity.
  final double? quantity;

  /// The multiplier (`x3`, `2x`) when one was typed. Already in [quantity].
  final double? multiplier;

  /// True when [quantity] is the midpoint of a range (the "Assumed" marker).
  final bool isRange;

  /// The unit as typed, if any. For `oz` the caller decides between weight and
  /// fluid ounces (4.2).
  final UnitDef? unit;

  /// The size word, normalized (`big` is `large`), or null.
  final String? size;

  /// The parts of the text that make up the amount: quantity, size, unit and
  /// multipliers. Adjacent parts are merged. Later tasks use this to rewrite
  /// only the amount in the text (8.3).
  final List<Span> amountSpans;

  /// True when the item's food words include "no" or "without" inside one of
  /// the user's protected names ("No sugar cola"). The matcher then must not
  /// cut the words itself (5.2 step 3, ruling R39): give it [matchText] with
  /// `negation: false`.
  final bool negationProtected;

  /// The food words to match. Same as [foodText], except when
  /// [negationProtected]: then the words are already cut at the first "no" or
  /// "without" that is not inside a protected name, so "no sugar cola without
  /// ice" is "no sugar cola".
  final String matchText;

  /// Whether an amount was typed at all.
  bool get hasAmount => quantity != null;

  @override
  String toString() =>
      'ItemDraft(span: $span, food: "$foodText", '
      'foodWords: $hasFoodWords, quantity: $quantity, multiplier: $multiplier, '
      'range: $isRange, unit: ${unit?.label}, size: $size, '
      'amountSpans: $amountSpans)';
}

/// The state of a line (grammar 8.1). Precedence for the single name used in
/// prose and tests: notFound, aliasOrSavedMeal, guess, amountAssumed, matched.
enum LineState { matched, guess, amountAssumed, notFound, aliasOrSavedMeal }

/// Markers a line can carry (8.1, 8.2). A line can carry several, for example
/// Guess and Assumed.
enum Marker { guess, assumed, yourPick, scanned }

/// One line of a meal, typed or added (8.1, 9.3). Later tasks fill in the food,
/// grams and nutrients; the splitting and amount steps fill [span] and the
/// typed quantity and unit.
class Line {
  const Line({
    required this.state,
    this.foodRef,
    this.foodName,
    this.quantity,
    this.unitLabel,
    this.baseQuantity,
    this.baseUnit,
    this.nutrients = const {},
    this.markers = const {},
    this.learnedKey,
    this.span,
    this.multiplier,
    this.items = const [],
    this.savedMealId,
    this.amountSpans = const [],
    this.foodText,
    this.plain = false,
  });

  final LineState state;

  /// For a typed line: the item's food words as typed, for the not found
  /// sheet's search box (8.3).
  final String? foodText;

  /// True for a not found line that has the cursor in it (9.2): the screen
  /// draws it as plain typing with no marker and does not count it for "Fix N
  /// items" (8.4).
  final bool plain;

  /// The same line with [plain] set.
  Line asPlain() => Line(
    state: state,
    foodRef: foodRef,
    foodName: foodName,
    quantity: quantity,
    unitLabel: unitLabel,
    baseQuantity: baseQuantity,
    baseUnit: baseUnit,
    nutrients: nutrients,
    markers: markers,
    learnedKey: learnedKey,
    span: span,
    multiplier: multiplier,
    items: items,
    savedMealId: savedMealId,
    amountSpans: amountSpans,
    foodText: foodText,
    plain: true,
  );

  /// For a saved meal header: the id of the saved meal it expands.
  final int? savedMealId;

  /// For a typed line: the parts of the typed text that make up the amount
  /// (numbers, unit, size, multiplier), as [ItemDraft.amountSpans], so the
  /// correction sheet can rewrite only the amount (8.3).
  final List<Span> amountSpans;

  /// `usda:<fdc id>` or `local:<id>`. Null when not found.
  final String? foodRef;

  /// The food's name at the time, or the saved meal's name for a header line.
  final String? foodName;

  /// What is stored in `meal_entries` (4.7): the quantity after multipliers and
  /// its unit label (empty string for a bare count).
  final double? quantity;
  final String? unitLabel;

  /// The amount in grams and `g`, or the base amount and unit of a local food.
  final double? baseQuantity;
  final String? baseUnit;

  /// Nutrient id (USDA ids) to the amount for this line, already scaled. For a
  /// saved meal header this is the subtotal of its [items], not an amount of
  /// its own: totals must add the item lines and never the header.
  final Map<int, double> nutrients;

  final Set<Marker> markers;

  /// The key of 7.1 for a line made from typed text.
  final String? learnedKey;

  /// Where the line came from in the typed text. Null for added lines.
  final Span? span;

  /// For a saved meal header (state aliasOrSavedMeal): the multiplier (6.4),
  /// and below it the item lines. Both are unused on other lines. The item
  /// lines are already multiplied by [multiplier] (quantity, base quantity and
  /// nutrients), and they, not the header, count toward the meal total.
  final double? multiplier;
  final List<Line> items;
}
