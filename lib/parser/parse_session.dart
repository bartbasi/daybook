// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Live re-parsing for one open food entry screen (grammar 8.3, 9.1, 9.2, 12.3).
// A session holds the text, the cursor, the typed lines and the sticky
// corrections ("your pick"). On every text change it splits the text again,
// re-parses only the items it has not parsed before, and carries each
// correction to the item it belongs to. Pure Dart, deterministic, no timers
// and no clock. The worker (parse_worker.dart) runs a session off the main
// thread.

import 'grams.dart';
import 'amount.dart';
import 'line.dart';
import 'normalize.dart';
import 'parser.dart';
import 'portions.dart';
import 'rank.dart';
import 'split.dart';
import 'tokens.dart';
import 'user_snapshot.dart';

const _energyId = 1008;

/// Most items kept in the per-item cache. Typing leaves a trail of half-typed
/// items behind, so the cache is emptied when it grows past this.
const _cacheLimit = 500;

/// A food offered in the correction sheet (8.3): its name, where it comes
/// from, and its energy for the line's amount, or null when that is unknown.
class FoodChoice {
  const FoodChoice(this.ref, this.name, this.dataset, this.kcal);

  final String ref;
  final String name;

  /// `fndds`, `sr_legacy` or `foundation` for a USDA food, `local` for the
  /// user's own.
  final String dataset;

  /// Energy in kcal for the line's amount (not rounded), or null.
  final double? kcal;
}

/// What the correction sheet lists for a line: the food it has now, then up to
/// 7 others in ranking order (8.3). Both are empty for a line with no food.
class Alternatives {
  const Alternatives(this.current, this.others);

  static const none = Alternatives(null, []);

  final FoodChoice? current;
  final List<FoodChoice> others;
}

/// One entry of the correction sheet's unit picker (ruling R42): an amount
/// that typed text can express for the line's food. Writing [unitText] after a
/// number, and reading that item again, gives the same food and [grams] for
/// one of it.
class UnitChoice {
  const UnitChoice(this.label, this.unitText, this.grams);

  /// What the picker shows: `g`, `tbsp`, `cup, cooked`, `medium`.
  final String label;

  /// What is written after the number. Empty for a bare count.
  final String unitText;

  /// The amount of one of it in the food's base unit (grams for a USDA food).
  final double grams;
}

class _Pick {
  const _Pick(this.ref, this.marker, this.key);
  final String ref;
  final Marker marker;

  /// The learned key (7.1) of the item when it was picked.
  final String? key;
}

// A pick whose item no longer has the picked key (ruling R43).
class _Suspended {
  const _Suspended(this.pick, this.span);
  final _Pick pick;
  final Span span;
}

class _Item {
  _Item(this.draft, this.base);

  final ItemDraft draft;

  /// The parse of the item with no correction.
  final Line base;
  _Pick? pick;

  /// What the screen shows, before the cursor rule: [base], or the line the
  /// pick makes.
  late Line line;
}

class _Cached {
  const _Cached(this.line);
  final Line? line;
}

class ParseSession {
  ParseSession(this.parser, {UserSnapshot? snapshot})
    : _snapshot = snapshot ?? UserSnapshot.empty;

  final Parser parser;

  UserSnapshot _snapshot;
  String _text = '';
  int _cursor = 0;
  List<_Item> _items = const [];
  List<Line> _lines = const [];
  List<_Suspended> _suspended = const [];

  // Parsed items by everything parseItem reads (ItemDraft.cacheKey), so a hit
  // is always right.
  Map<String, _Cached> _cache = {};
  int _parsed = 0;

  UserSnapshot get snapshot => _snapshot;
  String get text => _text;
  int get cursor => _cursor;

  /// The typed lines in text order (saved meal headers carry their item
  /// lines). Added lines (9.3) live outside the session.
  List<Line> get lines => _lines;

  /// How many items [Parser.parseItem] has been called for, over the life of
  /// the session. For tests and the benchmark.
  int get itemsParsed => _parsed;

  /// How many parsed items are cached now.
  int get cacheSize => _cache.length;

