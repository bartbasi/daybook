// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The 88 worked examples of docs/parser-grammar.md section 11.2, as plain
// data, with the fixtures of section 11.1. Nothing here depends on parser
// code. Each row is copied from the grammar's table; a field the example does
// not give is left null. No number is calculated here.
//
// How to check a row by eye: example N below is row N of section 11.2.
// "1." lines in the grammar are the first entry of `lines`; "1a." and "1b."
// are the `items` of a saved meal header.

/// The line states of grammar 8.1.
enum ExpectedState { matched, guess, amountAssumed, notFound, aliasOrSavedMeal }

/// The markers of grammar 8.2 that can sit on a line. "Not found" is a state,
/// not a marker here.
enum ExpectedMarker { guess, assumed, yourPick, scanned }

/// Where a default amount comes from (grammar 4.6).
enum DefaultSource {
  /// Marked "(default)": the FNDDS "Quantity not specified" portion (rule 2).
  notSpecified,

  /// Marked "(default rule 4)": the first portion that is neither mass nor
  /// volume.
  rule4,

  /// Marked "(learned)": the amount stored on a learned row (rule 1).
  learned,
}

/// A portion of the food that an example names, for example
/// `"1 cup, cooked" = 240 g`. Either part can be missing when the example
/// does not give it.
class ExpectedPortion {
  const ExpectedPortion({this.label, this.grams, this.converted = false});

  /// The portion label as the grammar prints it, for example '1 cup, cooked'.
  final String? label;

  /// The gram weight of one such portion.
  final double? grams;

  /// True when the line's unit differs from the portion and the grams come
  /// from converting (a tablespoon amount "from 1 cup = 240 g"). The grams of
  /// the line are then not a simple multiple of this portion.
  final bool converted;
}

/// One expected line, in the order the grammar lists them.
class ExpectedLine {
  const ExpectedLine(
    this.state, {
    this.markers = const {},
    this.ref,
    this.name,
    this.text,
    this.quantity,
    this.unit,
    this.grams,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.defaultSource,
    this.defaultGrams,
    this.portion,
    this.savedMeal,
    this.multiplier,
    this.items,
    this.plain = false,
  });

  final ExpectedState state;

  /// The markers the line shows: Guess, Assumed, Your pick, Scanned. "guess"
  /// in the grammar means state guess with the Guess marker; "guess, amount
  /// assumed" means both markers.
  final Set<ExpectedMarker> markers;

  /// 'usda:(fdc id)' or 'local:(id)'. Null for a not found line.
  final String? ref;

  /// The food name where the example prints it.
  final String? name;

  /// The typed text of a not found line.
  final String? text;

  /// The quantity as printed (2, 1.5, 0.5, 200 for "200 g").
  final double? quantity;

  /// The unit as printed ('slice', 'cup', 'fl oz', 'g', 'small', 'large',
  /// 'cup, cooked'); null for a bare count.
  final String? unit;

  final double? grams;
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// Set when the amount is marked "(default)", "(default rule 4)" or
  /// "(learned)".
  final DefaultSource? defaultSource;

  /// For "(default)": the gram weight of the "Quantity not specified"
  /// portion, as printed next to the mark (a line of "0.5 x 105 g (default)"
  /// has 105 here and 52.5 in [grams]).
  final double? defaultGrams;

  /// A portion the example names for this line's amount.
  final ExpectedPortion? portion;

  /// For a saved meal header: the name, the multiplier, and the item lines
  /// ("1a.", "1b."). [kcal] on a header is its subtotal.
  final String? savedMeal;
  final double? multiplier;
  final List<ExpectedLine>? items;

  /// True when the line is drawn as plain typing (a half-typed last item).
  final bool plain;
}

/// A saved meal item of the fixtures in 11.1.
class SavedMealItemFixture {
  const SavedMealItemFixture({
    required this.quantity,
    this.unit,
    required this.ref,
    this.name,
    required this.grams,
    required this.kcal,
  });
  final double quantity;
  final String? unit;
  final String ref;
  final String? name;
  final double grams;
  final double kcal;
}

class SavedMealFixture {
  const SavedMealFixture({
    required this.name,
    this.alias,
    this.items = const [],
  });
  final String name;
  final String? alias;

  /// Empty when the grammar says the items do not matter.
  final List<SavedMealItemFixture> items;
}

class UserFoodFixture {
  const UserFoodFixture({
    required this.ref,
    required this.name,
    required this.kind,
    required this.baseUnit,
    this.kcalPerServing,
    this.portionLabel,
    this.portionGrams,
  });
  final String ref;
  final String name;

  /// 'recipe' or 'custom food'.
  final String kind;
  final String baseUnit;
  final double? kcalPerServing;
  final String? portionLabel;
  final double? portionGrams;
}

/// A learned match row: the key, the food, and an optional learned amount.
class LearnedFixture {
  const LearnedFixture({
    required this.phrase,
    required this.ref,
    this.quantity,
    this.unit,
  });
  final String phrase;
  final String ref;
  final double? quantity;
  final String? unit;
}

