// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The fixed word lists of the meal text parser (docs/parser-grammar.md,
// sections 2.1, 2.3, 4.1, 4.3, 5.3 and 10.2). Data only: no logic here, so
// every entry can be tested on its own.

/// What a unit measures.
enum UnitKind {
  /// Converted directly to grams.
  mass,

  /// Converted to milliliters, then through the food's portions.
  volume,

  /// A household or count unit, converted only through a portion of the food.
  count,
}

/// What a unit spelling means. [factor] is grams for mass units, milliliters
/// for volume units and 0 for count units.
class UnitDef {
  const UnitDef(this.label, this.kind, this.factor);

  /// The canonical label stored on a line: `g`, `cup`, `fl oz`, `slice`.
  final String label;
  final UnitKind kind;
  final double factor;

  @override
  String toString() => 'UnitDef($label)';
}

/// A mass or volume unit and every spelling the grammar accepts for it (4.1).
/// A one-letter spelling is case sensitive and is read only directly after a
/// number (4.2). Longer spellings ignore case. A period after a spelling is
/// part of it.
class UnitEntry {
  const UnitEntry(this.def, this.spellings);
  final UnitDef def;
  final List<String> spellings;
}

const _g = UnitDef('g', UnitKind.mass, 1);
const _kg = UnitDef('kg', UnitKind.mass, 1000);
const _mg = UnitDef('mg', UnitKind.mass, 0.001);
const _oz = UnitDef('oz', UnitKind.mass, 28.349523125);
const _lb = UnitDef('lb', UnitKind.mass, 453.59237);
const _tsp = UnitDef('tsp', UnitKind.volume, 4.92892159375);
const _tbsp = UnitDef('tbsp', UnitKind.volume, 14.78676478125);
const _cup = UnitDef('cup', UnitKind.volume, 236.5882365);
const _flOz = UnitDef('fl oz', UnitKind.volume, 29.5735295625);
const _pint = UnitDef('pint', UnitKind.volume, 473.176473);
const _quart = UnitDef('quart', UnitKind.volume, 946.352946);
const _gallon = UnitDef('gallon', UnitKind.volume, 3785.411784);
const _ml = UnitDef('ml', UnitKind.volume, 1);
const _l = UnitDef('l', UnitKind.volume, 1000);

/// Grammar 4.1 mass and volume tables. `G` is added to gram by 4.2.
const unitTable = <UnitEntry>[
  UnitEntry(_g, [
    'g', 'G', 'gr', 'gm', 'gms', 'gram', 'grams', 'gramme', 'grammes', //
  ]),
  UnitEntry(_kg, ['kg', 'kgs', 'kilo', 'kilos', 'kilogram', 'kilograms']),
  UnitEntry(_mg, ['mg', 'milligram', 'milligrams']),
  UnitEntry(_oz, ['oz', 'ozs', 'ounce', 'ounces']),
  UnitEntry(_lb, ['lb', 'lbs', 'pound', 'pounds']),
  UnitEntry(_tsp, [
    't', 'tsp', 'tsps', 'tspn', 'teaspoon', 'teaspoons', 'teaspoonful',
    'teaspoonfuls', //
  ]),
  UnitEntry(_tbsp, [
    'T', 'tbsp', 'tbsps', 'tbs', 'tbl', 'tbls', 'tblsp', 'tablespoon',
    'tablespoons', 'tablespoonful', 'tablespoonfuls', //
  ]),
  UnitEntry(_cup, ['c', 'C', 'cup', 'cups', 'cupful', 'cupfuls']),
  UnitEntry(_flOz, [
    'fl oz', 'fl. oz.', 'fl.oz', 'floz', 'fl ounce', 'fl ounces',
    'fluid ounce', 'fluid ounces', //
  ]),
  UnitEntry(_pint, ['pint', 'pints', 'pt', 'pts']),
  UnitEntry(_quart, ['quart', 'quarts', 'qt', 'qts']),
  UnitEntry(_gallon, ['gallon', 'gallons', 'gal', 'gals']),
  UnitEntry(_ml, [
    'ml', 'mls', 'milliliter', 'milliliters', 'millilitre',
    'millilitres', //
  ]),
  UnitEntry(_l, ['l', 'L', 'liter', 'liters', 'litre', 'litres', 'ltr']),
];

/// Household and count units (4.1): canonical label, then the extra singular
/// spellings. Each spelling, and the label itself, is also accepted with `s`
/// and with `es`.
const householdUnits = <(String, List<String>)>[
  ('slice', []),
  ('piece', ['pc', 'pcs']),
  ('serving', ['svg']),
  ('portion', []),
  ('can', []),
  ('bottle', []),
  ('glass', []),
  ('mug', []),
  ('bowl', []),
  ('scoop', []),
  ('clove', []),
  ('container', []),
  ('packet', ['pkt']),
  ('package', ['pkg']),
  ('bag', []),
  ('box', []),
  ('carton', []),
  ('jar', []),
  ('pouch', []),
  ('tub', []),
  ('bar', []),
  ('stick', []),
  ('pat', []),
  ('strip', []),
  ('link', []),
  ('patty', []),
  ('fillet', ['filet']),
  ('wedge', []),
  ('leaf', []),
  ('stalk', []),
  ('spear', []),
  ('sprig', []),
  ('head', []),
  ('ear', []),
  ('handful', []),
  ('square', []),
  ('cube', []),
  ('sheet', []),
  ('shot', []),
  ('jigger', []),
];

/// The abbreviations among the household spellings. They take "s" but not
/// "es" (`pcs`, not `pcses`).
const householdAbbreviations = <String>{'pc', 'pcs', 'svg', 'pkt', 'pkg'};