  /// Uses new user data. The cache is emptied, because every item may now
  /// parse differently; the sticky corrections stay, except one whose food is
  /// gone. Giving the same snapshot again changes nothing. If parsing with the
  /// new data fails, the session stays as it was, with the old data.
  void setSnapshot(UserSnapshot snapshot) {
    if (identical(snapshot, _snapshot)) return;
    final oldSnapshot = _snapshot;
    final oldCache = _cache;
    _snapshot = snapshot;
    _cache = {};
    try {
      _rebuild(_text);
    } catch (_) {
      _snapshot = oldSnapshot;
      _cache = oldCache;
      rethrow;
    }
  }

  /// Starts again for a new opening of the food entry screen: the text, the
  /// cursor, every pick and the item cache are cleared. The snapshot stays.
  void reset() {
    _text = '';
    _cursor = 0;
    _items = const [];
    _lines = const [];
    _suspended = const [];
    _cache = {};
  }

  /// The text and the cursor (an index into [text]) after a change.
  void setText(String text, int cursor) {
    final before = _cursor;
    _cursor = cursor;
    try {
      if (text == _text && (_items.isNotEmpty || text.isEmpty)) {
        _publish();
      } else {
        _rebuild(text);
      }
    } catch (_) {
      // A failed parse leaves the session as it was.
      _cursor = before;
      rethrow;
    }
  }

  /// Picks [foodRef] for the typed line whose span is [line] (8.3). The text is
  /// not changed. The line keeps the item's own amount, recomputed for the
  /// food; it is matched, or amount assumed when the item has no usable
  /// amount, and carries [marker] ("Your pick", or "Scanned" for a product from
  /// a barcode). The pick follows the item while the user types (9.1, R43).
  /// False, and nothing changes, when there is no such typed line, the line is
  /// a saved meal, or the food is not in the USDA data or the user's snapshot
  /// (send the snapshot that holds a new local food before picking it).
  bool pickFood(Span line, String foodRef, {Marker marker = Marker.yourPick}) {
    final item = _itemAt(line);
    if (item == null || item.base.state == LineState.aliasOrSavedMeal) {
      return false;
    }
    final pick = _Pick(foodRef, marker, item.base.learnedKey);
    final picked = _pickLine(item, pick);
    if (picked == null) return false;
    item.pick = pick;
    item.line = picked;
    _dropSuspendedAt(line);
    _publish();
    return true;
  }

  /// Drops the pick of the line at [line], and any suspended pick of that item;
  /// the line goes back to normal matching. False when it had none.
  bool clearPick(Span line) {
    final item = _itemAt(line);
    if (item == null) return false;
    final had = item.pick != null || _suspendedAt(line);
    item.pick = null;
    item.line = item.base;
    _dropSuspendedAt(line);
    if (had) _publish();
    return had;
  }

  /// What the sheet lists for the typed line at [line] (8.3).
  Alternatives alternatives(Span line) {
    final item = _itemAt(line);
    if (item == null) return Alternatives.none;
    final l = item.line;
    final ref = l.foodRef;
    if (ref == null) return Alternatives.none;
    final ranker = parser.rankerFor(_snapshot);
    final m = ranker.match(
      item.draft.matchText,
      negation: !item.draft.negationProtected,
    );
    return Alternatives(
      FoodChoice(ref, l.foodName ?? ref, _dataset(ref), l.nutrients[_energyId]),
      [
        for (final c in ranker.alternatives(m, currentRef: ref))
          _choice(c, item.draft, m.words),
      ],
    );
  }

  /// The sheet's search box (5.7). With [forLine] the energy of each food is
  /// worked out for that typed line's amount; otherwise it is null.
  List<FoodChoice> search(String text, {Span? forLine}) {
    final d = forLine == null ? null : _itemAt(forLine)?.draft;
    final words = d == null
        ? const <String>[]
        : readQuery(d.matchText, negation: !d.negationProtected).words;
    return [
      for (final c in parser.rankerFor(_snapshot).search(text))
        d == null
            ? FoodChoice(c.ref, c.description, c.food.dataset, null)
            : _choice(c, d, words),
    ];
  }