/// Which fixtures an example needs. Everything not listed is absent: no
/// history, no learned matches, no aliases, no saved meals, no user foods.
class ExampleSetup {
  const ExampleSetup({
    this.savedMeals = const [],
    this.userFoods = const [],
    this.learned = const [],
    this.history = const {},
    this.cursorAtEnd = false,
  });

  /// Names of saved meals (and so their aliases) that are in place.
  final List<String> savedMeals;

  /// Refs of user foods that are in place.
  final List<String> userFoods;
  final List<LearnedFixture> learned;

  /// food ref to the number of times it was logged.
  final Map<String, int> history;

  /// True when the example depends on the cursor being at the end of the
  /// text (example 62). Otherwise the cursor does not matter.
  final bool cursorAtEnd;
}

/// A second result the grammar gives for the same input under other fixtures.
class ExampleVariant {
  const ExampleVariant(this.description, this.setup, this.lines);
  final String description;
  final ExampleSetup setup;
  final List<ExpectedLine> lines;
}

class WorkedExample {
  const WorkedExample(
    this.number,
    this.input, {
    this.alternateInputs = const [],
    this.setup = const ExampleSetup(),
    this.lines = const [],
    this.mealKcal,
    this.variants = const [],
  });
  final int number;
  final String input;

  /// Other inputs the grammar gives for the same expected result (63).
  final List<String> alternateInputs;
  final ExampleSetup setup;

  /// The expected lines in order. Empty means the example expects no lines
  /// (63). A saved meal header counts as one line, its items are inside it.
  final List<ExpectedLine> lines;

  /// "Meal total" where the grammar prints one.
  final double? mealKcal;
  final List<ExampleVariant> variants;

  /// The lines with each header's items following it, in screen order.
  List<ExpectedLine> get flatLines => [
    for (final l in lines) ...[l, ...?l.items],
  ];
}

// Short names so a row reads like the grammar's.
const _matched = ExpectedState.matched;
const _guess = ExpectedState.guess;
const _assumed = ExpectedState.amountAssumed;
const _notFound = ExpectedState.notFound;
const _saved = ExpectedState.aliasOrSavedMeal;

const _mGuess = {ExpectedMarker.guess};
const _mAssumed = {ExpectedMarker.assumed};
const _mBoth = {ExpectedMarker.guess, ExpectedMarker.assumed};

const _dflt = DefaultSource.notSpecified;

// Foods that come up again and again.
const _egg = 'usda:2707153';
const _bread = 'usda:2707647'; // Bread, sour dough, toasted
const _coffee = 'usda:2710373';
const _milk = 'usda:2705384';
const _banana = 'usda:2709224';
const _butter = 'usda:2710154';
const _chicken = 'usda:2705929';
const _rice = 'usda:2708402';
const _oatmeal = 'usda:2708380';
const _honey = 'usda:2710281';
const _peanutButter = 'usda:2707537';
const _toastNs = 'usda:2707592';
const _cream = 'usda:2705594';
const _almonds = 'usda:2707485';
const _chickenBreast = 'usda:2705953';

const _egg1Name = 'Egg, whole, cooked, NS as to cooking method';

// Fixtures of 11.1

const savedMealFixtures = <SavedMealFixture>[
  SavedMealFixture(
    name: 'Usual breakfast',
    alias: 'usual breakfast',
    items: [
      SavedMealItemFixture(
        quantity: 2,
        unit: 'egg',
        ref: _egg,
        grams: 100,
        kcal: 176,
      ),
      SavedMealItemFixture(
        quantity: 1,
        unit: 'slice',
        ref: _bread,
        grams: 28,
        kcal: 83.7,
      ),
    ],
  ),
  SavedMealFixture(
    name: 'My oatmeal',
    alias: 'my oatmeal',
    items: [
      SavedMealItemFixture(
        quantity: 1,
        unit: 'cup',
        ref: _oatmeal,
        grams: 240,
        kcal: 182.4,
      ),
      SavedMealItemFixture(
        quantity: 1,
        unit: 'tbsp',
        ref: 'usda:2710281',
        name: 'Honey',
        grams: 20,
        kcal: 60.8,
      ),
    ],
  ),
  // A saved meal name with no alias. Its items do not matter for the test.
  SavedMealFixture(name: 'Eggs and toast'),
];

const userFoodFixtures = <UserFoodFixture>[
  UserFoodFixture(
    ref: 'local:1',
    name: 'Turkey chili',
    kind: 'recipe',
    baseUnit: 'serving',
    kcalPerServing: 420,
  ),
  UserFoodFixture(
    ref: 'local:2',
    name: 'Peanut butter cookies',
    kind: 'custom food',
    baseUnit: 'g',
    portionLabel: '1 cookie',
    portionGrams: 20,
  ),
];

/// Learned rows used by examples 51 and 52.
const learnedToastNoAmount = LearnedFixture(
  phrase: 'toast',
  ref: 'usda:2707756',
);
const learnedToastTwoSlices = LearnedFixture(
  phrase: 'toast',
  ref: 'usda:2707756',
  quantity: 2,
  unit: 'slice',
);

