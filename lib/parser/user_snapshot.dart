// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The prepared form of the user's data (UserSnapshotData) that parsing needs.
// Built once per snapshot version, immutable afterwards.

import 'grams.dart';
import 'search_index.dart';
import 'split.dart';
import 'user_snapshot_data.dart';

const _energyId = 1008;

/// A phrase as aliases and saved meal names are compared (grammar 6.1): lower
/// case, accents and apostrophes removed, other punctuation read as a space,
/// words separated by single spaces. Same result as `normalizePhrase` in
/// lib/data/food_data.dart, which this folder cannot import.
String normalizeName(String text) {
  const from = 'àáâãäåāçèéêëìíîïñòóôõöøùúûüýÿ';
  const to = 'aaaaaaaceeeeiiiinoooooouuuuyy';
  final word = RegExp(r'[\p{L}\p{N}%]', unicode: true);
  final out = StringBuffer();
  for (final ch in text.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    final c = i >= 0 ? to[i] : ch;
    if (c == "'" || c == '’') continue;
    out.write(word.hasMatch(c) ? c : ' ');
  }
  return out.toString().split(' ').where((w) => w.isNotEmpty).join(' ');
}

/// One of the user's foods, ready for amounts and nutrients.
class LocalFood {
  const LocalFood(this.name, this.food);
  final String name;
  final PortionFood food;
}

class UserSnapshot {
  UserSnapshot._({
    required this.version,
    required this.names,
    required this.index,
    required this.foods,
    required this.mealsByName,
    required this.learned,
    required this.history,
  });

  /// The user's data prepared for parsing. A food whose base amount is not
  /// finite or not above zero is left out, so it is never a candidate (R35).
  factory UserSnapshot.from(UserSnapshotData d) {
    final foods = <String, LocalFood>{};
    final indexFoods = <IndexFood>[];
    for (final f in d.foods) {
      if (!f.baseAmount.isFinite || f.baseAmount <= 0) continue;
      foods[f.ref] = LocalFood(
        f.name,
        PortionFood.local(
          baseUnit: f.baseUnit,
          baseAmount: f.baseAmount,
          portions: [for (final p in f.portions) (p.label, p.baseQuantity)],
          nutrients: Map.unmodifiable(f.nutrients),
        ),
      );
      final kcal = f.nutrients[_energyId];
      indexFoods.add(
        IndexFood(
          ref: f.ref,
          description: f.name,
          dataset: 'local',
          kind: f.kind,
          energy: kcal != null && f.baseUnit != 'serving'
              ? kcal * 100 / f.baseAmount
              : null,
        ),
      );
    }

    // Saved meal names, then aliases. The newest saved meal (highest id) wins
    // a name tie, and an alias wins over a name (6.1).
    final meals = [...d.savedMeals]..sort((a, b) => a.id.compareTo(b.id));
    final byId = {for (final m in meals) m.id: m};
    final byName = <String, SavedMealData>{};
    for (final m in meals) {
      final n = normalizeName(m.name);
      if (n.isNotEmpty) byName[n] = m;
    }
    final aliases = [...d.aliases]
      ..sort((a, b) => a.savedMealId.compareTo(b.savedMealId));
    for (final a in aliases) {
      final m = byId[a.savedMealId];
      final n = normalizeName(a.phrase);
      if (m != null && n.isNotEmpty) byName[n] = m;
    }

    final learned = <String, LearnedMatchData>{};
    for (final l in d.learned) {
      final old = learned[l.key];
      if (old == null ||
          l.timesUsed > old.timesUsed ||
          (l.timesUsed == old.timesUsed &&
              l.foodRef.compareTo(old.foodRef) < 0)) {
        learned[l.key] = l;
      }
    }

    return UserSnapshot._(
      version: d.version,
      names: UserNames.from([
        for (final f in foods.values) f.name,
        for (final m in d.savedMeals) m.name,
        for (final a in d.aliases) a.phrase,
      ]),
      index: indexFoods.isEmpty ? null : SearchIndex.build(indexFoods),
      foods: Map.unmodifiable(foods),
      mealsByName: Map.unmodifiable(byName),
      learned: Map.unmodifiable(learned),
      history: Map.unmodifiable(d.historyCounts),
    );
  }

  static final UserSnapshot empty = UserSnapshot.from(const UserSnapshotData());

  final int version;

  /// The user's names, protected phrases for the splitter.
  final UserNames names;

  /// The user's own foods, or null when there are none.
  final SearchIndex? index;

  /// By food ref (`local:<id>`).
  final Map<String, LocalFood> foods;

  /// Saved meals by normalized name or alias phrase (6.1).
  final Map<String, SavedMealData> mealsByName;

  /// Learned matches by key (7.1).
  final Map<String, LearnedMatchData> learned;

  /// Food ref to times logged.
  final Map<String, int> history;
}
