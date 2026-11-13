// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Live re-parsing for one typed box (grammar 8.3, 9.1, 9.2, 12.3). A session
// holds the text, the cursor, the typed lines and the sticky corrections
// ("your pick"). On every text change it splits the text again, re-parses only
// the items it has not parsed before, and carries each pick to the item it
// belongs to. Pure Dart, deterministic, no timers and no clock. The worker
// (parse_worker.dart) runs one session per typed box off the main thread.

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

/// One entry of the correction sheet's unit picker (8.3, ruling R42): an
/// amount that typed text can express for the line's food. Writing [unitText]
/// after a number, and reading that item again, gives the same food and
/// [grams] for one of it.
class UnitChoice {
  const UnitChoice(this.label, this.unitText, this.grams);

  /// What the picker shows: `g`, `tbsp`, `cup, cooked`, `medium`, `serving`.
  /// Empty for a plain count that no portion names (the number alone).
  final String label;

  /// What is written after the number. Empty for a bare count.
  final String unitText;

  /// The amount of one of it in the food's base unit (grams for a USDA food).
  final double grams;
}

/// The line for a food added without typing (9.3): [ref] with [quantity] of
/// [unit] (a unit text as the picker gives it, empty for a bare count), or the
/// default amount when [quantity] is null. It is worked out by the same code
/// as a typed line with that amount, so state and markers are the same:
/// matched, or amount assumed when the amount is a default. Null when there is
/// no such food, or the amount cannot be written as text. The line has no
/// span.
Line? foodLineFor(
  Parser parser,
  UserSnapshot snapshot,
  String ref, {
  double? quantity,
  String unit = '',
}) {
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
  final l = parser.lineFor(d, snapshot, ref);
  if (l == null) return null;
  return Line(
    state: l.state,
    foodRef: l.foodRef,
    foodName: l.foodName,
    dataset: l.dataset,
    quantity: l.quantity,
    unitLabel: l.unitLabel,
    baseQuantity: l.baseQuantity,
    baseUnit: l.baseUnit,
    nutrients: l.nutrients,
    markers: l.markers,
  );
}

/// The unit picker for a food that is not a typed line (an added line, 9.3):
/// the same choices as [ParseSession.unitChoices], each checked by working out
/// one of it with [foodLineFor], the code that gives the added line its amount.
/// Empty for an unknown food.
List<UnitChoice> unitChoicesForFood(
  Parser parser,
  UserSnapshot snapshot,
  String ref,
) {
  final food = parser.foodFor(ref, snapshot);
  if (food == null) return const [];
  return _unitChoices(
    food,
    (t) => foodLineFor(parser, snapshot, ref, quantity: 1, unit: t),
  );
}

// The unit picker (8.3): grams and ounces, the volume units, each of the
// food's own portions that can be typed, then "serving" and a bare count, each
// only at an amount no earlier choice has. [read] gives the line for one of a
// unit text, or null when the text cannot express it; a choice is listed only
// when that line has the amount offered and is not assumed. The same unit text
// with the same amount is one choice.
List<UnitChoice> _unitChoices(
  PortionFood food,
  Line? Function(String unitText) read,
) {
  final out = <UnitChoice>[];
  void add(
    String label,
    List<String> texts, {
    double? grams,
    bool asTyped = false,
    bool onlyNew = false,
  }) {
    for (final t in texts) {
      final l = read(t);
      final g = l?.baseQuantity;
      if (l == null || g == null || l.markers.contains(Marker.assumed)) {
        continue;
      }
      // A unit that reads back as another one ("oz" as a fluid ounce, 4.2) is
      // not offered under its own name.
      if (asTyped && l.unitLabel != t) continue;
      if (grams != null && (g - grams).abs() > 0.05) continue;
      if (out.any((c) => c.unitText == t && c.grams == g)) return;
      // "serving" and a bare count only fill a gap: not at an amount that is
      // already listed.
      if (onlyNew && out.any((c) => (c.grams - g).abs() <= 0.05)) return;
      out.add(UnitChoice(label, t, g));
      return;
    }
  }

  for (final u in const ['g', 'oz', 'tsp', 'tbsp', 'cup', 'fl oz', 'ml']) {
    add(u, [u], asTyped: true);
  }
  for (final p in food.portions.usable) {
    if (p.label.startsWith(defaultPortionText)) continue;
    add(p.rest, [
      if (p.unit != null) p.unitLead,
      for (final w in p.phraseWords)
        if (sizeWords.containsKey(w) || unitForWord(w) != null) w,
      '',
    ], grams: p.gramsPerUnit);
  }
  add('serving', const ['serving'], onlyNew: true);
  add('', const [''], onlyNew: true);
  return out;
}