const _savedMealsFor47To50 = [
  'Usual breakfast',
  'My oatmeal',
  'Eggs and toast',
];
const _bothUserFoods = ['local:1', 'local:2'];

// Example 1, reused by example 2

const _example1Lines = <ExpectedLine>[
  ExpectedLine(
    _matched,
    ref: _egg,
    name: _egg1Name,
    quantity: 2,
    portion: ExpectedPortion(label: '1 egg', grams: 50),
    grams: 100,
    kcal: 176,
    protein: 11.8,
    carbs: 0.9,
    fat: 13.9,
  ),
  ExpectedLine(
    _matched,
    ref: _bread,
    name: 'Bread, sour dough, toasted',
    quantity: 2,
    unit: 'slice',
    grams: 56,
    kcal: 167,
    protein: 6.6,
    carbs: 31.9,
    fat: 1.5,
  ),
  ExpectedLine(
    _matched,
    ref: _butter,
    name: 'Butter, NFS',
    quantity: 1,
    unit: 'tbsp',
    grams: 14,
    kcal: 104,
    protein: 0.1,
    carbs: 0.0,
    fat: 11.5,
  ),
  ExpectedLine(
    _assumed,
    markers: _mAssumed,
    ref: _coffee,
    name: 'Coffee, NS as to type',
    quantity: 1,
    unit: 'small',
    defaultSource: _dflt,
    defaultGrams: 360,
    grams: 360,
    kcal: 4,
    protein: 0.4,
    carbs: 0.0,
    fat: 0.1,
  ),
  ExpectedLine(
    _guess,
    markers: _mGuess,
    ref: _cream,
    name: 'Cream, half and half',
    quantity: 2,
    unit: 'tbsp',
    portion: ExpectedPortion(label: '1 cup', grams: 240, converted: true),
    grams: 30,
    kcal: 39,
    protein: 0.9,
    carbs: 1.3,
    fat: 3.5,
  ),
];

// Lines that several examples share word for word.
const _coffeeDefault = ExpectedLine(
  _assumed,
  markers: _mAssumed,
  ref: _coffee,
  quantity: 1,
  unit: 'small',
  defaultSource: _dflt,
  defaultGrams: 360,
  grams: 360,
  kcal: 4,
);
const _egg2 = ExpectedLine(
  _matched,
  ref: _egg,
  quantity: 2,
  grams: 100,
  kcal: 176,
);
const _banana1 = ExpectedLine(
  _matched,
  ref: _banana,
  quantity: 1,
  grams: 126,
  kcal: 122,
);
const _milk15Cup = ExpectedLine(
  _matched,
  ref: _milk,
  quantity: 1.5,
  unit: 'cup',
  grams: 366,
  kcal: 190,
);
const _milkHalfCup = ExpectedLine(
  _matched,
  ref: _milk,
  quantity: 0.5,
  unit: 'cup',
  grams: 122,
  kcal: 63,
);
const _chicken200g = ExpectedLine(
  _matched,
  ref: _chicken,
  quantity: 200,
  unit: 'g',
  grams: 200,
  kcal: 328,
);
const _rice1Cup = ExpectedLine(
  _matched,
  ref: _rice,
  quantity: 1,
  unit: 'cup',
  grams: 158,
  kcal: 204,
);

// The 88 examples

