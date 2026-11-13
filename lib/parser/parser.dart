// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// The whole parse: typed text to the lines the screen shows (grammar 1, 5.1,
// 6, 7.3, 8.1, 9.2). Pure Dart. Live re-parsing, the item cache and sticky
// corrections are built on top of [Parser.parseItem] in a later task.

import 'package:sqlite3/sqlite3.dart';

import 'grams.dart';
import 'learned_key.dart';
import 'line.dart';
import 'name_key.dart';
import 'normalize.dart';
import 'rank.dart';
import 'search_index.dart';
import 'split.dart';
import 'user_snapshot.dart';
import 'user_snapshot_data.dart';

/// Finds a USDA food by ref (`usda:<id>`): its portions and its nutrients per
/// 100 g, or null when there is no such food. Tests pass a map lookup, the
/// worker passes [sqliteUsdaFoods].
typedef UsdaFoodLoader = PortionFood? Function(String ref);

/// A [UsdaFoodLoader] over an open USDA reference database (the tables of
/// tools/build_food_db.py). Results are kept, so each food is read once. A food
/// with no portion row and no nutrient row counts as missing. Its two queries
/// are prepared once; call [dispose] when the owner of [db] is done, before
/// closing the database, to release them. See [sqliteUsdaFoods] for the plain
/// function form.
class SqliteUsdaFoods {
  SqliteUsdaFoods(Database db)
    : _portions = db.prepare(
        'SELECT label, gram_weight FROM food_portion '
        'WHERE food_id = ? ORDER BY seq',
      ),
      _nutrients = db.prepare(
        'SELECT nutrient_id, amount FROM food_nutrient WHERE food_id = ?',
      );

  final PreparedStatement _portions;
  final PreparedStatement _nutrients;
  final Map<String, PortionFood?> _memo = {};

  PortionFood? call(String ref) => _memo.putIfAbsent(ref, () {
    final id = ref.startsWith('usda:') ? int.tryParse(ref.substring(5)) : null;
    if (id == null) return null;
    final portions = _portions.select([id]);
    final nutrients = _nutrients.select([id]);
    if (portions.isEmpty && nutrients.isEmpty) return null;
    return PortionFood.usda(
      portions: [
        for (final r in portions)
          (r['label'] as String, (r['gram_weight'] as num).toDouble()),
      ],
      nutrients: {
        for (final r in nutrients)
          r['nutrient_id'] as int: (r['amount'] as num).toDouble(),
      },
    );
  });

  /// Releases the prepared statements. The loader must not be called after.
  void dispose() {
    _portions.close();
    _nutrients.close();
  }
}

/// [SqliteUsdaFoods] as a plain function, for callers that never dispose it
/// (the statements then live until the database is closed).
UsdaFoodLoader sqliteUsdaFoods(Database db) => SqliteUsdaFoods(db).call;

/// True for a not found line that has the cursor in it: after its start, up to
/// and including its end (grammar 9.2). Such a line is drawn as plain typing.
bool underCursor(Line line, int cursor) {
  final sp = line.span;
  return line.state == LineState.notFound &&
      sp != null &&
      cursor > sp.start &&
      cursor <= sp.end;
}

class Parser {
  Parser(this.usda, this.loadUsda);

  /// The USDA search index, built once.
  final SearchIndex usda;
  final UsdaFoodLoader loadUsda;

  UserSnapshot? _rankerFor;
  Ranker? _ranker;
  late final Map<String, IndexFood> _usdaFoods = {
    for (final f in usda.foods) f.ref: f,
  };

  /// The ranker for [s], built once per snapshot and shared by parsing, the
  /// correction sheet's candidates and its search.
  Ranker rankerFor(UserSnapshot s) {
    if (!identical(_rankerFor, s)) {
      _ranker = Ranker(usda, user: s.index, history: s.history);
      _rankerFor = s;
    }
    return _ranker!;
  }

  /// The portions and nutrients of the food [ref] (`usda:<id>` or
  /// `local:<id>`) for [s], or null when there is no such food.
  PortionFood? foodFor(String ref, UserSnapshot s) => _food(ref, s);