// Sticky corrections (9.1, R43).
//
// A pick remembers the key it was picked with, the span it follows and the
// item it is on now (that item's span and draft). After an edit the span is
// carried through it ([_Edit.map]); the pick's item is the new item that
// overlaps the carried span most (the earlier one on a tie). The pick applies
// when that item's key is the pick's key; otherwise it is suspended and waits.
// While it applies, its span is its item's span; while it is suspended, its
// span is cut to the part inside its item, so it never takes in a neighbour.
//
// The item is unchanged by an edit when the edit lies wholly outside it and a
// new item has the old one's draft at the old one's carried span. A suspended
// pick is dropped when an edit leaves its item unchanged (the edit was
// elsewhere), unless the edit only added or removed blanks next to it; when
// no new item overlaps its span (its item was deleted); when a new pick is
// made on its item; or when its food is gone.
// A pick that applies is dropped only with its item or its food.
class _Pick {
  const _Pick(
    this.ref,
    this.marker,
    this.key,
    this.span,
    this.item,
    this.itemKey, {
    required this.applies,
  });

  final String ref;
  final Marker marker;

  /// The learned key (7.1) of the item when it was picked.
  final String? key;

  /// The text the pick follows.
  final Span span;

  /// The item the pick is on now: its span and [ItemDraft.cacheKey].
  final Span item;
  final String itemKey;

  /// False while the pick is suspended.
  final bool applies;

  _Pick applyTo(_Item i) => _Pick(
    ref,
    marker,
    key,
    i.draft.span,
    i.draft.span,
    i.draft.cacheKey,
    applies: true,
  );

  _Pick suspendOn(_Item i, Span carried) {
    final s = i.draft.span;
    return _Pick(
      ref,
      marker,
      key,
      Span(
        carried.start > s.start ? carried.start : s.start,
        carried.end < s.end ? carried.end : s.end,
      ),
      s,
      i.draft.cacheKey,
      applies: false,
    );
  }
}

// "The amount was set in the sheet" (7.2): an item whose assumed amount the
// user set with rewriteAmount. It follows its item while the item's draft
// stays the same, and is cleared by any edit that changes the draft.
class _Mark {
  const _Mark(this.item, this.itemKey);
  final Span item;
  final String itemKey;
}

final _blanks = RegExp(r'^[ \t ]*$');

// The changed region of one edit (9.1 step 1): [start, oldEnd) of the old text
// became [start, newEnd) of the new text.
class _Edit {
  const _Edit(
    this.start,
    this.oldEnd,
    this.newEnd, {
    this.blanks = false,
    this.none = false,
  });

  /// The longest common start and the longest common end of [a] and [b].
  factory _Edit.between(String a, String b) {
    if (a == b) return _Edit(a.length, a.length, a.length, none: true);
    final shortest = a.length < b.length ? a.length : b.length;
    var p = 0;
    while (p < shortest && a.codeUnitAt(p) == b.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < shortest - p &&
        a.codeUnitAt(a.length - 1 - s) == b.codeUnitAt(b.length - 1 - s)) {
      s++;
    }
    final oldEnd = a.length - s;
    final newEnd = b.length - s;
    return _Edit(
      p,
      oldEnd,
      newEnd,
      blanks:
          _blanks.hasMatch(a.substring(p, oldEnd)) &&
          _blanks.hasMatch(b.substring(p, newEnd)),
    );
  }

  final int start;
  final int oldEnd;
  final int newEnd;

  /// Only blanks (spaces, tabs, no-break spaces) were added or removed.
  final bool blanks;

  /// The text did not change (new user data).
  final bool none;

  /// [s] in the new text: before the region it keeps its place, after it it
  /// shifts by the change in length, and over it it stretches or shrinks with
  /// it. Text typed exactly at either end of [s] is outside it.
  Span map(Span s) {
    if (s.end <= start) return s;
    final delta = newEnd - oldEnd;
    if (s.start >= oldEnd) return Span(s.start + delta, s.end + delta);
    return Span(
      s.start < start ? s.start : start,
      s.end > oldEnd ? s.end + delta : newEnd,
    );
  }