  /// The line for a food added without typing (9.3): [ref] with [quantity] of
  /// [unit] (a unit text as the picker gives it, empty for a bare count), or
  /// the default amount when [quantity] is null. It is worked out by the same
  /// code as a typed line with that amount, so state and markers are the same:
  /// matched, or amount assumed when the amount is a default. Null when there
  /// is no such food, or the amount cannot be written as text. The line has no
  /// span.
  Line? lineForFood(String ref, {double? quantity, String unit = ''}) {
    ItemDraft d = const ItemDraft(
      span: Span(0, 0),
      foodText: '',
      hasFoodWords: true,
    );
    if (quantity != null) {
      final written = _written(quantity);
      if (written == null) return null;
      final probe = _probe(written, unit);
      if (probe == null) return null;
      d = ItemDraft(
        span: const Span(0, 0),
        foodText: '',
        hasFoodWords: true,
        quantity: probe.quantity,
        unit: probe.unit,
        size: probe.size,
      );
    }
    final l = parser.lineFor(d, _snapshot, ref);
    if (l == null) return null;
    return Line(
      state: l.state,
      foodRef: l.foodRef,
      foodName: l.foodName,
      quantity: l.quantity,
      unitLabel: l.unitLabel,
      baseQuantity: l.baseQuantity,
      baseUnit: l.baseUnit,
      nutrients: l.nutrients,
      markers: l.markers,
    );
  }

  /// Rewrites only the amount of the typed line at [line] in [text] (8.3) and
  /// returns the new text and where [cursor] goes, or null when it cannot be
  /// done as asked. [text] is the text the line came from; it must be the
  /// session's text now.
  ///
  /// The old quantity and unit are replaced by [quantity] and [unit], or
  /// `<quantity> <unit> ` is put immediately before the item's first food word
  /// when it had no amount. Other amount words, such as a multiplier, are
  /// removed so the item reads as [quantity] and no more; when [unit] is empty
  /// a leftover "of" after the old amount goes too ("2 slices of toast" set to
  /// 3 is "3 toast"). Food words are never touched.
  ///
  /// It is verified by reading the new text again: the result must be exactly
  /// [quantity] of [unit] on the same food, with the item's food words and
  /// every other item unchanged. Otherwise the answer is null and nothing
  /// changes. A quantity that would be written as 0, or is not finite, is
  /// refused. [unit] is a unit the parser reads (`g`, `oz`, `tbsp`, `cup`,
  /// `slice`, `large`), or empty for a bare count; the unit picker's
  /// [UnitChoice.unitText] is always one.
  ({String text, int cursor})? rewriteAmount(
    String text,
    int cursor,
    Span line, {
    required double quantity,
    String unit = '',
  }) {
    if (text != _text) return null;
    final item = _itemAt(line);
    if (item == null) return null;
    final r = _tryAmount(item, quantity, unit, cursor);
    return r == null ? null : (text: r.text, cursor: r.cursor);
  }

  /// The unit picker for the typed line at [line] (ruling R42): the amounts
  /// that typed text can express for the line's food. A choice is listed only
  /// if writing it into the item and reading the item again gives the same food
  /// and the grams shown. Grams and ounces, the volume units the food can
  /// convert, and each of the food's own portions that can be typed; labels
  /// that start with "Quantity not specified" are never listed. Empty for a
  /// line with no food.
  List<UnitChoice> unitChoices(Span line) {
    final item = _itemAt(line);
    final ref = item?.line.foodRef;
    if (item == null || ref == null) return const [];
    final food = parser.foodFor(ref, _snapshot);
    if (food == null) return const [];
    final out = <UnitChoice>[];
    void add(String label, String unitText, double? expect, List<String> alt) {
      for (final t in [unitText, ...alt]) {
        final r = _tryAmount(item, 1, t, 0);
        if (r == null) continue;
        final grams = r.line.baseQuantity;
        if (grams == null) continue;
        if (expect != null && (grams - expect).abs() > 0.05) continue;
        // The same unit text and the same amount is one choice.
        if (out.any((c) => c.unitText == t && c.grams == grams)) return;
        out.add(UnitChoice(label, t, grams));
        return;
      }
    }

    for (final u in const ['g', 'oz', 'tsp', 'tbsp', 'cup', 'fl oz', 'ml']) {
      add(u, u, null, const []);
    }
    for (final p in food.portions.usable) {
      if (p.label.startsWith(defaultPortionText)) continue;
      final words = <String>[
        if (p.unit != null) p.unitLead,
        for (final w in p.phraseWords)
          if (sizeWords.containsKey(w) || unitForWord(w) != null) w,
        '',
      ];
      add(p.rest, words.first, p.gramsPerUnit, words.skip(1).toList());
    }
    return out;
  }