  /// The name of the food [ref] for [s], or null.
  String? nameFor(String ref, UserSnapshot s) => _name(ref, s);

  /// The USDA index entry for [ref], or null (also for a local food).
  IndexFood? usdaFood(String ref) => _usdaFoods[ref];

  /// The lines for [text], in screen order. A saved meal header carries its
  /// item lines in [Line.items]; on screen they follow it. [cursor] is an
  /// index into [text]; a not found item that has it (after its start, up to
  /// and including its end) is returned as plain (9.2). A cursor outside the
  /// text means none.
  ///
  /// Totals: add up the item lines of headers and every other line. A header
  /// adds nothing of its own (6.4).
  List<Line> parseMeal(String text, int cursor, UserSnapshot snapshot) {
    final out = <Line>[];
    for (final d in splitItems(text, names: snapshot.names)) {
      var line = parseItem(d, snapshot);
      if (line == null) continue;
      if (underCursor(line, cursor)) line = line.asPlain();
      out.add(line);
    }
    return out;
  }

  /// One item to its line (grammar 5.1 order): an alias or saved meal, then a
  /// learned match, then ranking. Does not look at the cursor. Null when the
  /// item gives no line (R36: all its words were cut by a negation and no
  /// amount was typed).
  Line? parseItem(ItemDraft d, UserSnapshot s) {
    if (!d.hasFoodWords) {
      return Line(
        state: LineState.notFound,
        span: d.span,
        amountSpans: d.amountSpans,
      );
    }

    final meal = _savedMeal(d, s);
    if (meal != null) return _header(d, meal);

    final key = learnedKey(d.foodText);
    final typedKey = key.isEmpty ? null : key;
    Line notFound() => Line(
      state: LineState.notFound,
      learnedKey: typedKey,
      span: d.span,
      amountSpans: d.amountSpans,
      foodText: d.foodText,
    );

    // 7.3: a learned match decides the food, and may give the amount.
    String? ref;
    String? name;
    PortionFood? food;
    var base = LineState.matched;
    List<String> words = const [];
    LearnedAmount? learnedAmount;
    var fromLearned = false;
    final learned = key.isEmpty ? null : s.learned[key];
    if (learned != null) {
      final f = _food(learned.foodRef, s);
      if (f != null) {
        ref = learned.foodRef;
        name = _name(learned.foodRef, s) ?? learned.foodName;
        food = f;
        fromLearned = true;
        words = queryWords(d.foodText);
        final q = learned.quantity;
        if (q != null) {
          learnedAmount = LearnedAmount(q, learned.unitLabel ?? '');
        }
      }
    }
    if (food == null) {
      final m = rankerFor(s).match(d.matchText, negation: !d.negationProtected);
      if (m.state == LineState.notFound || m.top == null) {
        // Every word was removed by the negation cut ("no sugar"): with an
        // amount it is not found (8.1), without one it gives no line (R36).
        final negated =
            m.allNegated || (d.negationProtected && d.matchText.isEmpty);
        if (negated && !d.hasAmount) return null;
        return notFound();
      }
      ref = m.top!.ref;
      name = m.top!.description;
      food = _food(ref, s);
      if (food == null) return notFound();
      base = m.state;
      words = m.words;
    }

    return _finish(
      d,
      key: typedKey,
      food: food,
      ref: ref!,
      name: name,
      base: base,
      words: words,
      learned: learnedAmount,
      fromLearned: fromLearned,
    );
  }