/// Irregular plurals of household units, beyond `s` and `es`. The grammar names
/// `leaves`; `patties` is added so "2 patties" reads as a unit.
const householdIrregularPlurals = <String, String>{
  'leaf': 'leaves',
  'patty': 'patties',
};

/// Size words (4.3) and what each is read as. `big` is read as large.
const sizeWords = <String, String>{
  'small': 'small',
  'medium': 'medium',
  'large': 'large',
  'big': 'large',
  'extra large': 'extra large',
  'xl': 'extra large',
  'jumbo': 'jumbo',
  'mini': 'mini',
  'miniature': 'miniature',
  'regular': 'regular',
  'thin': 'thin',
  'thick': 'thick',
};

/// The ones, teens and tens number words (10.2).
const onesWords = <String, int>{
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
};

const teensWords = <String, int>{
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const tensWords = <String, int>{
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

/// The fraction words of 3.1: half, quarter, third.
const fractionWords = <String, double>{
  'half': 1 / 2,
  'quarter': 1 / 4,
  'third': 1 / 3,
};

/// Plural fraction words after a whole number: `three quarters`, `two thirds`.
const countedFractionWords = <String, double>{
  'quarters': 1 / 4,
  'thirds': 1 / 3,
};

/// The unicode fraction characters (2.1) and the `n/d` each becomes.
const vulgarFractions = <String, String>{
  '½': '1/2',
  '⅓': '1/3',
  '⅔': '2/3',
  '¼': '1/4',
  '¾': '3/4',
  '⅕': '1/5',
  '⅖': '2/5',
  '⅗': '3/5',
  '⅘': '4/5',
  '⅙': '1/6',
  '⅚': '5/6',
  '⅐': '1/7',
  '⅛': '1/8',
  '⅜': '3/8',
  '⅝': '5/8',
  '⅞': '7/8',
  '⅑': '1/9',
  '⅒': '1/10',
};

/// Vague words that count as no quantity (3.4), longest first. The code reads
/// these from this list. The quantity phrases that start with "a" (`a couple
/// of`, `a dozen`, `a half`, `a quarter`, `a third`) are built into the
/// quantity reader in amount.dart, and the approximation words (`about`,
/// `around`, `approximately`, `roughly`) are in [fillerWords], where they are
/// ignored.
const vaguePhrases = <String>[
  'a bit of',
  'a bit',
  'a little',
  'a few',
  'few',
  'some',
];

/// Filler words (10.2). `a` and `an` are filler only where 2.6 rule 5 does not
/// read them as the quantity 1.
const fillerWords = <String>{
  'a', 'an', 'the', 'of', 'and', 'or', 'with', 'in', 'on', 'for', 'to', 'my',
  'i', 'im', 'had', 'have', 'ate', 'eaten', 'drank', 'then', 'also', 'just',
  'made', 'prepared', 'topped', 'plus', 'about', 'around', 'approximately',
  'roughly', //
};

/// Words that do not count as extra when ranking foods (5.4, 10.2). Compared
/// after plural removal.
const neutralDescriptionWords = <String>{
  'nfs', 'ns', 'as', 'to', 'or', 'and', 'with', 'of', 'in', 'whole', 'plain',
  'regular', 'raw', 'fresh', 'brewed', 'cooked', 'include', //
};

/// Words after which a period belongs to the word (2.2).
const titleAbbreviations = <String>{
  'dr', 'mr', 'mrs', 'ms', 'st', 'jr', 'sr', 'vs', //
};

/// The built-in protected phrases (2.3): food names that contain a separator
/// word or would split into the wrong foods. All lower case, single spaces.
const builtInProtectedPhrases = <String>[
  'half and half',
  'mac and cheese',
  'mac n cheese',
  'macaroni and cheese',
  'peanut butter and jelly',
  'pb and j',
  'pb and jelly',
  'almond butter and jelly',
  'sweet and sour',
  'sour cream and onion',
  'peas and carrots',
  'beans and rice',
  'rice and beans',
  'pork and beans',
  'beans and franks',
  'beef and broccoli',
  'biscuits and gravy',
  'gin and tonic',
  'vodka and tonic',
  'rum and cola',
  'rum and coke',
  '7 up',
  // Protected only so that its "a" is never read as a quantity.
  'a la',
];

/// The synonym table (5.3): typed phrase to what it is matched as. A phrase
/// that maps to itself protects it from the shorter rows. Later tasks apply it
/// to typed text, longest phrase first, in a single pass.
const synonyms = <String, String>{
  'french toast': 'french toast',
  'melba toast': 'melba toast',
  'toast': 'bread toasted',
  'black coffee': 'coffee',
  'dr pepper': 'soft drink pepper type',
  '7 up': 'lemon lime soda',
  '7up': 'lemon lime soda',
  'v8': 'tomato vegetable juice',
  'fries': 'french fries',
  'pb and j': 'peanut butter jelly',
  'pbj': 'peanut butter jelly',
  'pb': 'peanut butter',
  'oj': 'orange juice',
  'evoo': 'olive oil',
  'mac': 'macaroni',
  'mayo': 'mayonnaise',
  'coke': 'cola soft drink',
  'soda': 'soft drink',
  'burger': 'hamburger',
  'yoghurt': 'yogurt',
  'donut': 'doughnut',
  'skim milk': 'milk fat free skim',
  'nonfat milk': 'milk fat free skim',
  'bbq': 'barbecue',
  'cooked cereal': 'cooked cereal',
  'cereal bar': 'cereal bar',
  'cereal': 'cereal ready to eat',
};
