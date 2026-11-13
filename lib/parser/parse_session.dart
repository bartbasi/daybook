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
import 'line.dart';
import 'normalize.dart';
import 'parser.dart';
import 'rank.dart';
import 'search_index.dart';
import 'split.dart';
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

class _Pick {
  const _Pick(this.ref, this.marker);
  final String ref;
  final Marker marker;
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

  // Parsed items by everything parseItem reads, so a hit is always right.
  final Map<String, _Cached> _cache = {};
  int _parsed = 0;
  Ranker? _ranker;
  late final Map<String, IndexFood> _usdaFoods = {
    for (final f in parser.usda.foods) f.ref: f,
  };

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
  /// parse differently; the sticky corrections stay. Giving the same snapshot
  /// again changes nothing.
  void setSnapshot(UserSnapshot snapshot) {
    if (identical(snapshot, _snapshot)) return;
    _snapshot = snapshot;
    _ranker = null;
    _cache.clear();
    _rebuild(_text);
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
  /// a barcode). The pick follows the item while the user types (9.1). False,
  /// and nothing changes, when there is no such typed line, the line is a saved
  /// meal, or the food is not in the USDA data or the user's snapshot (send the
  /// snapshot that holds a new local food before picking it).
  bool pickFood(Span line, String foodRef, {Marker marker = Marker.yourPick}) {
    final item = _itemAt(line);
    if (item == null || item.base.state == LineState.aliasOrSavedMeal) {
      return false;
    }
    final picked = _pickLine(item, _Pick(foodRef, marker));
    if (picked == null) return false;
    item.pick = _Pick(foodRef, marker);
    item.line = picked;
    _publish();
    return true;
  }

  /// Drops the pick of the line at [line]; the line goes back to normal
  /// matching. False when it had none.
  bool clearPick(Span line) {
    final item = _itemAt(line);
    if (item == null || item.pick == null) return false;
    item.pick = null;
    item.line = _restamped(item.base, item.draft);
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
    final m = _rankerOf().match(
      item.draft.foodText,
      negation: !item.draft.negationProtected,
    );
    return Alternatives(
      FoodChoice(ref, l.foodName ?? ref, _dataset(ref), l.nutrients[_energyId]),
      [
        for (final c in _rankerOf().alternatives(m, currentRef: ref))
          _choice(c, item.draft, m.words),
      ],
    );
  }

  /// The sheet's search box (5.7). With [forLine] the energy of each food is
  /// worked out for that typed line's amount; otherwise it is null.
  List<FoodChoice> search(String text, {Span? forLine}) {
    final draft = forLine == null ? null : _itemAt(forLine)?.draft;
    return [
      for (final c in _rankerOf().search(text))
        draft == null
            ? FoodChoice(c.ref, c.description, c.food.dataset, null)
            : _choice(
                c,
                draft,
                readQuery(
                  draft.foodText,
                  negation: !draft.negationProtected,
                ).words,
              ),
    ];
  }

  /// Rewrites only the amount of the typed [line] in [text] (8.3): the old
  /// quantity and unit are replaced by [quantity] and [unit], or
  /// `<quantity> <unit> ` is put at the start of the item when it had none.
  /// Other amount words, such as a multiplier, are removed so the item reads
  /// as [quantity] and no more. Food words are never touched. Returns the new
  /// text and where [cursor] goes: it keeps its place in the text around the
  /// change, or lands at the end of the new amount when it was inside the old
  /// one.
  ///
  /// [unit] is a unit the parser reads (`g`, `oz`, `tbsp`, `cup`, `slice`,
  /// `large`), or empty for a bare count. Anything after a comma is dropped,
  /// because a comma would split the item. A quantity that is not finite and
  /// above zero, or a line with no span, leaves the text as it is.
  static ({String text, int cursor}) withAmount(
    String text,
    int cursor,
    Line line, {
    required double quantity,
    String unit = '',
  }) {
    final span = line.span;
    if (span == null || !quantity.isFinite || quantity <= 0) {
      return (text: text, cursor: cursor);
    }
    final u = unit.split(',').first.trim();
    final amount = u.isEmpty ? _number(quantity) : '${_number(quantity)} $u';

    // Edits in text order: start, end, replacement.
    final edits = <(int, int, String)>[];
    final spans = [...line.amountSpans]
      ..sort((a, b) => a.start.compareTo(b.start));
    if (spans.isEmpty) {
      edits.add((span.start, span.start, '$amount '));
    } else {
      edits.add((spans.first.start, spans.first.end, amount));
      var floor = spans.first.end;
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

  // Rebuilding.

  void _rebuild(String text) {
    final drafts = splitItems(text, names: _snapshot.names);
    final items = <_Item>[];
    for (final d in drafts) {
      final base = _baseLine(d);
      if (base != null) items.add(_Item(d, base));
    }
    _carryPicks(_text, text, items);
    for (final i in items) {
      i.line = i.pick == null
          ? _restamped(i.base, i.draft)
          : (_pickLine(i, i.pick!) ?? _restamped(i.base, i.draft));
    }
    // Nothing above changes the session until it has all worked.
    _text = text;
    _items = items;
    _publish();
  }

  void _publish() {
    _lines = List.unmodifiable([for (final i in _items) _withCursor(i.line)]);
  }

  // 9.2: a not found item that has the cursor (after its start, up to and
  // including its end) is plain typing. The same test as Parser.parseMeal; the
  // parser does not expose it as a function.
  //
  // Session rule that 9.2 does not cover: when the cursor is at the end of the
  // text and only blanks lie between the item's end and the cursor, the item
  // is still being typed ("2 " and "2 sl "), so it stays plain. It becomes Not
  // found when the cursor moves elsewhere or more text follows.
  Line _withCursor(Line l) {
    final s = l.span;
    if (l.state != LineState.notFound || s == null) return l;
    final inside = _cursor > s.start && _cursor <= s.end;
    final typingOn =
        _cursor > s.end &&
        _cursor == _text.length &&
        _text.substring(s.end).trim().isEmpty;
    return inside || typingOn ? l.asPlain() : l;
  }

  _Item? _itemAt(Span span) {
    for (final i in _items) {
      if (i.draft.span == span) return i;
    }
    return null;
  }

  // The parse of an item, from the cache when everything the parser reads is
  // the same. The span is not part of the key: a hit is given its new place.
  Line? _baseLine(ItemDraft d) {
    final key = [
      d.foodText,
      d.hasFoodWords,
      d.quantity,
      d.multiplier,
      d.isRange,
      d.unit?.label,
      d.size,
      d.negationProtected,
    ].join('\u0001');
    var hit = _cache[key];
    if (hit == null) {
      _parsed++;
      hit = _Cached(parser.parseItem(d, _snapshot));
      if (_cache.length >= _cacheLimit) _cache.clear();
      _cache[key] = hit;
    }
    final line = hit.line;
    return line == null ? null : _restamped(line, d);
  }

  // The line with the item's own place in the text.
  Line _restamped(Line l, ItemDraft d) {
    if (l.span == d.span && _sameSpans(l.amountSpans, d.amountSpans)) return l;
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
      learnedKey: l.learnedKey,
      span: d.span,
      multiplier: l.multiplier,
      items: l.items,
      savedMealId: l.savedMealId,
      amountSpans: d.amountSpans,
      foodText: l.foodText,
    );
  }

  static bool _sameSpans(List<Span> a, List<Span> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Sticky corrections (9.1).

  // Moves the picks of the old items to the new items. [items] are the new
  // items, without picks yet.
  void _carryPicks(String oldText, String newText, List<_Item> items) {
    final old = [
      for (final i in _items)
        if (i.pick != null) i,
    ];
    if (old.isEmpty) return;

    // The changed region: the longest common start and end of the two texts.
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

    final taken = <_Item>{};
    _Item? findAt(Span span) {
      for (final i in items) {
        if (!taken.contains(i) &&
            i.base.state != LineState.aliasOrSavedMeal &&
            i.draft.span == span) {
          return i;
        }
      }
      return null;
    }

    for (final o in old) {
      final span = o.draft.span;
      _Item? target;
      // Wholly before the region, or wholly after it: kept, shifted by the
      // change in length. The item must still be there with that span.
      if (span.end <= p) {
        target = findAt(span);
      } else if (span.start >= oldEnd) {
        target = findAt(Span(span.start + delta, span.end + delta));
      }
      // Overlapping it, or no longer the same item: kept only when the new
      // learned key equals the old one.
      if (target == null) {
        final a = mapStart(span.start);
        final b = mapEnd(span.end);
        for (final i in items) {
          if (taken.contains(i) ||
              i.base.state == LineState.aliasOrSavedMeal ||
              i.draft.span.start > b ||
              i.draft.span.end < a ||
              i.base.learnedKey != o.base.learnedKey) {
            continue;
          }
          target = i;
          break;
        }
      }
      if (target != null) {
        target.pick = o.pick;
        taken.add(target);
      }
    }
  }

  // The line a pick makes (8.3): the picked food with the item's own amount.
  // Null when the food cannot be found.
  Line? _pickLine(_Item item, _Pick pick) {
    final d = item.draft;
    final ref = pick.ref;
    final food = _food(ref);
    if (food == null) return null;
    final key = item.base.learnedKey;
    // A learned amount is used only when the learned match is this food (7.2:
    // a changed food clears the amount).
    final learned = key == null ? null : _snapshot.learned[key];
    final r = resolveAmount(
      d,
      food,
      foodWords: readQuery(d.foodText, negation: !d.negationProtected).words,
      learned:
          learned != null && learned.foodRef == ref && learned.quantity != null
          ? LearnedAmount(learned.quantity!, learned.unitLabel ?? '')
          : null,
    );
    return Line(
      state: r.assumed ? LineState.amountAssumed : LineState.matched,
      foodRef: ref,
      foodName: _name(ref) ?? ref,
      quantity: r.quantity,
      unitLabel: r.unitLabel,
      baseQuantity: r.baseQuantity,
      baseUnit: r.baseUnit,
      nutrients: scaleNutrients(food, r.baseQuantity),
      markers: {pick.marker, if (r.assumed) Marker.assumed},
      learnedKey: key,
      span: d.span,
      amountSpans: d.amountSpans,
      foodText: d.foodText,
    );
  }

  // Foods and the sheet.

  PortionFood? _food(String ref) => ref.startsWith('local:')
      ? _snapshot.foods[ref]?.food
      : parser.loadUsda(ref);

  String? _name(String ref) => ref.startsWith('local:')
      ? _snapshot.foods[ref]?.name
      : _usdaFoods[ref]?.description;

  String _dataset(String ref) =>
      ref.startsWith('local:') ? 'local' : (_usdaFoods[ref]?.dataset ?? '');

  Ranker _rankerOf() => _ranker ??= Ranker(
    parser.usda,
    user: _snapshot.index,
    history: _snapshot.history,
  );

  FoodChoice _choice(Candidate c, ItemDraft d, List<String> words) {
    final food = _food(c.ref);
    double? kcal;
    if (food != null) {
      final r = resolveAmount(d, food, foodWords: words);
      kcal = scaleNutrients(food, r.baseQuantity)[_energyId];
    }
    return FoodChoice(c.ref, c.description, c.food.dataset, kcal);
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