  /// The line for item [d] when its food is [ref]: the item's own amount
  /// worked out for that food (4.5, 4.6), the state matched, or amount assumed
  /// when the amount falls back to a default, and [markers] added. This is the
  /// tail of [parseItem]; a pick in the correction sheet uses it. A learned
  /// amount is used only when the learned match is this food (7.2). Null when
  /// there is no such food.
  Line? lineFor(
    ItemDraft d,
    UserSnapshot s,
    String ref, {
    Set<Marker> markers = const {},
  }) {
    final food = _food(ref, s);
    if (food == null) return null;
    final key = learnedKey(d.foodText);
    final learned = key.isEmpty ? null : s.learned[key];
    final q = learned != null && learned.foodRef == ref
        ? learned.quantity
        : null;
    return _finish(
      d,
      key: key.isEmpty ? null : key,
      food: food,
      ref: ref,
      name: _name(ref, s) ?? ref,
      base: LineState.matched,
      words: readQuery(d.matchText, negation: !d.negationProtected).words,
      learned: q == null ? null : LearnedAmount(q, learned!.unitLabel ?? ''),
      extraMarkers: markers,
    );
  }

  // From the amount onward (the shared end of parseItem and lineFor).
  Line _finish(
    ItemDraft d, {
    required String? key,
    required PortionFood food,
    required String ref,
    required String? name,
    required LineState base,
    required List<String> words,
    required LearnedAmount? learned,
    bool fromLearned = false,
    Set<Marker> extraMarkers = const {},
  }) {
    final r = resolveAmount(d, food, foodWords: words, learned: learned);
    var state = base;
    final markers = <Marker>{...extraMarkers};
    if (base == LineState.guess) markers.add(Marker.guess);
    if (r.assumed) {
      markers.add(Marker.assumed);
      if (state == LineState.matched) state = LineState.amountAssumed;
    }
    return Line(
      state: state,
      foodRef: ref,
      foodName: name,
      quantity: r.quantity,
      unitLabel: r.unitLabel,
      baseQuantity: r.baseQuantity,
      baseUnit: r.baseUnit,
      nutrients: scaleNutrients(food, r.baseQuantity),
      markers: markers,
      learnedKey: key,
      span: d.span,
      amountSpans: d.amountSpans,
      foodText: d.foodText,
      fromLearnedMatch: fromLearned,
    );
  }

  PortionFood? _food(String ref, UserSnapshot s) =>
      ref.startsWith('local:') ? s.foods[ref]?.food : loadUsda(ref);

  String? _name(String ref, UserSnapshot s) => ref.startsWith('local:')
      ? s.foods[ref]?.name
      : _usdaFoods[ref]?.description;

  /// 6.1 and 6.2: the saved meal an item's text names, or null. Only a plain
  /// quantity, a multiplier, a range or the unit `serving` or `portion` may
  /// come with it; a size or any other unit means it is food text.
  SavedMealData? _savedMeal(ItemDraft d, UserSnapshot s) {
    if (s.mealsByName.isEmpty) return null;
    final u = d.unit?.label;
    if (d.size != null || (u != null && u != 'serving' && u != 'portion')) {
      return null;
    }
    return s.mealsByName[nameKey(d.foodText)];
  }

  /// 6.4: the header and its item lines. The item lines are already multiplied
  /// by the header's multiplier (quantity, base quantity and nutrients), as
  /// `expandSavedMeal` in lib/data/food_library_data.dart returns them. The
  /// header's own nutrients are their sum, a subtotal.
  Line _header(ItemDraft d, SavedMealData meal) {
    final m = d.quantity ?? 1;
    final items = [
      for (final i in meal.items)
        Line(
          state: LineState.matched,
          foodRef: i.foodRef,
          foodName: i.foodName,
          quantity: i.quantity * m,
          unitLabel: i.unitLabel,
          baseQuantity: i.baseQuantity * m,
          baseUnit: i.baseUnit,
          nutrients: {for (final e in i.nutrients.entries) e.key: e.value * m},
        ),
    ];
    final sum = <int, double>{};
    for (final i in items) {
      for (final e in i.nutrients.entries) {
        sum[e.key] = (sum[e.key] ?? 0) + e.value;
      }
    }
    return Line(
      state: LineState.aliasOrSavedMeal,
      foodName: meal.name,
      nutrients: sum,
      markers: d.isRange ? {Marker.assumed} : const {},
      span: d.span,
      amountSpans: d.amountSpans,
      multiplier: m,
      items: items,
      savedMealId: meal.id,
      foodText: d.foodText,
    );
  }
}