  /// True when only blanks of [old] (the text before the edit) lie between the
  /// region and [s], a span of it: the region is next to [s] or in it.
  bool nextTo(String old, Span s) {
    if (start > s.end) return _blanks.hasMatch(old.substring(s.end, start));
    if (oldEnd < s.start) {
      return _blanks.hasMatch(old.substring(oldEnd, s.start));
    }
    return true;
  }
}

// A sheet edit (rewriteAmount, removeItem) whose text the screen is about to
// set. Its region is known exactly, so it is used instead of the common start
// and end, and a mark it makes is placed when the text arrives.
class _Pending {
  const _Pending(this.from, this.to, this.edit, this.mark);
  final String from;
  final String to;
  final _Edit edit;
  final _Mark? mark;
}

class _Item {
  _Item(this.draft, this.base);

  final ItemDraft draft;

  /// The parse of the item with no correction.
  final Line base;

  /// The pick that applies to it, if any.
  _Pick? pick;

  /// "The amount was set in the sheet".
  bool marked = false;

  /// What the screen shows, before the cursor rule: [base] or the pick's line,
  /// with the mark.
  late Line line;

  void show(Line? picked) {
    final l = picked ?? base;
    line = marked ? l.copyWith(assumedAmountSetInSheet: true) : l;
  }
}

class _Cached {
  const _Cached(this.line);
  final Line? line;
}