const workedExamples = <WorkedExample>[
  // 1
  WorkedExample(
    1,
    '2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp half and half',
    lines: _example1Lines,
    mealKcal: 490,
  ),
  // 2: the same 5 lines as example 1
  WorkedExample(
    2,
    'two eggs two slices of sourdough toast one tablespoon of butter and coffee with two tablespoons of half and half',
    lines: _example1Lines,
    mealKcal: 490,
  ),
  // 3
  WorkedExample(
    3,
    '2 tbsp half and half',
    setup: ExampleSetup(history: {_cream: 1}),
    lines: [
      ExpectedLine(
        _matched,
        ref: _cream,
        quantity: 2,
        unit: 'tbsp',
        grams: 30,
        kcal: 39,
      ),
    ],
  ),
  // 4
  WorkedExample(
    4,
    '2 eggs and toast',
    lines: [
      _egg2,
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _toastNs,
        name: 'Bread, NS as to major flour, toasted',
        quantity: 1,
        unit: 'medium or regular slice',
        defaultSource: _dflt,
        defaultGrams: 25,
        grams: 25,
        kcal: 73,
      ),
    ],
  ),
  // 5
  WorkedExample(
    5,
    'half and half',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: _cream,
        name: 'Cream, half and half',
        quantity: 20,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 20,
        grams: 20,
        kcal: 26,
      ),
    ],
  ),
  // 6
  WorkedExample(
    6,
    'mac and cheese',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2708811',
        name: 'Macaroni or noodles with cheese',
        quantity: 1,
        unit: 'cup',
        defaultSource: _dflt,
        defaultGrams: 230,
        grams: 230,
        kcal: 513,
      ),
    ],
  ),
  // 7
  WorkedExample(
    7,
    'peanut butter and jelly sandwich',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2707554',
        name: 'Peanut butter and jelly sandwich, NFS',
        quantity: 1,
        unit: 'sandwich',
        defaultSource: _dflt,
        defaultGrams: 112,
        grams: 112,
        kcal: 404,
      ),
    ],
  ),
  // 8
  WorkedExample(
    8,
    'rice and beans',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2708990',
        name: 'Beans and white rice',
        quantity: 1,
        unit: 'cup',
        defaultSource: _dflt,
        defaultGrams: 170,
        grams: 170,
        kcal: 279,
      ),
    ],
  ),
  // 9
  WorkedExample(
    9,
    'chicken and rice',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _chicken,
        name: 'Chicken, NS as to part and cooking method, NS as to skin eaten',
        quantity: 85,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 85,
        grams: 85,
        kcal: 139,
      ),
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _rice,
        name: 'Rice, cooked, NFS',
        quantity: 118,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 118,
        grams: 118,
        kcal: 152,
      ),
    ],
  ),
  // 10
  WorkedExample(
    10,
    'chicken with broccoli',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _chicken,
        quantity: 85,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 85,
        grams: 85,
        kcal: 139,
      ),
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2709647',
        name: 'Broccoli, NS as to form, cooked',
        quantity: 80,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 80,
        grams: 80,
        kcal: 50,
      ),
    ],
  ),
  // 11
  WorkedExample(
    11,
    'coffee with milk',
    lines: [
      _coffeeDefault,
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _milk,
        name: 'Milk, NFS',
        quantity: 1,
        unit: 'cup',
        defaultSource: _dflt,
        defaultGrams: 244,
        grams: 244,
        kcal: 127,
      ),
    ],
  ),
  // 12
  WorkedExample(
    12,
    'coffee w/ cream & sugar',
    lines: [
      _coffeeDefault,
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2705629',
        name: 'Ice cream, NFS',
        quantity: 1,
        unit: 'cup',
        defaultSource: _dflt,
        defaultGrams: 135,
        grams: 135,
        kcal: 298,
      ),
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2710257',
        name: 'Sugar, NFS',
        quantity: 8,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 8,
        grams: 8,
        kcal: 32,
      ),
    ],
  ),
  // 13
  WorkedExample(
    13,
    'gin and tonic',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2710633',
        name: 'Gin and tonic',
        quantity: 1,
        unit: 'drink',
        defaultSource: _dflt,
        defaultGrams: 225,
        grams: 225,
        kcal: 189,
      ),
    ],
  ),
  // 14
  WorkedExample(
    14,
    'oatmeal made with milk',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _oatmeal,
        name: 'Oatmeal, NFS',
        quantity: 1,
        unit: 'cup, cooked',
        defaultSource: _dflt,
        defaultGrams: 240,
        grams: 240,
        kcal: 182,
      ),
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _milk,
        quantity: 1,
        unit: 'cup',
        defaultSource: _dflt,
        defaultGrams: 244,
        grams: 244,
        kcal: 127,
      ),
    ],
  ),
  // 15
  WorkedExample(
    15,
    'burger and fries',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2706920',
        name: 'Hamburger, NFS',
        quantity: 1,
        unit: 'hamburger',
        defaultSource: _dflt,
        defaultGrams: 145,
        grams: 145,
        kcal: 418,
      ),
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2709456',
        name: 'Potato, french fries, NFS',
        quantity: 110,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 110,
        grams: 110,
        kcal: 248,
      ),
    ],
  ),
  // 16
  WorkedExample(
    16,
    '1 and 1/2 cups oatmeal',
    lines: [
      ExpectedLine(
        _matched,
        ref: _oatmeal,
        quantity: 1.5,
        unit: 'cup',
        portion: ExpectedPortion(label: '1 cup, cooked', grams: 240),
        grams: 360,
        kcal: 274,
      ),
    ],
  ),
  // 17
  WorkedExample(17, 'one and a half cups of milk', lines: [_milk15Cup]),
  // 18
  WorkedExample(18, 'a cup and a half of milk', lines: [_milk15Cup]),
  // 19
  WorkedExample(19, '1½ cups milk', lines: [_milk15Cup]),
  // 20
  WorkedExample(20, '1-1/2 cups milk', lines: [_milk15Cup]),
  // 21
  WorkedExample(21, '1 1/2 cups milk', lines: [_milk15Cup]),
  // 22
  WorkedExample(
    22,
    'three quarters of a cup of milk',
    lines: [
      ExpectedLine(
        _matched,
        ref: _milk,
        quantity: 0.75,
        unit: 'cup',
        grams: 183,
        kcal: 95,
      ),
    ],
  ),
  // 23
  WorkedExample(
    23,
    '.5 cup almonds',
    lines: [
      ExpectedLine(
        _matched,
        ref: _almonds,
        name: 'Almonds, NFS',
        quantity: 0.5,
        unit: 'cup',
        grams: 70.5,
        kcal: 422,
      ),
    ],
  ),
  // 24: "0.5 x 105 g (default)"
  WorkedExample(
    24,
    'half a bagel',
    lines: [
      ExpectedLine(
        _matched,
        ref: 'usda:2707684',
        name: 'Bagel',
        quantity: 0.5,
        defaultSource: _dflt,
        defaultGrams: 105,
        grams: 52.5,
        kcal: 139,
      ),
    ],
  ),
  // 25
  WorkedExample(25, 'a couple of eggs', lines: [_egg2]),
  // 26: "1 x 200 g (default)"
  WorkedExample(
    26,
    'an apple',
    lines: [
      ExpectedLine(
        _matched,
        ref: 'usda:2709215',
        name: 'Apple, raw',
        quantity: 1,
        defaultSource: _dflt,
        defaultGrams: 200,
        grams: 200,
        kcal: 122,
      ),
    ],
  ),
  // 27
  WorkedExample(
    27,
    'eggs x3',
    lines: [
      ExpectedLine(_matched, ref: _egg, quantity: 3, grams: 150, kcal: 264),
    ],
  ),
  // 28
  WorkedExample(
    28,
    '2x 100g chicken breast',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: _chickenBreast,
        name: 'Chicken breast, NS as to cooking method, skin eaten',
        quantity: 200,
        unit: 'g',
        grams: 200,
        kcal: 350,
      ),
    ],
  ),
  // 29
  WorkedExample(
    29,
    '2-3 eggs',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _egg,
        quantity: 2.5,
        grams: 125,
        kcal: 220,
      ),
    ],
  ),
  // 30
  WorkedExample(
    30,
    'chicken breast 6 oz',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: _chickenBreast,
        quantity: 6,
        unit: 'oz',
        grams: 170.1,
        kcal: 298,
      ),
    ],
  ),
  // 31
  WorkedExample(
    31,
    '8 oz milk',
    lines: [
      ExpectedLine(
        _matched,
        ref: _milk,
        quantity: 8,
        unit: 'fl oz',
        grams: 244,
        kcal: 127,
      ),
    ],
  ),
  // 32
  WorkedExample(
    32,
    '3 oz salmon',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: 'usda:2706285',
        name: 'Fish, salmon, NFS',
        quantity: 3,
        unit: 'oz',
        grams: 85,
        kcal: 233,
      ),
    ],
  ),
  // 33
  WorkedExample(
    33,
    '1 T peanut butter, 1 t honey',
    lines: [
      ExpectedLine(
        _matched,
        ref: _peanutButter,
        name: 'Peanut butter',
        quantity: 1,
        unit: 'tbsp',
        grams: 16,
        kcal: 96,
      ),
      ExpectedLine(
        _matched,
        ref: _honey,
        name: 'Honey',
        quantity: 1,
        unit: 'tsp',
        portion: ExpectedPortion(
          label: '1 tablespoon',
          grams: 20,
          converted: true,
        ),
        grams: 6.7,
        kcal: 20,
      ),
    ],
  ),
  // 34
  WorkedExample(
    34,
    '2c rice',
    lines: [
      ExpectedLine(
        _matched,
        ref: _rice,
        quantity: 2,
        unit: 'cup',
        portion: ExpectedPortion(label: '1 cup, cooked', grams: 158),
        grams: 316,
        kcal: 408,
      ),
    ],
  ),
  // 35
  WorkedExample(
    35,
    '500 ml milk',
    lines: [
      ExpectedLine(
        _matched,
        ref: _milk,
        quantity: 500,
        unit: 'ml',
        portion: ExpectedPortion(label: '1 cup', grams: 244, converted: true),
        grams: 515.7,
        kcal: 268,
      ),
    ],
  ),
  // 36
  WorkedExample(
    36,
    'a large coffee',
    lines: [
      ExpectedLine(
        _matched,
        ref: _coffee,
        quantity: 1,
        unit: 'large',
        grams: 600,
        kcal: 6,
      ),
    ],
  ),
  // 37
  WorkedExample(
    37,
    'large coffee',
    lines: [
      ExpectedLine(
        _matched,
        ref: _coffee,
        quantity: 1,
        unit: 'large',
        grams: 600,
        kcal: 6,
      ),
    ],
  ),
  // 38: "2 (1 egg)"
  WorkedExample(
    38,
    '2 large eggs',
    lines: [
      ExpectedLine(
        _matched,
        ref: _egg,
        quantity: 2,
        portion: ExpectedPortion(label: '1 egg'),
        grams: 100,
        kcal: 176,
      ),
    ],
  ),
  // 39
  WorkedExample(
    39,
    '3 thick slices toast',
    lines: [
      ExpectedLine(
        _matched,
        ref: _toastNs,
        quantity: 3,
        unit: 'slice',
        portion: ExpectedPortion(label: '1 large or thick slice', grams: 39),
        grams: 117,
        kcal: 343,
      ),
    ],
  ),
  // 40: "1 tbsp (default 14 g)"
  WorkedExample(
    40,
    '2 slices butter',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _butter,
        quantity: 1,
        unit: 'tbsp',
        defaultSource: _dflt,
        defaultGrams: 14,
        grams: 14,
        kcal: 104,
      ),
    ],
  ),
  // 41
  WorkedExample(
    41,
    '1 bowl of oatmeal',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _oatmeal,
        quantity: 1,
        unit: 'cup, cooked',
        defaultSource: _dflt,
        defaultGrams: 240,
        grams: 240,
        kcal: 182,
      ),
    ],
  ),
  // 42
  WorkedExample(
    42,
    '2 bananna',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: _banana,
        name: 'Banana, raw',
        quantity: 2,
        portion: ExpectedPortion(label: '1 banana', grams: 126),
        grams: 252,
        kcal: 244,
      ),
    ],
  ),
  // 43
  WorkedExample(
    43,
    'I had two eggs and a banana',
    lines: [
      _egg2,
      ExpectedLine(
        _matched,
        ref: _banana,
        quantity: 1,
        portion: ExpectedPortion(label: '1 banana', grams: 126),
        grams: 126,
        kcal: 122,
      ),
    ],
  ),
  // 44
  WorkedExample(
    44,
    'chicken 200g rice 1 cup',
    lines: [_chicken200g, _rice1Cup],
  ),
  // 45
  WorkedExample(
    45,
    '2 eggs. coffee',
    lines: [
      ExpectedLine(_matched, ref: _egg, grams: 100, kcal: 176),
      _coffeeDefault,
    ],
  ),
  // 46: new line, then semicolon
  WorkedExample(
    46,
    '2 eggs\n1 banana; black coffee',
    lines: [
      ExpectedLine(_matched, ref: _egg, grams: 100),
      ExpectedLine(_matched, ref: _banana, grams: 126),
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _coffee,
        quantity: 1,
        unit: 'small',
        defaultSource: _dflt,
        defaultGrams: 360,
        grams: 360,
      ),
    ],
  ),
  // 47
  WorkedExample(
    47,
    'usual breakfast',
    setup: ExampleSetup(savedMeals: _savedMealsFor47To50),
    lines: [
      ExpectedLine(
        _saved,
        savedMeal: 'Usual breakfast',
        multiplier: 1,
        kcal: 260,
        items: [
          ExpectedLine(_matched, ref: _egg, quantity: 2, grams: 100, kcal: 176),
          ExpectedLine(
            _matched,
            ref: _bread,
            quantity: 1,
            unit: 'slice',
            grams: 28,
            kcal: 84,
          ),
        ],
      ),
    ],
  ),
  // 48
  WorkedExample(
    48,
    'half usual breakfast, coffee',
    setup: ExampleSetup(savedMeals: _savedMealsFor47To50),
    lines: [
      ExpectedLine(
        _saved,
        savedMeal: 'Usual breakfast',
        multiplier: 0.5,
        kcal: 130,
        items: [
          ExpectedLine(_matched, ref: _egg, quantity: 1, grams: 50, kcal: 88),
          ExpectedLine(
            _matched,
            ref: _bread,
            quantity: 0.5,
            unit: 'slice',
            grams: 14,
            kcal: 42,
          ),
        ],
      ),
      _coffeeDefault,
    ],
  ),
  // 49
  WorkedExample(
    49,
    '2 my oatmeal',
    setup: ExampleSetup(savedMeals: _savedMealsFor47To50),
    lines: [
      ExpectedLine(
        _saved,
        savedMeal: 'My oatmeal',
        multiplier: 2,
        kcal: 486,
        items: [
          ExpectedLine(
            _matched,
            ref: _oatmeal,
            quantity: 2,
            unit: 'cup',
            grams: 480,
            kcal: 365,
          ),
          ExpectedLine(
            _matched,
            ref: _honey,
            quantity: 2,
            unit: 'tbsp',
            grams: 40,
            kcal: 122,
          ),
        ],
      ),
    ],
  ),
  // 50: the saved meal's items are not given
  WorkedExample(
    50,
    'eggs and toast, coffee',
    setup: ExampleSetup(savedMeals: _savedMealsFor47To50),
    lines: [
      ExpectedLine(_saved, savedMeal: 'Eggs and toast', multiplier: 1),
      _coffeeDefault,
    ],
  ),
  // 51
  WorkedExample(
    51,
    '2 slices toast',
    setup: ExampleSetup(learned: [learnedToastNoAmount]),
    lines: [
      ExpectedLine(
        _matched,
        ref: 'usda:2707756',
        name: 'Bread, rye, toasted',
        quantity: 2,
        unit: 'slice',
        portion: ExpectedPortion(grams: 29),
        grams: 58,
        kcal: 165,
      ),
    ],
  ),
  // 52
  WorkedExample(
    52,
    'toast',
    setup: ExampleSetup(learned: [learnedToastTwoSlices]),
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2707756',
        quantity: 2,
        unit: 'slice',
        defaultSource: DefaultSource.learned,
        grams: 58,
        kcal: 165,
      ),
    ],
  ),
  // 53
  WorkedExample(
    53,
    '1 cup egg noodles',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: 'usda:169732',
        name: 'Noodles, egg, enriched, cooked',
        quantity: 1,
        unit: 'cup',
        grams: 160,
        kcal: 221,
      ),
    ],
  ),
  // 54
  WorkedExample(
    54,
    'french toast',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: 'usda:2708331',
        name: 'French toast, NFS',
        quantity: 60,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 60,
        grams: 60,
        kcal: 164,
      ),
    ],
  ),
  // 55
  WorkedExample(55, 'coffee without sugar', lines: [_coffeeDefault]),
  // 56
  WorkedExample(
    56,
    '2% milk',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2705386',
        name: 'Milk, reduced fat (2%)',
        quantity: 1,
        unit: 'cup',
        defaultSource: _dflt,
        defaultGrams: 244,
        grams: 244,
        kcal: 122,
      ),
    ],
  ),
  // 57
  WorkedExample(
    57,
    '1 oz cheese, 2 tbsp. peanut butter',
    lines: [
      ExpectedLine(
        _matched,
        ref: 'usda:2705704',
        name: 'Cheese, NFS',
        quantity: 1,
        unit: 'oz',
        grams: 28.3,
        kcal: 108,
      ),
      ExpectedLine(
        _matched,
        ref: _peanutButter,
        quantity: 2,
        unit: 'tbsp',
        grams: 32,
        kcal: 191,
      ),
    ],
  ),
  // 58
  WorkedExample(
    58,
    '2 eggs + 1 banana plus coffee',
    lines: [
      ExpectedLine(_matched, ref: _egg, grams: 100),
      ExpectedLine(_matched, ref: _banana, grams: 126),
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _coffee,
        quantity: 1,
        unit: 'small',
        defaultSource: _dflt,
        defaultGrams: 360,
        grams: 360,
      ),
    ],
  ),
  // 59
  WorkedExample(59, 'asdfgh', lines: [ExpectedLine(_notFound, text: 'asdfgh')]),
  // 60
  WorkedExample(
    60,
    'purple monkey dishwasher',
    lines: [ExpectedLine(_notFound, text: 'purple monkey dishwasher')],
  ),
  // 61
  WorkedExample(61, '200 g', lines: [ExpectedLine(_notFound, text: '200 g')]),
  // 62: cursor at the end; the half-typed item is drawn as plain typing
  WorkedExample(
    62,
    '2 eggs, 2 sl',
    setup: ExampleSetup(cursorAtEnd: true),
    lines: [
      ExpectedLine(_matched, ref: _egg, grams: 100),
      ExpectedLine(_notFound, text: '2 sl', plain: true),
    ],
  ),
  // 63: two inputs, no lines
  WorkedExample(63, '!!!', alternateInputs: [',,, and']),
  // 64
  WorkedExample(
    64,
    'black coffee two eggs and toast',
    lines: [
      _coffeeDefault,
      _egg2,
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _toastNs,
        quantity: 1,
        unit: 'medium or regular slice',
        defaultSource: _dflt,
        defaultGrams: 25,
        grams: 25,
        kcal: 73,
      ),
    ],
  ),
  // 65: "1 ("1 banana")"
  WorkedExample(
    65,
    'two eggs a banana',
    lines: [
      _egg2,
      ExpectedLine(
        _matched,
        ref: _banana,
        quantity: 1,
        portion: ExpectedPortion(label: '1 banana'),
        grams: 126,
        kcal: 122,
      ),
    ],
  ),
  // 66
  WorkedExample(66, 'I had a banana', lines: [_banana1]),
  // 67
  WorkedExample(
    67,
    'a dozen eggs',
    lines: [
      ExpectedLine(_matched, ref: _egg, quantity: 12, grams: 600, kcal: 1056),
    ],
  ),
  // 68
  WorkedExample(
    68,
    'half a dozen eggs',
    lines: [
      ExpectedLine(_matched, ref: _egg, quantity: 6, grams: 300, kcal: 528),
    ],
  ),
  // 69
  WorkedExample(
    69,
    '2 eggs x3',
    lines: [
      ExpectedLine(_matched, ref: _egg, quantity: 6, grams: 300, kcal: 528),
    ],
  ),
  // 70
  WorkedExample(
    70,
    '1/2-3/4 cup milk',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _milk,
        quantity: 0.625,
        unit: 'cup',
        grams: 152.5,
        kcal: 79,
      ),
    ],
  ),
  // 71
  WorkedExample(
    71,
    '1 can Dr. Pepper',
    lines: [
      ExpectedLine(
        _matched,
        ref: 'usda:2710545',
        name: 'Soft drink, pepper type',
        quantity: 1,
        unit: 'can',
        portion: ExpectedPortion(label: '1 can (12 fl oz)', grams: 372),
        grams: 372,
        kcal: 156,
      ),
    ],
  ),
  // 72
  WorkedExample(
    72,
    '1 can V8',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2709731',
        name: 'Tomato and vegetable juice, 100%',
        quantity: 248,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 248,
        grams: 248,
        kcal: 55,
      ),
    ],
  ),
  // 73: "1 drink (12 fl oz)" (default rule 4)
  WorkedExample(
    73,
    '7up',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:173205',
        name: 'Beverages, carbonated, lemon-lime soda, no caffeine',
        quantity: 1,
        unit: 'drink (12 fl oz)',
        defaultSource: DefaultSource.rule4,
        portion: ExpectedPortion(label: '1 drink (12 fl oz)', grams: 368),
        grams: 368,
        kcal: 151,
      ),
    ],
  ),
  // 74: the variant is the "without the recipe" line, "2 x 255 g (default)"
  WorkedExample(
    74,
    '2 servings chili',
    setup: ExampleSetup(userFoods: _bothUserFoods),
    lines: [
      ExpectedLine(
        _matched,
        ref: 'local:1',
        name: 'Turkey chili',
        quantity: 2,
        unit: 'serving',
        kcal: 840,
      ),
    ],
    variants: [
      ExampleVariant('without the recipe', ExampleSetup(), [
        ExpectedLine(
          _matched,
          ref: 'usda:2706373',
          name: 'Chili, NFS',
          quantity: 2,
          defaultSource: _dflt,
          defaultGrams: 255,
          grams: 510,
          kcal: 602,
        ),
      ]),
    ],
  ),
  // 75
  WorkedExample(
    75,
    'butter',
    setup: ExampleSetup(userFoods: _bothUserFoods),
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _butter,
        name: 'Butter, NFS',
        quantity: 1,
        unit: 'tbsp',
        defaultSource: _dflt,
        defaultGrams: 14,
        grams: 14,
        kcal: 104,
      ),
    ],
  ),
  // 76
  WorkedExample(
    76,
    '2 slices 12 grain bread',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: 'usda:2707706',
        name: 'Bread, whole grain white',
        quantity: 2,
        unit: 'slice',
        grams: 72,
        kcal: 171,
      ),
    ],
  ),
  // 77
  WorkedExample(
    77,
    'zorbo bar',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2708114',
        name: 'Breakfast bar, NFS',
        quantity: 1,
        unit: 'bar',
        defaultSource: _dflt,
        defaultGrams: 43,
        grams: 43,
        kcal: 162,
      ),
    ],
  ),
  // 78
  WorkedExample(
    78,
    'leftover pizza',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mBoth,
        ref: 'usda:2708686',
        name: 'Pizza rolls',
        quantity: 85,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 85,
        grams: 85,
        kcal: 293,
      ),
    ],
  ),
  // 79
  WorkedExample(
    79,
    'chicken breast 6 oz grilled',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: 'usda:2705969',
        name: 'Chicken breast, grilled with sauce, skin eaten',
        quantity: 6,
        unit: 'oz',
        grams: 170.1,
        kcal: 344,
      ),
    ],
  ),
  // 80
  WorkedExample(
    80,
    'rice 1 cup cooked',
    lines: [
      ExpectedLine(
        _matched,
        ref: _rice,
        name: 'Rice, cooked, NFS',
        quantity: 1,
        unit: 'cup',
        grams: 158,
        kcal: 204,
      ),
    ],
  ),
  // 81
  WorkedExample(
    81,
    'chicken 200g rice 1 cup cooked',
    lines: [_chicken200g, _rice1Cup],
  ),
  // 82
  WorkedExample(
    82,
    'chicken 200g rice',
    lines: [
      ExpectedLine(
        _guess,
        markers: _mGuess,
        ref: 'usda:2706438',
        name: 'Chicken curry with rice',
        quantity: 200,
        unit: 'g',
        grams: 200,
        kcal: 232,
      ),
    ],
  ),
  // 83
  WorkedExample(
    83,
    '1 lb 4 oz steak',
    lines: [
      ExpectedLine(
        _matched,
        ref: 'usda:2705823',
        name: 'Steak, NS as to type of meat, NS as to fat eaten',
        quantity: 1.25,
        unit: 'lb',
        grams: 567,
        kcal: 1304,
      ),
    ],
  ),
  // 84
  WorkedExample(
    84,
    '1 cup 2 tbsp milk',
    lines: [
      ExpectedLine(
        _matched,
        ref: _milk,
        quantity: 1.125,
        unit: 'cup',
        grams: 274.5,
        kcal: 143,
      ),
    ],
  ),
  // 85
  WorkedExample(85, '2eggs', lines: [_egg2]),
  // 86
  WorkedExample(86, '1/2c milk', lines: [_milkHalfCup]),
  // 87
  WorkedExample(87, 'a half cup milk', lines: [_milkHalfCup]),
  // 88
  WorkedExample(
    88,
    'a few almonds',
    lines: [
      ExpectedLine(
        _assumed,
        markers: _mAssumed,
        ref: _almonds,
        quantity: 28,
        unit: 'g',
        defaultSource: _dflt,
        defaultGrams: 28,
        grams: 28,
        kcal: 167,
      ),
    ],
  ),
];