  // Rebuilding.

  List<_Item> _parseAll(String text) {
    final items = <_Item>[];
    for (final d in splitItems(text, names: _snapshot.names)) {
      final base = _baseLine(d);
      if (base != null) items.add(_Item(d, base));
    }
    return items;
  }

  void _rebuild(String text) {
    final items = _parseAll(text);
    final suspended = _carryPicks(_text, text, items);
    for (final i in items) {
      Line? picked;
      if (i.pick != null) {
        picked = _pickLine(i, i.pick!);
        // The picked food is gone from the user's data: the pick is dropped.
        if (picked == null) i.pick = null;
      }
      i.line = picked ?? i.base;
    }
    // Nothing above changes the session until it has all worked.
    _text = text;
    _items = items;
    _suspended = [
      for (final s in suspended)
        if (parser.foodFor(s.pick.ref, _snapshot) != null) s,
    ];
    _publish();
  }

  void _publish() {
    _lines = List.unmodifiable([for (final i in _items) _withCursor(i.line)]);
  }

  // 9.2: a not found item under the cursor is plain typing (the parser's own
  // test, [underCursor]).
  //
  // Session rule that 9.2 does not cover: when the cursor is at the end of the
  // text and only spaces, tabs or no-break spaces lie between the item's end
  // and the cursor, the item is still being typed ("2 " and "2 sl "), so it
  // stays plain. A new line is a separator, like a comma, so it ends the item.
  // The item becomes Not found when the cursor moves elsewhere or more text
  // follows.
  Line _withCursor(Line l) {
    if (underCursor(l, _cursor)) return l.asPlain();
    final s = l.span;
    if (l.state == LineState.notFound &&
        s != null &&
        _cursor > s.end &&
        _cursor == _text.length &&
        _blanks.hasMatch(_text.substring(s.end))) {
      return l.asPlain();
    }
    return l;
  }

  static final _blanks = RegExp(r'^[ \t ]*$');

  _Item? _itemAt(Span span) {
    for (final i in _items) {
      if (i.draft.span == span) return i;
    }
    return null;
  }

  bool _suspendedAt(Span span) => _suspended.any(
    (s) => s.span.start <= span.end && s.span.end >= span.start,
  );

  void _dropSuspendedAt(Span span) {
    _suspended = [
      for (final s in _suspended)
        if (!(s.span.start <= span.end && s.span.end >= span.start)) s,
    ];
  }

  // The parse of an item, from the cache when everything the parser reads is
  // the same. The place in the text is not part of the key: a hit is given its
  // new place.
  Line? _baseLine(ItemDraft d) {
    final key = d.cacheKey;
    var hit = _cache[key];
    if (hit == null) {
      _parsed++;
      hit = _Cached(parser.parseItem(d, _snapshot));
      if (_cache.length >= _cacheLimit) _cache.clear();
      _cache[key] = hit;
    }
    final line = hit.line;
    return line == null ? null : _placed(line, d);
  }

  // The line with the item's own place in the text.
  Line _placed(Line l, ItemDraft d) {
    if (l.span == d.span && _sameSpans(l.amountSpans, d.amountSpans)) return l;
    return l.copyWith(span: d.span, amountSpans: d.amountSpans);
  }