int _overlap(Span a, Span b) {
  final lo = a.start > b.start ? a.start : b.start;
  final hi = a.end < b.end ? a.end : b.end;
  return hi > lo ? hi - lo : 0;
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
  List<_Pick> _picks = const [];
  List<_Mark> _marks = const [];
  _Pending? _pending;

  // New user data that could not be parsed yet.
  UserSnapshot? _waiting;

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
  /// new data fails, this throws and the session stays as it was, with the old
  /// data; the new data waits, and every [setText] tries it again until it
  /// parses (a newer snapshot replaces it).
  void setSnapshot(UserSnapshot snapshot) {
    if (identical(snapshot, _snapshot)) {
      _waiting = null;
      return;
    }
    _waiting = snapshot;
    _takeUp(_text);
  }

  // Parses [text] with the waiting user data. On failure the session stays as
  // it was and the data keeps waiting.
  void _takeUp(String text) {
    final oldSnapshot = _snapshot;
    final oldCache = _cache;
    _snapshot = _waiting!;
    _cache = {};
    try {
      _rebuild(text);
    } catch (_) {
      _snapshot = oldSnapshot;
      _cache = oldCache;
      rethrow;
    }
    _waiting = null;
  }

  /// The text and the cursor (an index into [text]) after a change. User data
  /// that failed to parse in [setSnapshot] is tried again first; if it still
  /// fails, the text is parsed with the data the session has.
  void setText(String text, int cursor) {
    final before = _cursor;
    _cursor = cursor;
    try {
      if (_waiting != null) {
        try {
          _takeUp(text);
          return;
        } catch (_) {
          // Still failing; that failure was reported when the data came.
        }
        _rebuild(text);
      } else if (text == _text && (_items.isNotEmpty || text.isEmpty)) {
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
  /// a barcode). It replaces any pick the item had, suspended or not, and
  /// follows the item while the user types (9.1). False, and nothing changes,
  /// when there is no such typed line, the line is a saved meal, or the food is
  /// not in the USDA data or the user's snapshot (send the snapshot that holds
  /// a new local food before picking it).
  bool pickFood(Span line, String foodRef, {Marker marker = Marker.yourPick}) {
    final item = _itemAt(line);
    if (item == null || item.base.state == LineState.aliasOrSavedMeal) {
      return false;
    }
    final pick = _Pick(
      foodRef,
      marker,
      item.base.learnedKey,
      line,
      line,
      item.draft.cacheKey,
      applies: true,
    );
    final picked = _pickLine(item, pick);
    if (picked == null) return false;
    _picks = [
      for (final p in _picks)
        if (p.item != line) p,
      pick,
    ];
    item.pick = pick;
    item.show(picked);
    _publish();
    return true;
  }

  /// Drops the pick of the line at [line], suspended or not; the line goes
  /// back to normal matching. False when it had none.
  bool clearPick(Span line) {
    final item = _itemAt(line);
    if (item == null || !_picks.any((p) => p.item == line)) return false;
    _picks = [
      for (final p in _picks)
        if (p.item != line) p,
    ];
    item.pick = null;
    item.show(null);
    _publish();
    return true;
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

  /// [foodLineFor] with this session's user data.
  Line? lineForFood(String ref, {double? quantity, String unit = ''}) =>
      foodLineFor(parser, _snapshot, ref, quantity: quantity, unit: unit);

  /// Rewrites only the amount of the typed line at [line] in [text] (8.3) and
  /// returns the new text and where [cursor] goes, or null when it cannot be
  /// done as asked. [text] is the text the line came from; it must be the
  /// session's text now. The session's text does not change: the screen puts
  /// the new text in the box, and the setText that follows carries the picks
  /// through this exact change.
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
  ///
  /// A saved meal header (6.4) takes a quantity only ([unit] empty): its
  /// multiplier. The result must be the same saved meal with that multiplier.
  ///
  /// When the line's amount was assumed because none was typed or the typed
  /// unit could not be converted (the cases where 7.3 uses a learned amount),
  /// its item is marked once the new text is set:
  /// [Line.assumedAmountSetInSheet] (7.2). A typed range is the user's own
  /// amount and is not marked. A line already marked stays marked through a
  /// second change in the sheet.
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
    final header = item.base.state == LineState.aliasOrSavedMeal;
    final r = header
        ? _tryMultiplier(item, quantity, unit, cursor)
        : _tryAmount(item, quantity, unit, cursor);
    if (r == null) return null;
    final mark =
        !header &&
        (item.marked ||
            (item.line.markers.contains(Marker.assumed) &&
                !item.draft.isRange));
    _pending = _Pending(
      _text,
      r.text,
      r.edit,
      mark ? _Mark(r.draft.span, r.draft.cacheKey) : null,
    );
    return (text: r.text, cursor: r.cursor);
  }

  /// "Remove from meal" for the typed line at [line] (8.3): the new text and
  /// where [cursor] goes, or null when the item cannot be removed cleanly.
  /// [text] must be the session's text now. The item's text goes, with the
  /// separators after it (or, for the last item, the ones before it, and no
  /// blank or separator is left at the end of the text). It is
  /// verified by reading the new text again: every other item must read
  /// exactly as before, in order, and the removed one must be gone; cutting
  /// "2 eggs" out of "2 eggs and toast" as "and toast" would fail that, so
  /// the "and" goes with it. The session's text does not change; picks on the
  /// other items follow them when the screen sets the new text.
  ({String text, int cursor})? removeItem(String text, int cursor, Span line) {
    if (text != _text) return null;
    final idx = _items.indexWhere((i) => i.draft.span == line);
    if (idx < 0) return null;
    final s = line;
    // The separator after the item, and the one before it.
    final after = _sepAfter.matchAsPrefix(text, s.end)?.end ?? s.end;
    final before = _sepBefore.firstMatch(text.substring(0, s.start))?.start;
    final last = idx == _items.length - 1;
    final cuts = <(int, int)>[
      if (!last) (s.start, after),
      if (before != null) (before, s.end),
      if (last) (s.start, after),
      (s.start, s.end),
    ];
    for (var (a, b) in cuts) {
      // A cut with only blanks and separators after it takes them, and those
      // before it, so nothing is left dangling at the end of the text.
      if (_sepAfter.matchAsPrefix(text, b)!.end == text.length) {
        b = text.length;
        a = _junkAtEnd.firstMatch(text.substring(0, a))!.start;
      }
      final t = text.substring(0, a) + text.substring(b);
      final fresh = _parseAll(t);
      if (fresh.length != _items.length - 1) continue;
      var same = true;
      for (var j = 0; j < fresh.length && same; j++) {
        final old = _items[j < idx ? j : j + 1];
        same = fresh[j].draft.cacheKey == old.draft.cacheKey;
      }
      if (!same) continue;
      _pending = _Pending(_text, t, _Edit(a, b, a), null);
      final c = cursor >= b ? cursor - (b - a) : (cursor > a ? a : cursor);
      return (text: t, cursor: c);
    }
    return null;
  }

  // Blanks and separators at the end of a text.
  static final _junkAtEnd = RegExp(
    r'(?:\s|[,;+.&]|w/|\b(?:and|with|plus)\b)*$',
    caseSensitive: false,
  );

  // Separators (2.2, 2.5) with the blanks around them.
  static final _sepAfter = RegExp(
    r'\s*(?:(?:[,;+.&]|w/|\b(?:and|with|plus)\b)\s*)*',
    caseSensitive: false,
  );
  static final _sepBefore = RegExp(
    r'\s*(?:(?:[,;+.&]|w/|\b(?:and|with|plus)\b)\s*)+$',
    caseSensitive: false,
  );

  /// The unit picker for the typed line at [line] (8.3, ruling R42): the
  /// amounts that typed text can express for the line's food. A choice is
  /// listed only if writing it into the item and reading the item again gives
  /// the same food, the amount shown, and no Assumed marker. Grams and ounces
  /// (not "oz" where it would be read as a fluid ounce), the volume units the
  /// food can convert, each of the food's own portions that can be typed, then
  /// "serving" and a bare count, each only at an amount not already listed;
  /// labels that start with "Quantity not specified" are never listed. Empty
  /// for a line with no food.
  List<UnitChoice> unitChoices(Span line) {
    final item = _itemAt(line);
    final ref = item?.line.foodRef;
    if (item == null || ref == null) return const [];
    final food = parser.foodFor(ref, _snapshot);
    if (food == null) return const [];
    return _unitChoices(food, (t) => _tryAmount(item, 1, t, 0)?.line);
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
    final p = _pending;
    // The text a sheet edit made: its own region, and its mark.
    final sheet = p != null && p.from == _text && p.to == text ? p : null;
    final edit = sheet?.edit ?? _Edit.between(_text, text);

    final picks = _carry(edit, items);
    bool isItem(Span at, String key) =>
        items.any((i) => i.draft.span == at && i.draft.cacheKey == key);
    final marks = <_Mark>[
      for (final m in _marks)
        if (isItem(edit.map(m.item), m.itemKey))
          _Mark(edit.map(m.item), m.itemKey),
    ];
    final made = sheet?.mark;
    if (made != null && isItem(made.item, made.itemKey)) marks.add(made);
    for (final i in items) {
      i.marked = marks.any((m) => m.item == i.draft.span);
    }
    final kept = <_Pick>[];
    final picked = <_Item, Line>{};
    for (final p in picks) {
      if (p.applies) {
        final i = items.firstWhere((i) => i.draft.span == p.item);
        final l = _pickLine(i, p);
        // The picked food is gone from the user's data: the pick is dropped.
        if (l == null) continue;
        i.pick = p;
        picked[i] = l;
      } else if (parser.foodFor(p.ref, _snapshot) == null) {
        continue;
      }
      kept.add(p);
    }
    for (final i in items) {
      i.show(picked[i]);
    }

    // Nothing above changes the session until it has all worked.
    if (sheet != null || !edit.none) _pending = null;
    _text = text;
    _items = items;
    _picks = kept;
    _marks = marks;
    _publish();
  }

  // Carries every pick through [e] to the new [items] (9.1, R43; the rule is
  // written out above [_Pick]).
  List<_Pick> _carry(_Edit e, List<_Item> items) {
    final out = <_Pick>[];
    final claims = <_Item, List<(_Pick, Span, int)>>{};
    for (final p in _picks) {
      final span = e.map(p.span);
      _Item? own;
      var most = 0;
      for (final i in items) {
        final o = _overlap(i.draft.span, span);
        if (o > most) {
          own = i;
          most = o;
        }
      }
      // Its item was deleted.
      if (own == null) continue;
      // Unchanged: the edit was wholly outside the item and the item reads
      // the same at its new place. An edit inside it ("slices" to "slice")
      // changes it even when the parser reads it the same.
      final at = e.map(p.item);
      final unchanged =
          (p.item.end <= e.start || p.item.start >= e.oldEnd) &&
          items.any((i) => i.draft.span == at && i.draft.cacheKey == p.itemKey);
      // A suspended pick whose item an edit elsewhere left as it was: the user
      // has moved on.
      if (!p.applies &&
          !e.none &&
          unchanged &&
          !(e.blanks && e.nextTo(_text, p.item))) {
        continue;
      }
      final fits =
          own.base.state != LineState.aliasOrSavedMeal &&
          own.base.learnedKey == p.key;
      if (fits && (p.applies || !unchanged)) {
        claims.putIfAbsent(own, () => []).add((p, span, most));
      } else {
        out.add(p.suspendOn(own, span));
      }
    }
    // One pick per item: the one that overlaps it most, then the earlier one.
    for (final MapEntry(key: item, value: list) in claims.entries) {
      list.sort((a, b) {
        final c = b.$3.compareTo(a.$3);
        return c != 0 ? c : a.$2.start.compareTo(b.$2.start);
      });
      out.add(list.first.$1.applyTo(item));
      for (final (p, span, _) in list.skip(1)) {
        out.add(p.suspendOn(item, span));
      }
    }
    return out;
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

  _Item? _itemAt(Span span) {
    for (final i in _items) {
      if (i.draft.span == span) return i;
    }
    return null;
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

  // The line a pick makes (8.3): the picked food with the item's own amount.
  // Null when the food cannot be found.
  Line? _pickLine(_Item item, _Pick pick) =>
      parser.lineFor(item.draft, _snapshot, pick.ref, markers: {pick.marker});

  // Foods and the sheet.

  String _dataset(String ref) => ref.startsWith('local:')
      ? (_snapshot.foods[ref]?.dataset ?? 'local')
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

  // True when every item of [fresh] but the one at [idx] has the draft it has
  // now, in order.
  bool _othersSame(List<_Item> fresh, int idx) {
    if (fresh.length != _items.length) return false;
    for (var j = 0; j < fresh.length; j++) {
      if (j != idx && fresh[j].draft.cacheKey != _items[j].draft.cacheKey) {
        return false;
      }
    }
    return true;
  }

  // The new text for [item]'s amount, verified by reading it again. Null when
  // the result would not be [q] of [unit] on the same food with everything else
  // unchanged.
  ({String text, int cursor, _Edit edit, ItemDraft draft, Line line})?
  _tryAmount(_Item item, double q, String unit, int cursor) {
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
    if (!_othersSame(fresh, idx)) return null;
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
    return (
      text: edited.text,
      cursor: edited.cursor,
      edit: edited.edit,
      draft: d,
      line: line,
    );
  }

  // A saved meal header's multiplier (6.4): the quantity only, verified the
  // same way. The result must be the same saved meal with [q] as its
  // multiplier, and every other item unchanged.
  ({String text, int cursor, _Edit edit, ItemDraft draft, Line line})?
  _tryMultiplier(_Item item, double q, String unit, int cursor) {
    if (unit.trim().isNotEmpty) return null;
    final written = _written(q);
    if (written == null) return null;
    final idx = _items.indexOf(item);
    if (idx < 0) return null;
    final edited = _edit(
      _text,
      cursor,
      item.draft,
      amount: written,
      bare: true,
    );
    final fresh = _parseAll(edited.text);
    if (!_othersSame(fresh, idx)) return null;
    final f = fresh[idx];
    if (f.base.state != LineState.aliasOrSavedMeal ||
        f.base.savedMealId != item.base.savedMealId ||
        f.base.multiplier != double.parse(written) ||
        f.draft.isRange ||
        f.draft.foodText != item.draft.foodText) {
      return null;
    }
    return (
      text: edited.text,
      cursor: edited.cursor,
      edit: edited.edit,
      draft: f.draft,
      line: f.base,
    );
  }

  // The text edit: the first amount part is replaced by [amount], the other
  // parts are removed, or [amount] goes before the first food word when there
  // was none. Returns the text, the cursor moved with it, and the region that
  // changed.
  static ({String text, int cursor, _Edit edit}) _edit(
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
    return (
      text: out.toString(),
      cursor: cur,
      edit: _Edit(edits.first.$1, edits.last.$2, edits.last.$2 + shift),
    );
  }
}

// The quantity as it would be written, or null when it would be written as 0
// or is not finite.
String? _written(double q) {
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

bool _isBlank(int c) => c == 0x20 || c == 0x09 || c == 0xA0;

String _number(double q) {
  if (q == q.roundToDouble() && q < 1e9) return q.round().toString();
  return q
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
