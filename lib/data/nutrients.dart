// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

/// A nutrient the app tracks. Ids are USDA FoodData Central nutrient ids,
/// used everywhere in the app and in both databases. Nutrients the app does
/// not track are still stored under their USDA id so they can be shown later.
class Nutrient {
  const Nutrient(this.id, this.name, this.unit, {this.offKey});

  final int id;
  final String name;

  /// 'kcal', 'g', 'mg' or 'µg'.
  final String unit;

  /// Open Food Facts nutriment key (the part before `_100g`), if any.
  final String? offKey;
}

class Nutrients {
  static const energy = 1008;
  static const protein = 1003;
  static const carbs = 1005;
  static const fat = 1004;
  static const fiber = 1079;
  static const sugar = 2000;
  static const addedSugar = 1235;
  static const saturatedFat = 1258;
  static const transFat = 1257;
  static const cholesterol = 1253;
  static const sodium = 1093;
  static const potassium = 1092;
  static const calcium = 1087;
  static const iron = 1089;
  static const magnesium = 1090;
  static const zinc = 1095;
  static const vitaminA = 1106; // RAE
  static const vitaminC = 1162;
  static const vitaminD = 1114; // D2 + D3
  static const vitaminE = 1109; // alpha-tocopherol
  static const vitaminK = 1185; // phylloquinone
  static const vitaminB6 = 1175;
  static const vitaminB12 = 1178;
  static const folate = 1190; // DFE

  /// The nutrients in BRIEF.md, in display order.
  static const tracked = <Nutrient>[
    Nutrient(energy, 'Calories', 'kcal', offKey: 'energy-kcal'),
    Nutrient(protein, 'Protein', 'g', offKey: 'proteins'),
    Nutrient(carbs, 'Carbs', 'g', offKey: 'carbohydrates'),
    Nutrient(fat, 'Fat', 'g', offKey: 'fat'),
    Nutrient(fiber, 'Fiber', 'g', offKey: 'fiber'),
    Nutrient(sugar, 'Sugar', 'g', offKey: 'sugars'),
    Nutrient(addedSugar, 'Added sugar', 'g', offKey: 'added-sugars'),
    Nutrient(saturatedFat, 'Saturated fat', 'g', offKey: 'saturated-fat'),
    Nutrient(transFat, 'Trans fat', 'g', offKey: 'trans-fat'),
    Nutrient(cholesterol, 'Cholesterol', 'mg', offKey: 'cholesterol'),
    Nutrient(sodium, 'Sodium', 'mg', offKey: 'sodium'),
    Nutrient(potassium, 'Potassium', 'mg', offKey: 'potassium'),
    Nutrient(calcium, 'Calcium', 'mg', offKey: 'calcium'),
    Nutrient(iron, 'Iron', 'mg', offKey: 'iron'),
    Nutrient(magnesium, 'Magnesium', 'mg', offKey: 'magnesium'),
    Nutrient(zinc, 'Zinc', 'mg', offKey: 'zinc'),
    Nutrient(vitaminA, 'Vitamin A', 'µg', offKey: 'vitamin-a'),
    Nutrient(vitaminC, 'Vitamin C', 'mg', offKey: 'vitamin-c'),
    Nutrient(vitaminD, 'Vitamin D', 'µg', offKey: 'vitamin-d'),
    Nutrient(vitaminE, 'Vitamin E', 'mg', offKey: 'vitamin-e'),
    Nutrient(vitaminK, 'Vitamin K', 'µg', offKey: 'vitamin-k'),
    Nutrient(vitaminB6, 'Vitamin B6', 'mg', offKey: 'vitamin-b6'),
    Nutrient(vitaminB12, 'Vitamin B12', 'µg', offKey: 'vitamin-b12'),
    Nutrient(folate, 'Folate', 'µg', offKey: 'vitamin-b9'),
  ];

  static Nutrient? byId(int id) {
    for (final n in tracked) {
      if (n.id == id) return n;
    }
    return null;
  }
}