  static bool _sameSpans(List<Span> a, List<Span> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Sticky corrections (9.1, R43).

  // Moves the picks of the old items, and the suspended ones, to the new
  // items ([items] are new and have no picks yet), and returns the picks that
  // are suspended now.
  //
  // The changed region is the longest common start and end of the two texts.
  // A pick on an item wholly before or wholly after it, which is still an item
  // at that (shifted) place, is kept. A pick on an item the edit touched is
  // kept only if the item's key is still the picked key; otherwise it is
  // suspended with the item, and comes back if a later edit that touches the
  // same item gives the picked key again. A suspended pick is dropped as soon
  // as an edit lands outside its item.
  List<_Suspended> _carryPicks(
    String oldText,
    String newText,
    List<_Item> items,
  ) {
    final attached = [
      for (final i in _items)
        if (i.pick != null) (i.pick!, i.draft.span),
    ];
    if (attached.isEmpty && _suspended.isEmpty) return const [];
    final same = oldText == newText;

    final shortest = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    var p = 0;
    while (p < shortest && oldText.codeUnitAt(p) == newText.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < shortest - p &&
        oldText.codeUnitAt(oldText.length - 1 - s) ==
            newText.codeUnitAt(newText.length - 1 - s)) {
      s++;
    }
    final oldEnd = oldText.length - s; // the region is [p, oldEnd) before
    final newEnd = newText.length - s; // and [p, newEnd) after
    final delta = newText.length - oldText.length;

    int mapStart(int x) => x <= p ? x : (x >= oldEnd ? x + delta : p);
    int mapEnd(int x) => x <= p ? x : (x >= oldEnd ? x + delta : newEnd);

    final blankEdit =
        _blanks.hasMatch(oldText.substring(p, oldEnd)) &&
        _blanks.hasMatch(newText.substring(p, newEnd));

    final taken = <_Item>{};
    bool free(_Item i) =>
        !taken.contains(i) && i.base.state != LineState.aliasOrSavedMeal;
    _Item? findAt(Span span) {
      for (final i in items) {
        if (free(i) && i.draft.span == span) return i;
      }
      return null;
    }

    final out = <_Suspended>[];

    // Returns the item the pick moves to, or null; fills [out] when the pick
    // is suspended.
    void carry(_Pick pick, Span span, {required bool wasAttached}) {
      if (same && !wasAttached) {
        out.add(_Suspended(pick, span));
        return;
      }
      Span? exact;
      if (span.end <= p) {
        exact = span;
      } else if (span.start >= oldEnd) {
        exact = Span(span.start + delta, span.end + delta);
      }
      if (exact != null) {
        final at = findAt(exact);
        if (at != null) {
          // Before or after the edit and still there: an attached pick is
          // kept; a suspended one saw an edit outside its item and is dropped,
          // unless the edit only added or removed blanks next to the item (a
          // backspace over the space before it).
          if (wasAttached) {
            at.pick = pick;
            taken.add(at);
          } else if (blankEdit && span.start <= oldEnd && span.end >= p) {
            out.add(_Suspended(pick, exact));
          }
          return;
        }
      }
      final touched = span.start <= oldEnd && span.end >= p;
      if (!touched) return;
      final a = mapStart(span.start);
      final b = mapEnd(span.end);
      final near = [
        for (final i in items)
          if (free(i) && i.draft.span.start <= b && i.draft.span.end >= a) i,
      ];
      for (final i in near) {
        if (i.base.learnedKey == pick.key) {
          i.pick = pick;
          taken.add(i);
          return;
        }
      }
      out.add(
        _Suspended(pick, near.isEmpty ? Span(a, a) : near.first.draft.span),
      );
    }

    for (final (pick, span) in attached) {
      carry(pick, span, wasAttached: true);
    }
    for (final sp in _suspended) {
      carry(sp.pick, sp.span, wasAttached: false);
    }
    return out;
  }

  // The line a pick makes (8.3): the picked food with the item's own amount.
  // Null when the food cannot be found.
  Line? _pickLine(_Item item, _Pick pick) =>
      parser.lineFor(item.draft, _snapshot, pick.ref, markers: {pick.marker});

  // Foods and the sheet.

  String _dataset(String ref) => ref.startsWith('local:')
      ? 'local'
      : (parser.usdaFood(ref)?.dataset ?? '');

  FoodChoice _choice(Candidate c, ItemDraft d, List<String> words) {
    final food = parser.foodFor(c.ref, _snapshot);
    double? kcal;
    if (food != null) {
      final r = resolveAmount(d, food, foodWords: words);
      kcal = scaleNutrients(food, r.baseQuantity)[_energyId];
    }
    return FoodChoice(c.ref, c.description, c.food.dataset, kcal);
  }

  // Rewriting an amount.

  // The quantity as it would be written, or null when it would be written as
  // 0 or is not finite.
  static String? _written(double q) {
    if (!q.isFinite || q <= 0) return null;
    final s = _number(q);
    final v = double.tryParse(s);
    return v == null || v <= 0 ? null : s;
  }

  // How the parser reads `<number> <unit> apple`: the quantity, unit and size;
  // null when the unit text is not one amount.
  ({double quantity, UnitDef? unit, String? size})? _probe(
    String written,
    String unit,
  ) {
    final u = unit.trim();
    final d = splitItems(u.isEmpty ? '$written apple' : '$written $u apple');
    if (d.length != 1 ||
        d.single.foodText != 'apple' ||
        d.single.quantity != double.parse(written)) {
      return null;
    }
    return (
      quantity: d.single.quantity!,
      unit: d.single.unit,
      size: d.single.size,
    );
  }

  // The new text for [item]'s amount, verified by reading it again. Null when
  // the result would not be [q] of [unit] on the same food with everything else
  // unchanged.
  ({String text, int cursor, Line line})? _tryAmount(
    _Item item,
    double q,
    String unit,
    int cursor,
  ) {
    final written = _written(q);
    if (written == null) return null;
    final probe = _probe(written, unit);
    if (probe == null) return null;
    final idx = _items.indexOf(item);
    final oldRef = item.line.foodRef;
    if (idx < 0 ||
        oldRef == null ||
        item.base.state == LineState.aliasOrSavedMeal) {
      return null;
    }

    final u = unit.trim();
    final edited = _edit(
      _text,
      cursor,
      item.draft,
      amount: u.isEmpty ? written : '$written $u',
      bare: u.isEmpty,
    );

    final fresh = _parseAll(edited.text);
    if (fresh.length != _items.length) return null;
    for (var j = 0; j < fresh.length; j++) {
      if (j != idx && fresh[j].draft.cacheKey != _items[j].draft.cacheKey) {
        return null;
      }
    }
    final d = fresh[idx].draft;
    if (d.foodText != item.draft.foodText ||
        d.matchText != item.draft.matchText ||
        d.quantity != probe.quantity ||
        d.isRange ||
        d.unit?.label != probe.unit?.label ||
        d.size != probe.size) {
      return null;
    }
    final pick = item.pick;
    final line = pick == null
        ? fresh[idx].base
        : parser.lineFor(d, _snapshot, pick.ref, markers: {pick.marker});
    if (line == null ||
        line.foodRef != oldRef ||
        line.markers.contains(Marker.assumed)) {
      return null;
    }
    return (text: edited.text, cursor: edited.cursor, line: line);
  }

  // The text edit: the first amount part is replaced by [amount], the other
  // parts are removed, or [amount] goes before the first food word when there
  // was none. Returns the text and the cursor moved with it.
  static ({String text, int cursor}) _edit(
    String text,
    int cursor,
    ItemDraft d, {
    required String amount,
    required bool bare,
  }) {
    final edits = <(int, int, String)>[];
    final spans = [...d.amountSpans]
      ..sort((a, b) => a.start.compareTo(b.start));
    if (spans.isEmpty) {
      final at = d.foodStart ?? d.span.start;
      edits.add((at, at, '$amount '));
    } else {
      edits.add((spans.first.start, spans.first.end, amount));
      var floor = spans.first.end;
      if (bare) {
        final of = RegExp(
          r'^[ \t ]+of(?=[ \t ]|$)',
          caseSensitive: false,
        ).firstMatch(text.substring(floor));
        if (of != null) {
          edits.add((floor, floor + of.end, ''));
          floor += of.end;
        }
      }
      for (final s in spans.skip(1)) {
        // Remove the part and the blanks before it (or after it, when the
        // part is at the start of the item).
        var a = s.start;
        while (a > floor && _isBlank(text.codeUnitAt(a - 1))) {
          a -= 1;
        }
        var b = s.end;
        if (a == s.start) {
          while (b < text.length && _isBlank(text.codeUnitAt(b))) {
            b++;
          }
        }
        edits.add((a, b, ''));
        floor = b;
      }
    }

    final out = StringBuffer();
    var at = 0;
    var shift = 0;
    var cur = cursor;
    for (final (s, e, r) in edits) {
      out
        ..write(text.substring(at, s))
        ..write(r);
      at = e;
      if (cursor >= e) {
        cur = cursor + shift + r.length - (e - s);
      } else if (cursor > s) {
        cur = s + shift + r.length;
      }
      shift += r.length - (e - s);
    }
    out.write(text.substring(at));
    return (text: out.toString(), cursor: cur);
  }
}

bool _isBlank(int c) => c == 0x20 || c == 0x09 || c == 0xA0;

String _number(double q) {
  if (q == q.roundToDouble() && q < 1e9) return q.round().toString();
  return q
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
