// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';
import 'dart:math';

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_session.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/split.dart';
import 'package:daybook/parser/user_snapshot.dart';
import 'package:daybook/parser/user_snapshot_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Live re-parsing (grammar 8.3, 9.1, 9.2, 12.3): the item cache, sticky
// corrections across edits, the half-typed item, the amount rewrite. Real
// USDA database.

const _egg = 'usda:2707153';
const _coffee = 'usda:2710373';
const _halfAndHalf = 'usda:2705594';

UserSnapshotData _data({
  int version = 1,
  bool learned = false,
  bool foods = true,
}) => UserSnapshotData(
  version: version,
  foods: [
    if (foods)
      const UserFoodData(
        ref: 'local:1',
        name: 'Protein bar',
        kind: 'custom',
        baseUnit: 'g',
        baseAmount: 50,
        portions: [PortionData('1 bar', 50)],
        nutrients: {1008: 200, 203: 20},
      ),
    const UserFoodData(
      ref: 'local:2',
      name: 'No sugar cola',
      kind: 'off',
      baseUnit: 'ml',
      baseAmount: 100,
      nutrients: {1008: 1},
    ),
  ],
  savedMeals: [
    const SavedMealData(
      id: 1,
      name: 'Usual oatmeal',
      items: [
        SavedMealItemData(
          foodRef: _egg,
          foodName: 'Egg',
          quantity: 1,
          unitLabel: '',
          baseQuantity: 50,
          baseUnit: 'g',
          nutrients: {1008: 72},
        ),
      ],
    ),
  ],
  aliases: [const AliasData('my oatmeal', 1)],
  // A scanned product counts for the splitter once it has been logged (R40).
  historyCounts: const {'local:2': 1},
  learned: [
    if (learned)
      const LearnedMatchData(
        key: 'toast',
        foodRef: _egg,
        foodName: 'Egg, whole',
      ),
  ],
);

String _sum(Line l) {
  final nutrients = (l.nutrients.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key)));
  final markers = (l.markers.toList()..sort((a, b) => a.index - b.index));
  return [
    l.state.name,
    l.foodRef,
    l.foodName,
    l.quantity,
    l.unitLabel,
    l.baseQuantity,
    l.baseUnit,
    nutrients.map((e) => '${e.key}:${e.value}').join(','),
    markers.map((m) => m.name).join(','),
    l.learnedKey,
    l.span,
    l.amountSpans.join(),
    l.foodText,
    l.plain,
    l.multiplier,
    l.savedMealId,
    l.fromLearnedMatch,
    l.items.map(_sum).join(';'),
  ].join('|');
}

// The parser's line, with the session's extra rule on top: a not found item
// followed only by blanks, with the cursor at the end of the text, is plain.
Line _expectedPlain(Line l, String text, int cursor) {
  final span = l.span;
  if (l.state == LineState.notFound &&
      span != null &&
      cursor > span.end &&
      cursor == text.length &&
      RegExp(r'^[ \t\u00A0]*$').hasMatch(text.substring(span.end))) {
    return l.asPlain();
  }
  return l;
}

// An independent model of the picks (grammar 9.1 and ruling R43), used to
// check the session over generated edits. It is written from the rule, not
// from the session's code, and works on a plain parse of each text.
//
// The rule: a pick remembers the key it was picked with, the span it follows,
// and the item it is on. After an edit, the span is carried through the
// changed region (before it: kept; after it: shifted; over it: stretched or
// shrunk with it). The pick's item is the new item that overlaps the carried
// span most (the first one on a tie). If that item is not a saved meal and
// its key is the pick's key, the pick applies to it; otherwise it is
// suspended on it. The pick's old item is unchanged when a new item has its
// draft at its carried span. A suspended pick is dropped when the text changed,
// its item is unchanged, and the edit was not only blanks with nothing but
// blanks between it and the item; and it is never restored onto an unchanged
// item. Any pick is dropped when no new item overlaps its span, when a new
// pick is made on its item, when it is cleared, or when its food is gone. An
// item takes at most one pick: the one that overlaps it most, then the one
// whose span starts first; the others are suspended on it. A pick that
// applies follows its whole item; a suspended one follows only the part of its
// span inside its item.
class _MItem {
  _MItem(this.span, this.key, this.draft, this.header);
  final Span span;
  final String? key;
  final String draft;
  final bool header;
}

class _MPick {
  _MPick(this.ref, this.key, this.follows, this.on, this.onDraft, this.live);
  final String ref;
  final String? key;
  Span follows;
  Span on;
  String onDraft;
  bool live;
}

class _Model {
  var picks = <_MPick>[];
  final dropped = <String, int>{};
  var restored = 0;

  static const movedOn = 'an edit elsewhere left its item as it was';
  static const deleted = 'its item was deleted';
  static const repicked = 'a new pick was made on its item';
  static const cleared = 'it was cleared';
  static const foodGone = 'its food left the user data';

  void _drop(String why) => dropped[why] = (dropped[why] ?? 0) + 1;

  static bool _onlyBlanks(String s) =>
      s.split('').every((c) => c == ' ' || c == '\t' || c == ' ');

  void edit(String before, String after, List<_MItem> items) {
    var head = 0;
    while (head < before.length &&
        head < after.length &&
        before[head] == after[head]) {
      head++;
    }
    var tail = 0;
    while (tail < before.length - head &&
        tail < after.length - head &&
        before[before.length - 1 - tail] == after[after.length - 1 - tail]) {
      tail++;
    }
    final cutEnd = before.length - tail;
    final pasteEnd = after.length - tail;
    final grow = pasteEnd - cutEnd;
    final changed = before != after;
    final blanksOnly =
        _onlyBlanks(before.substring(head, cutEnd)) &&
        _onlyBlanks(after.substring(head, pasteEnd));

    Span carry(Span s) {
      if (s.end <= head) return s;
      if (s.start >= cutEnd) return Span(s.start + grow, s.end + grow);
      return Span(min(s.start, head), s.end > cutEnd ? s.end + grow : pasteEnd);
    }

    bool besideOrIn(Span s) {
      if (head > s.end) return _onlyBlanks(before.substring(s.end, head));
      if (cutEnd < s.start) {
        return _onlyBlanks(before.substring(cutEnd, s.start));
      }
      return true;
    }

    int overlap(Span a, Span b) =>
        max(0, min(a.end, b.end) - max(a.start, b.start));

    final next = <_MPick>[];
    final claims = <_MItem, List<(_MPick, Span, int)>>{};
    for (final p in picks) {
      final s = carry(p.follows);
      _MItem? best;
      var most = 0;
      for (final it in items) {
        if (overlap(it.span, s) > most) {
          best = it;
          most = overlap(it.span, s);
        }
      }
      if (best == null) {
        _drop(deleted);
        continue;
      }
      final was = carry(p.on);
      final same = items.any((it) => it.span == was && it.draft == p.onDraft);
      if (!p.live && changed && same && !(blanksOnly && besideOrIn(p.on))) {
        _drop(movedOn);
        continue;
      }
      if (!best.header && best.key == p.key && (p.live || !same)) {
        claims.putIfAbsent(best, () => []).add((p, s, most));
      } else {
        next.add(_suspend(p, s, best));
      }
    }
    for (final MapEntry(key: it, value: list) in claims.entries) {
      list.sort(
        (a, b) => a.$3 != b.$3
            ? b.$3.compareTo(a.$3)
            : a.$2.start.compareTo(b.$2.start),
      );
      final w = list.first.$1;
      if (!w.live) restored++;
      w
        ..live = true
        ..follows = it.span
        ..on = it.span
        ..onDraft = it.draft;
      next.add(w);
      for (final (p, s, _) in list.skip(1)) {
        next.add(_suspend(p, s, it));
      }
    }
    picks = next;
  }

  static _MPick _suspend(_MPick p, Span s, _MItem it) => p
    ..live = false
    ..follows = Span(max(s.start, it.span.start), min(s.end, it.span.end))
    ..on = it.span
    ..onDraft = it.draft;

  /// Whether a pick at [at] is accepted.
  bool pick(Span at, String ref, List<_MItem> items, bool known) {
    final it = items.where((i) => i.span == at).firstOrNull;
    if (it == null || it.header || !known) return false;
    for (final _ in picks.where((p) => p.on == at)) {
      _drop(repicked);
    }
    picks = [
      ...picks.where((p) => p.on != at),
      _MPick(ref, it.key, at, at, it.draft, true),
    ];
    return true;
  }

  bool clear(Span at) {
    final had = picks.where((p) => p.on == at).length;
    for (var i = 0; i < had; i++) {
      _drop(cleared);
    }
    picks = picks.where((p) => p.on != at).toList();
    return had > 0;
  }

  void foodsLeft(bool Function(String ref) known) {
    for (final _ in picks.where((p) => !known(p.ref))) {
      _drop(foodGone);
    }
    picks = picks.where((p) => known(p.ref)).toList();
  }

  List<String> shown() => [
    for (final p in picks)
      if (p.live) '${p.on.start}-${p.on.end} ${p.ref} ${p.key}',
  ]..sort();
}

/// Types into a session the way a keyboard does: every change inserts or
/// deletes one character at the cursor, and the session sees each one.
class _Keys {
  _Keys(this.s, String start) : text = start, cursor = start.length {
    s.setText(text, cursor);
  }

  final ParseSession s;
  String text;
  int cursor;

  void moveTo(int c) {
    cursor = c;
    s.setText(text, cursor);
  }

  /// Types [chars] one at a time; [each] runs after every keystroke.
  void type(String chars, [void Function(String text)? each]) {
    for (final c in chars.split('')) {
      text = text.substring(0, cursor) + c + text.substring(cursor);
      cursor++;
      s.setText(text, cursor);
      each?.call(text);
    }
  }

  /// Deletes [n] characters before the cursor, one at a time.
  void backspace(int n, [void Function(String text)? each]) {
    for (var i = 0; i < n; i++) {
      text = text.substring(0, cursor - 1) + text.substring(cursor);
      cursor--;
      s.setText(text, cursor);
      each?.call(text);
    }
  }

  /// Select all and type (or delete with an empty [t]).
  void replaceAll(String t) {
    text = t;
    cursor = t.length;
    s.setText(text, cursor);
  }

  /// Takes the session's text and cursor, after the screen set them.
  void reload() {
    text = s.text;
    cursor = s.cursor;
  }

  /// The line whose span starts at [start].
  Line lineAt(int start) => s.lines.firstWhere((l) => l.span!.start == start);

  List<Span> pickedSpans() => [
    for (final l in s.lines)
      if (l.markers.contains(Marker.yourPick)) l.span!,
  ];
}

void main() {
  late Parser parser;
  late Database db;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_session');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    // Registered after the folder's delete, so it runs first: the loader's
    // statements are released, then the database is closed, then the file goes.
    addTearDown(db.close);
    final loader = SqliteUsdaFoods(db);
    addTearDown(loader.dispose);
    parser = Parser(SearchIndex.build(readUsdaFoods(db)), loader.call);
  });

  ParseSession newSession({UserSnapshotData? data}) =>
      ParseSession(parser, snapshot: UserSnapshot.from(data ?? _data()));

  // Picks the first other food the sheet lists for line [i] and returns it.
  String pickOther(ParseSession s, int i) {
    final span = s.lines[i].span!;
    final ref = s.alternatives(span).others.first.ref;
    expect(s.pickFood(span, ref), isTrue);
    return ref;
  }

  bool picked(Line l) => l.markers.contains(Marker.yourPick);

  group('the three cases of 9.1', () {
    test('typing , 1 banana at the end keeps every correction above it', () {
      final s = newSession()..setText('2 eggs, 2 slices toast', 22);
      final eggs = pickOther(s, 0);
      final toast = pickOther(s, 1);
      s.setText('2 eggs, 2 slices toast, 1 banana', 31);
      expect(s.lines, hasLength(3));
      expect(s.lines[0].foodRef, eggs);
      expect(picked(s.lines[0]), isTrue);
      expect(s.lines[1].foodRef, toast);
      expect(picked(s.lines[1]), isTrue);
      expect(picked(s.lines[2]), isFalse);
    });

    test('2 slices toast to 3 slices toast keeps the pick, new grams', () {
      final s = newSession()..setText('200 g chicken', 13);
      final ref = pickOther(s, 0);
      expect(s.lines[0].baseQuantity, 200);
      s.setText('300 g chicken', 13);
      expect(s.lines[0].foodRef, ref);
      expect(picked(s.lines[0]), isTrue);
      expect(s.lines[0].quantity, 300);
      expect(s.lines[0].baseQuantity, 300);
      expect(s.lines[0].state, LineState.matched);

      // The grammar's own wording.
      final t = newSession()..setText('2 slices toast', 14);
      final bread = pickOther(t, 0);
      t.setText('3 slices toast', 14);
      expect(t.lines[0].foodRef, bread);
      expect(picked(t.lines[0]), isTrue);
      expect(t.lines[0].quantity, 3);
    });

    test('3 slices white toast changes the key, so the pick is dropped', () {
      final s = newSession()..setText('2 slices toast', 14);
      s.pickFood(s.lines[0].span!, _halfAndHalf);
      expect(s.lines[0].foodRef, _halfAndHalf);
      s.setText('3 slices white toast', 20);
      expect(picked(s.lines[0]), isFalse);
      expect(s.lines[0].foodRef, isNot(_halfAndHalf));
      // Normal matching applies: the same line as a plain parse.
      expect(
        _sum(s.lines[0]),
        _sum(parser.parseMeal('3 slices white toast', 20, s.snapshot).single),
      );
      // R43: the pick is only suspended, and comes back with the key.
      s.setText('3 slices toast', 14);
      expect(picked(s.lines[0]), isTrue);
      expect(s.lines[0].foodRef, _halfAndHalf);
    });
  });

  group('a pick', () {
    test('keeps the item\'s own amount and is matched, "Your pick"', () {
      final s = newSession()..setText('200 g toast', 11);
      expect(s.pickFood(s.lines[0].span!, _egg), isTrue);
      final l = s.lines[0];
      expect(l.foodRef, _egg);
      expect(l.foodName, startsWith('Egg, whole'));
      expect(l.baseQuantity, 200);
      expect(l.state, LineState.matched);
      expect(l.markers, {Marker.yourPick});
      expect(l.learnedKey, 'toast');
      expect(l.nutrients[1008], isNotNull);
    });

    test(
      'with no usable amount is amount assumed, "Your pick" and "Assumed"',
      () {
        final s = newSession()..setText('toast', 5);
        s.pickFood(s.lines[0].span!, _egg);
        expect(s.lines[0].state, LineState.amountAssumed);
        expect(s.lines[0].markers, {Marker.yourPick, Marker.assumed});
        expect(s.lines[0].baseQuantity, 50);
      },
    );

    test('can be marked Scanned', () {
      final s = newSession()..setText('2 yogurt', 8);
      s.pickFood(s.lines[0].span!, 'local:1', marker: Marker.scanned);
      expect(s.lines[0].markers, contains(Marker.scanned));
      expect(s.lines[0].foodRef, 'local:1');
      expect(s.lines[0].foodName, 'Protein bar');
    });

    test(
      'on a not found line makes it matched, even with the cursor in it',
      () {
        final s = newSession()..setText('purple monkey dishwasher', 24);
        expect(s.lines[0].plain, isTrue);
        expect(s.pickFood(s.lines[0].span!, _egg), isTrue);
        expect(s.lines[0].state, isNot(LineState.notFound));
        expect(s.lines[0].plain, isFalse);
      },
    );

    test('is refused for a missing line, a saved meal or an unknown food', () {
      final s = newSession()..setText('my oatmeal, 2 eggs', 18);
      expect(s.lines[0].state, LineState.aliasOrSavedMeal);
      expect(s.pickFood(s.lines[0].span!, _egg), isFalse);
      expect(s.pickFood(const Span(0, 3), _egg), isFalse);
      expect(s.pickFood(s.lines[1].span!, 'usda:1'), isFalse);
      expect(s.pickFood(s.lines[1].span!, 'local:99'), isFalse);
      expect(picked(s.lines[1]), isFalse);
    });

    test('can be cleared, and the line is the plain parse again', () {
      final s = newSession()..setText('2 slices toast', 14);
      final before = _sum(s.lines[0]);
      s.pickFood(s.lines[0].span!, _halfAndHalf);
      expect(s.clearPick(s.lines[0].span!), isTrue);
      expect(_sum(s.lines[0]), before);
      expect(s.clearPick(s.lines[0].span!), isFalse);
      s.setText('2 slices toast, 1 egg', 21);
      expect(picked(s.lines[0]), isFalse);
    });

    test('uses a learned amount only when the learned food is the pick', () {
      final data = _data(learned: true);
      final s = newSession(data: data)..setText('toast', 5);
      expect(s.lines[0].foodRef, _egg);
      s.pickFood(s.lines[0].span!, _halfAndHalf);
      // The learned row is for the egg: the pick gets the default amount.
      expect(s.lines[0].foodRef, _halfAndHalf);
      expect(s.lines[0].markers, contains(Marker.assumed));
    });
  });

  group('span shifting', () {
    const text = '2 eggs, 1 tbsp butter, coffee';

    ParseSession picks() {
      final s = newSession()..setText(text, text.length);
      for (var i = 0; i < 3; i++) {
        s.pickFood(s.lines[i].span!, [_egg, _halfAndHalf, _coffee][i]);
      }
      return s;
    }

    void expectKept(ParseSession s, String t, List<String> words) {
      final refs = [_egg, _halfAndHalf, _coffee];
      var from = 0;
      for (var i = 0; i < 3; i++) {
        final at = t.indexOf(words[i], from);
        final l = s.lines.firstWhere((l) => l.span!.start == at);
        expect(l.span, Span(at, at + words[i].length));
        expect(l.foodRef, refs[i]);
        expect(picked(l), isTrue);
        from = at + words[i].length;
      }
    }

    test('typing at the start shifts every span', () {
      final s = picks();
      final t = '1 banana, $text';
      s.setText(t, 10);
      expect(s.lines, hasLength(4));
      expect(picked(s.lines[0]), isFalse);
      expectKept(s, t, ['2 eggs', '1 tbsp butter', 'coffee']);
    });

    test('typing in the middle keeps both sides', () {
      final s = picks();
      final t = '2 eggs, 1 banana, 1 tbsp butter, coffee';
      s.setText(t, 17);
      expect(s.lines, hasLength(4));
      expectKept(s, t, ['2 eggs', '1 tbsp butter', 'coffee']);
    });

    test('typing at the end keeps all of them', () {
      final s = picks();
      final t = '$text, 1 banana';
      s.setText(t, t.length);
      expect(s.lines, hasLength(4));
      expectKept(s, t, ['2 eggs', '1 tbsp butter', 'coffee']);
    });

    test('deleting text before an item shifts it back', () {
      final s = picks();
      final t = text.substring(8); // "1 tbsp butter, coffee"
      s.setText(t, 0);
      expect(s.lines, hasLength(2));
      expect(s.lines[0].foodRef, _halfAndHalf);
      expect(picked(s.lines[0]), isTrue);
      expect(s.lines[0].span, const Span(0, 13));
      expect(s.lines[1].foodRef, _coffee);
      expect(s.lines[1].span, const Span(15, 21));
    });

    test(
      'a unicode fraction that clean-up changes does not move the spans',
      () {
        // Spans are indexes into the text as typed (2.1).
        var t = '½ cup milk, 2 eggs';
        final s = newSession()..setText(t, t.length);
        s.pickFood(s.lines[1].span!, _egg);
        for (final next in [
          '¼ cup milk, 2 eggs', // one fraction for another
          '1 cup milk, 2 eggs', // the fraction becomes a plain digit
          '2½ cups milk, 2 eggs', // a longer amount
          'cup milk, 2 eggs', // the fraction is deleted
          '⅓ cup ⅔ milk, 2 eggs', // two fractions
        ]) {
          t = next;
          s.setText(t, t.length);
          final l = s.lines.last;
          expect(l.span, Span(t.indexOf('2 eggs'), t.length), reason: t);
          expect(picked(l), isTrue, reason: t);
          expect(l.foodRef, _egg, reason: t);
        }
        // An item that contains the fraction keeps its own pick while its key
        // stays the same.
        final u = newSession()..setText('½ cup milk', 10);
        u.pickFood(u.lines[0].span!, _egg);
        u.setText('¾ cup milk', 10);
        expect(picked(u.lines[0]), isTrue);
        expect(u.lines[0].quantity, 0.75);
        u.setText('¾ cup oat milk', 14);
        expect(picked(u.lines[0]), isFalse);
      },
    );

    test('surrogate pairs are counted in UTF-16 units', () {
      var t = '😀 eggs, toast';
      final s = newSession()..setText(t, t.length);
      s.pickFood(s.lines.last.span!, _egg);
      t = '😀😀 eggs, toast';
      s.setText(t, t.length);
      expect(s.lines.last.span, Span(t.indexOf('toast'), t.length));
      expect(picked(s.lines.last), isTrue);
    });

    test('a pick on the last item survives typing in its own words if the key '
        'stays', () {
      final s = newSession()..setText('2 eggs, toast', 13);
      s.pickFood(s.lines[1].span!, _egg);
      for (final t in [
        '2 eggs, toasts',
        '2 eggs, 2 toast',
        '2 eggs, toast 2',
      ]) {
        s.setText(t, t.length);
        expect(picked(s.lines.last), isTrue, reason: t);
      }
      s.setText('2 eggs, toasty', 14);
      expect(picked(s.lines.last), isFalse);
    });

    test('two items with the same words keep their own picks', () {
      final s = newSession()..setText('toast, toast', 12);
      s.pickFood(s.lines[1].span!, _egg);
      s.setText('1 toast, toast', 14);
      expect(picked(s.lines[0]), isFalse);
      expect(picked(s.lines[1]), isTrue);
    });
  });

  group('the half-typed last item (9.2)', () {
    test('example 62: 2 eggs, 2 sl with the cursor at the end', () {
      final s = newSession()..setText('2 eggs, 2 sl', 12);
      expect(s.lines, hasLength(2));
      expect(s.lines[0].state, LineState.matched);
      expect(s.lines[0].foodRef, _egg);
      expect(s.lines[0].baseQuantity, 100);
      expect(s.lines[1].state, LineState.notFound);
      expect(s.lines[1].plain, isTrue);
      expect(s.lines[1].foodText, 'sl');
      expect(
        s.lines.map(_sum),
        parser.parseMeal('2 eggs, 2 sl', 12, s.snapshot).map(_sum),
      );
    });

    test('the cursor leaving the item turns it into a real not found line', () {
      final s = newSession()..setText('2 eggs, 2 sl', 12);
      final parsed = s.itemsParsed;
      s.setText('2 eggs, 2 sl', 3);
      expect(s.lines[1].plain, isFalse);
      expect(s.lines[1].state, LineState.notFound);
      s.setText('2 eggs, 2 sl', 7); // on the comma, before the item
      expect(s.lines[1].plain, isFalse);
      s.setText('2 eggs, 2 sl', 8); // at the start of the item: not under it
      expect(s.lines[1].plain, isFalse);
      s.setText('2 eggs, 2 sl', 9);
      expect(s.lines[1].plain, isTrue);
      s.setText('2 eggs, 2 sl', 10); // inside
      expect(s.lines[1].plain, isTrue);
      s.setText('2 eggs, 2 sl', -1); // no cursor
      expect(s.lines[1].plain, isFalse);
      // Moving the cursor only does not parse anything.
      expect(s.itemsParsed, parsed);
    });

    test('only a not found item is softened', () {
      final s = newSession()..setText('2 eggs, 2 slices', 16);
      expect(s.lines[1].state, LineState.notFound);
      expect(s.lines[1].plain, isTrue);
      s.setText('2 eggs, 2 slices', 3);
      expect(s.lines[0].plain, isFalse);
      s.setText('2 eggs, 2 slices', 5);
      expect(s.lines[0].plain, isFalse);
      expect(s.lines[0].state, LineState.matched);
    });

    test(
      'typing the words through, the item at the cursor is always plain',
      () {
        const t = '2 eggs, 2 slices toast';
        final s = newSession();
        for (var n = 1; n <= t.length; n++) {
          s.setText(t.substring(0, n), n);
          // A space typed after an item ends it (the cursor is then outside
          // it), so only the other keystrokes are checked.
          if (t[n - 1] == ' ') continue;
          for (final l in s.lines) {
            if (l.state == LineState.notFound) {
              expect(l.plain, isTrue, reason: '$n');
            }
          }
        }
      },
    );
  });

  group('a number typed and then a space (session rule, not in 9.2)', () {
    test('"2 " with the cursor at the end is still plain', () {
      final s = newSession()..setText('2 ', 2);
      expect(s.lines.single.state, LineState.notFound);
      expect(s.lines.single.plain, isTrue);
      s.setText('2 sl ', 5);
      expect(s.lines.single.plain, isTrue);
      // A new line is a separator like a comma: it ends the item.
      s.setText('2 \n ', 4);
      expect(s.lines.single.plain, isFalse);
      s.setText('purple monkey dishwasher\n', 25);
      expect(s.lines.single.plain, isFalse);
      s.setText('purple monkey dishwasher\t \u00A0', 27);
      expect(s.lines.single.plain, isTrue);
    });

    test('"2 , eggs" with the cursor after the space is not plain', () {
      final s = newSession()..setText('2 , eggs', 2);
      expect(s.lines[0].state, LineState.notFound);
      expect(s.lines[0].plain, isFalse);
    });

    test('"eggs, 2 " at the end is plain; the cursor in "eggs" ends it', () {
      final s = newSession()..setText('eggs, 2 ', 8);
      expect(s.lines[1].state, LineState.notFound);
      expect(s.lines[1].plain, isTrue);
      s.setText('eggs, 2 ', 2);
      expect(s.lines[1].plain, isFalse);
      s.setText('eggs, 2 ', 8);
      expect(s.lines[1].plain, isTrue);
      s.setText('eggs, 2 , toast', 8);
      expect(s.lines[1].plain, isFalse);
    });
  });

  group('a name that starts with No', () {
    test(
      'a product named "No sugar cola" is found, as the parser finds it',
      () {
        final s = newSession()..setText('no sugar cola', 13);
        expect(s.lines.single.foodRef, 'local:2');
        expect(
          _sum(s.lines.single),
          _sum(parser.parseMeal('no sugar cola', 13, s.snapshot).single),
        );
        final a = s.alternatives(s.lines.single.span!);
        expect(a.current!.ref, 'local:2');
      },
    );
  });

  group('picks while editing, one keystroke at a time (9.1)', () {
    // Each test types into a session the way a keyboard does: one character
    // inserted or deleted at the cursor per change, spaces included.

    test('typing an amount after a picked item keeps the pick the whole way '
        '(the key stays "toast")', () {
      final k = _Keys(newSession(), '2 eggs, toast');
      final ref = pickOther(k.s, 1);
      k.type(' 2 slices', (t) {
        final toast = k.lineAt(8);
        expect(toast.learnedKey, 'toast', reason: t);
        expect(picked(toast), isTrue, reason: t);
        expect(toast.foodRef, ref, reason: t);
      });
      expect(k.text, '2 eggs, toast 2 slices');
      expect(k.s.lines.last.unitLabel, 'slice');
    });

    test('eggs x3: suspended at "eggs x", back at "eggs x3"', () {
      final k = _Keys(newSession(), 'eggs');
      final ref = pickOther(k.s, 0);
      final seen = <String, bool>{};
      k.type(' x3', (t) => seen[t] = picked(k.s.lines.single));
      expect(seen, {'eggs ': true, 'eggs x': false, 'eggs x3': true});
      expect(k.s.lines.single.foodRef, ref);
      expect(k.s.lines.single.quantity, 3);
    });

    test('the last word backspaced and typed again', () {
      final k = _Keys(newSession(), '2 slices toast');
      final ref = pickOther(k.s, 0);
      k.backspace(5, (t) => expect(k.s.lines.any(picked), isFalse, reason: t));
      expect(k.text, '2 slices ');
      final seen = <bool>[];
      k.type('toast', (t) => seen.add(picked(k.s.lines.single)));
      expect(seen, [false, false, false, false, true]);
      expect(k.s.lines.single.foodRef, ref);
    });

    test('two like items: a merge suspends the pick and the split puts it '
        'back on its own item', () {
      final k = _Keys(newSession(), 'toast, toast');
      final ref = pickOther(k.s, 1);
      k.moveTo(7);
      k.backspace(1);
      expect(k.text, 'toast,toast');
      expect(k.pickedSpans(), [const Span(6, 11)]);
      k.backspace(1);
      expect(k.text, 'toasttoast');
      expect(k.pickedSpans(), isEmpty);
      k.type(',');
      expect(k.text, 'toast,toast');
      expect(k.pickedSpans(), [const Span(6, 11)]);
      expect(k.s.lines[1].foodRef, ref);
      expect(picked(k.s.lines[0]), isFalse);
    });

    test('an amount backspaced across the separator and typed again stays on '
        'its own item', () {
      final k = _Keys(newSession(), 'toast, 2 slices toast');
      final ref = pickOther(k.s, 1);
      k.moveTo(8);
      k.backspace(3, (t) => expect(k.s.lines.any(picked), isFalse, reason: t));
      expect(k.text, 'toast slices toast');
      k.type(', 3', (t) {
        if (t != 'toast, 3 slices toast') {
          expect(k.s.lines.any(picked), isFalse, reason: t);
        }
      });
      expect(k.text, 'toast, 3 slices toast');
      expect(k.pickedSpans(), [const Span(7, 21)]);
      expect(k.s.lines[1].foodRef, ref);
      expect(k.s.lines[1].quantity, 3);
    });

    test('9.1 case 1: typing , 1 banana at the end keeps every pick', () {
      final k = _Keys(newSession(), '2 eggs, 2 slices toast');
      final eggs = pickOther(k.s, 0);
      final toast = pickOther(k.s, 1);
      k.type(', 1 banana', (t) {
        expect(k.lineAt(0).foodRef, eggs, reason: t);
        expect(picked(k.lineAt(0)), isTrue, reason: t);
        expect(k.lineAt(8).foodRef, toast, reason: t);
        expect(picked(k.lineAt(8)), isTrue, reason: t);
      });
      expect(k.s.lines, hasLength(3));
      expect(picked(k.s.lines[2]), isFalse);
    });

    test('9.1 case 2: 2 slices toast to 3 slices toast by backspacing', () {
      final k = _Keys(newSession(), '2 slices toast');
      final ref = pickOther(k.s, 0);
      final grams = k.s.lines.single.baseQuantity!;
      k.moveTo(1);
      k.backspace(1);
      expect(k.text, ' slices toast');
      expect(picked(k.s.lines.single), isFalse);
      // While suspended the line is what a fresh parse shows.
      expect(
        _sum(k.s.lines.single),
        _sum(parser.parseMeal(k.text, 0, k.s.snapshot).single),
      );
      k.type('3');
      expect(picked(k.s.lines.single), isTrue);
      expect(k.s.lines.single.foodRef, ref);
      expect(k.s.lines.single.quantity, 3);
      expect(k.s.lines.single.baseQuantity, closeTo(grams * 3 / 2, 1e-9));
    });

    test('9.1 case 3: 3 slices white toast suspends it, and an edit in '
        'another item drops it', () {
      final k = _Keys(newSession(), '3 slices toast, coffee');
      pickOther(k.s, 0);
      k.moveTo(9);
      k.type('white ', (t) {
        if (t != '3 slices white toast, coffee') return;
        expect(picked(k.s.lines[0]), isFalse);
        expect(
          _sum(k.s.lines[0]),
          _sum(parser.parseMeal(t, 15, k.s.snapshot)[0]),
        );
      });
      k.moveTo(k.text.length);
      k.type(' x2'); // the coffee item changes: the user has moved on
      k.moveTo(15);
      k.backspace(6);
      expect(k.text, '3 slices toast, coffee x2');
      expect(k.s.lines.any(picked), isFalse);
    });

    test('1 cup milk to 1 cu milk and back', () {
      final k = _Keys(newSession(), '1 cup milk');
      final ref = pickOther(k.s, 0);
      k.moveTo(5);
      k.backspace(1);
      expect(picked(k.s.lines.single), isFalse);
      k.type('p');
      expect(picked(k.s.lines.single), isTrue);
      expect(k.s.lines.single.foodRef, ref);
    });

    test('an item backspaced to nothing and typed again has no pick', () {
      final k = _Keys(newSession(), '2 eggs, toast');
      pickOther(k.s, 1);
      k.backspace(5);
      expect(k.text, '2 eggs, ');
      k.type('toast', (t) => expect(k.s.lines.any(picked), isFalse, reason: t));

      // Select all, delete, and a new meal that starts with the same food.
      final j = _Keys(newSession(), 'toast, 2 eggs');
      pickOther(j.s, 0);
      j.replaceAll('');
      expect(j.s.lines, isEmpty);
      j.type('toast, 1 egg', (t) {
        expect(j.s.lines.any(picked), isFalse, reason: t);
      });
    });

    test('typing in another item while suspended drops it', () {
      final k = _Keys(newSession(), '1 cup milk, 2 eggs');
      pickOther(k.s, 0);
      k.moveTo(5);
      k.backspace(1); // 1 cu milk: suspended
      k.moveTo(12);
      k.backspace(1);
      k.type('3'); // 3 eggs
      k.moveTo(4);
      k.type('p');
      expect(k.text, '1 cup milk, 3 eggs');
      expect(k.s.lines.any(picked), isFalse);
    });

    test('blanks typed or removed next to a suspended item keep it', () {
      final k = _Keys(newSession(), '1 cup milk, 2 eggs');
      final ref = pickOther(k.s, 0);
      k.moveTo(5);
      k.backspace(1); // 1 cu milk
      k.moveTo(9);
      k.type('  ');
      k.backspace(2);
      k.moveTo(0);
      k.type(' ');
      k.backspace(1);
      k.moveTo(4);
      k.type('p');
      expect(k.text, '1 cup milk, 2 eggs');
      expect(k.s.lines[0].foodRef, ref);
      expect(picked(k.s.lines[0]), isTrue);
    });

    test('a pick that applies survives any typing elsewhere, before and after '
        'it', () {
      final k = _Keys(newSession(), 'toast');
      final ref = pickOther(k.s, 0);
      void stillThere(String t) {
        final l = k.s.lines.firstWhere((l) => l.learnedKey == 'toast');
        expect(l.foodRef, ref, reason: t);
        expect(picked(l), isTrue, reason: t);
        expect(k.s.lines.where(picked), hasLength(1), reason: t);
      }

      k.moveTo(0);
      k.type(', ', stillThere);
      k.moveTo(0);
      k.type('2 eggs', stillThere);
      k.moveTo(k.text.length);
      k.type(', 1 banana and coffee', stillThere);
      k.moveTo(1);
      k.backspace(1, stillThere);
      k.type('3', stillThere);
      k.moveTo(k.text.length);
      k.backspace(10, stillThere);
      k.type('tea', stillThere);
      expect(k.text, '3 eggs, toast, 1 banana tea');
    });

    test('a pick made on an item replaces its suspended pick', () {
      final k = _Keys(newSession(), '1 cup milk');
      pickOther(k.s, 0);
      k.moveTo(5);
      k.backspace(1);
      expect(k.s.pickFood(k.s.lines[0].span!, _coffee), isTrue);
      k.type('p');
      expect(k.s.lines[0].foodRef, isNot(_coffee));
      expect(picked(k.s.lines[0]), isFalse);
    });

    test('clearing a suspended pick drops it', () {
      final k = _Keys(newSession(), '1 cup milk');
      pickOther(k.s, 0);
      k.moveTo(5);
      k.backspace(1);
      expect(k.s.clearPick(k.s.lines[0].span!), isTrue);
      k.type('p');
      expect(picked(k.s.lines[0]), isFalse);
    });

    test('a suspended pick on the first of two like items stays with it', () {
      final k = _Keys(newSession(), '1 cup milk, 1 cup milk');
      final ref = pickOther(k.s, 0);
      k.moveTo(5);
      k.backspace(1);
      expect(k.s.lines.any(picked), isFalse);
      k.type('p');
      expect(picked(k.s.lines[0]), isTrue);
      expect(k.s.lines[0].foodRef, ref);
      expect(picked(k.s.lines[1]), isFalse);
    });

    test('a suspended pick is not put on a saved meal header', () {
      final k = _Keys(newSession(), 'my oatmea');
      expect(k.s.pickFood(k.s.lines.single.span!, _egg), isTrue);
      k.type('l');
      expect(k.s.lines.single.state, LineState.aliasOrSavedMeal);
      expect(k.s.lines.single.markers, isNot(contains(Marker.yourPick)));
      k.backspace(1);
      expect(picked(k.s.lines.single), isTrue);
    });
  });

  group('a failed snapshot change', () {
    test('leaves the session with its old data and lines', () {
      var failing = false;
      final inner = SqliteUsdaFoods(db);
      addTearDown(inner.dispose);
      final flaky = Parser(
        parser.usda,
        (ref) => failing ? throw StateError('boom') : inner(ref),
      );
      final s = ParseSession(flaky, snapshot: UserSnapshot.from(_data()))
        ..setText('toast', 5);
      final before = _sum(s.lines.single);
      failing = true;
      expect(
        () =>
            s.setSnapshot(UserSnapshot.from(_data(version: 2, learned: true))),
        throwsStateError,
      );
      failing = false;
      expect(s.snapshot.version, 1);
      s.setText('toast', 5);
      expect(s.snapshot.version, 1);
      expect(_sum(s.lines.single), before);
      // And the new data goes in once the loader is back.
      s.setSnapshot(UserSnapshot.from(_data(version: 2, learned: true)));
      expect(s.snapshot.version, 2);
      expect(s.lines.single.foodRef, _egg);
      expect(s.lines.single.fromLearnedMatch, isTrue);
    });
  });

  group('a pick whose food leaves the snapshot', () {
    test('is dropped for good', () {
      final s = newSession()..setText('2 yogurt, toast', 15);
      s.pickFood(s.lines[0].span!, 'local:1');
      expect(picked(s.lines[0]), isTrue);
      final without = _data(version: 2);
      s.setSnapshot(
        UserSnapshot.from(
          UserSnapshotData(
            version: 2,
            savedMeals: without.savedMeals,
            aliases: without.aliases,
          ),
        ),
      );
      expect(picked(s.lines[0]), isFalse);
      s.setSnapshot(UserSnapshot.from(_data(version: 3)));
      expect(picked(s.lines[0]), isFalse, reason: 'it came back');
      s.setText('3 yogurt, toast', 15);
      expect(picked(s.lines[0]), isFalse);
    });
  });

  group('the parser\'s additions the session uses', () {
    test('a learned match is flagged on its line', () {
      final s = newSession(data: _data(learned: true))..setText('toast', 5);
      expect(s.lines[0].fromLearnedMatch, isTrue);
      s.pickFood(s.lines[0].span!, _halfAndHalf);
      expect(s.lines[0].fromLearnedMatch, isFalse);
    });

    test('the cache key separates drafts that parse differently', () {
      final a = splitItems(
        'no sugar cola without ice',
        names: UserSnapshot.from(_data()).names,
      ).single;
      final b = splitItems(
        'no sugar cola',
        names: UserSnapshot.from(_data()).names,
      ).single;
      expect(a.foodText, isNot(b.foodText));
      expect(a.matchText, b.matchText);
      expect(a.cacheKey, isNot(b.cacheKey));
      expect(a.cacheKey, a.cacheKey);
    });

    test(
      'a name with a protected "no" matches by the cut words everywhere',
      () {
        final s = newSession()..setText('no sugar cola without ice', 25);
        expect(s.lines.single.foodRef, 'local:2');
        expect(
          _sum(s.lines.single),
          _sum(
            parser
                .parseMeal('no sugar cola without ice', 25, s.snapshot)
                .single,
          ),
        );
        final a = s.alternatives(s.lines.single.span!);
        expect(a.current!.ref, 'local:2');
        s.pickFood(s.lines.single.span!, 'local:2');
        expect(s.lines.single.foodRef, 'local:2');
        expect(s.search('cola', forLine: s.lines.single.span), isNotEmpty);
      },
    );

    test('foodStart is where the first food word starts', () {
      ItemDraft one(String t) =>
          splitItems(t, names: UserSnapshot.from(_data()).names).single;
      expect(one('I had toast').foodStart, 6);
      expect(one('toast').foodStart, 0);
      expect(one('2 slices toast').foodStart, 9);
      expect(one('my oatmeal').foodStart, 0);
    });
  });

  group('added lines', () {
    test('a food with an amount is the line a typed item would be', () {
      final s = newSession();
      final added = s.lineForFood(_egg, quantity: 2)!;
      final typed = parser.parseMeal('2 eggs', -1, s.snapshot).single;
      expect(added.foodRef, _egg);
      expect(added.baseQuantity, typed.baseQuantity);
      expect(added.nutrients, typed.nutrients);
      expect(added.state, LineState.matched);
      expect(added.span, isNull);
      final grams = s.lineForFood(_egg, quantity: 100, unit: 'g')!;
      expect(grams.baseQuantity, 100);
      expect(grams.unitLabel, 'g');
    });

    test('with no amount it is the default, amount assumed', () {
      final s = newSession();
      final added = s.lineForFood(_egg)!;
      final typed = parser.parseMeal('eggs', -1, s.snapshot).single;
      expect(added.state, LineState.amountAssumed);
      expect(added.markers, contains(Marker.assumed));
      expect(added.baseQuantity, typed.baseQuantity);
    });

    test('an unknown food, or an amount that cannot be written, is null', () {
      final s = newSession();
      expect(s.lineForFood('usda:1', quantity: 1), isNull);
      expect(s.lineForFood(_egg, quantity: 0), isNull);
      expect(s.lineForFood(_egg, quantity: 1, unit: 'egg egg'), isNull);
    });
  });

  group('the cache', () {
    test('only the item being typed is parsed again', () {
      final s = newSession()
        ..setText('2 eggs, 2 slices toast, 1 tbsp butter', 37);
      expect(s.itemsParsed, 3);
      s.setText('2 eggs, 2 slices toast, 1 tbsp butter ', 38);
      expect(s.itemsParsed, 3);
      s.setText('2 eggs, 2 slices toast, 1 tbsp butter, c', 40);
      expect(s.itemsParsed, 4);
      s.setText('2 eggs, 2 slices toast, 1 tbsp butter, co', 41);
      expect(s.itemsParsed, 5);
    });

    test('an item that only moved is not parsed again', () {
      final s = newSession()..setText('2 eggs, 1 tbsp butter', 21);
      final parsed = s.itemsParsed;
      s.setText('1 banana, 2 eggs, 1 tbsp butter', 31);
      expect(s.itemsParsed, parsed + 1);
      expect(s.lines[1].span, const Span(10, 16));
    });

    test('a cached item shows the new place in the text', () {
      final s = newSession()..setText('2 eggs', 6);
      s.setText('  2 eggs', 8);
      expect(s.lines[0].span, const Span(2, 8));
      expect(s.lines[0].amountSpans, [const Span(2, 3)]);
    });

    test('a new snapshot version clears it and every item is parsed again', () {
      final s = newSession()..setText('toast, 2 eggs', 13);
      expect(s.cacheSize, 2);
      final before = s.itemsParsed;
      expect(s.lines[0].foodRef, isNot(_egg));
      s.setSnapshot(UserSnapshot.from(_data(version: 2, learned: true)));
      expect(s.cacheSize, 2); // rebuilt for the text that is there
      expect(s.itemsParsed, before + 2);
      // The new data decides: toast is now learned as the egg.
      expect(s.lines[0].foodRef, _egg);
      expect(s.snapshot.version, 2);
    });

    test('giving the same snapshot again keeps the cache', () {
      final s = newSession()..setText('toast, 2 eggs', 13);
      final before = s.itemsParsed;
      s.setSnapshot(s.snapshot);
      expect(s.itemsParsed, before);
    });

    test('picks survive a snapshot change', () {
      final s = newSession()..setText('toast, 2 eggs', 13);
      s.pickFood(s.lines[0].span!, _halfAndHalf);
      s.setSnapshot(UserSnapshot.from(_data(version: 2, learned: true)));
      expect(s.lines[0].foodRef, _halfAndHalf);
      expect(picked(s.lines[0]), isTrue);
    });

    test('it does not grow without limit', () {
      final s = newSession();
      for (var i = 0; i < 1500; i++) {
        s.setText('$i eggs', 3);
      }
      expect(s.cacheSize, lessThanOrEqualTo(500));
    });

    test('a failed parse leaves the session as it was', () {
      final bad = Parser(
        SearchIndex.build(readUsdaFoods(db)),
        (ref) => ref == _egg ? throw StateError('boom') : null,
      );
      final s = ParseSession(bad)..setText('purple monkey dishwasher', 24);
      expect(() => s.setText('2 eggs', 6), throwsStateError);
      expect(s.text, 'purple monkey dishwasher');
      expect(s.cursor, 24);
      expect(s.lines.single.state, LineState.notFound);
    });
  });

  group('the sheet', () {
    test('lists the current food, then up to 7 others with energy', () {
      final s = newSession()..setText('2 slices toast', 14);
      final a = s.alternatives(s.lines[0].span!);
      expect(a.current!.ref, s.lines[0].foodRef);
      expect(a.current!.kcal, s.lines[0].nutrients[1008]);
      expect(a.others.length, inInclusiveRange(1, 7));
      expect(a.others.map((c) => c.ref), isNot(contains(a.current!.ref)));
      expect(a.others.every((c) => c.kcal != null), isTrue);
    });

    test('the current food is the pick once picked', () {
      final s = newSession()..setText('2 slices toast', 14);
      s.pickFood(s.lines[0].span!, _egg);
      expect(s.alternatives(s.lines[0].span!).current!.ref, _egg);
    });

    test('a not found line has no candidates', () {
      final s = newSession()..setText('purple monkey dishwasher', 24);
      final a = s.alternatives(s.lines[0].span!);
      expect(a.current, isNull);
      expect(a.others, isEmpty);
      expect(s.alternatives(const Span(40, 41)).others, isEmpty);
    });

    test('search lists foods with energy for the line\'s amount', () {
      final s = newSession()..setText('200 g purple', 12);
      final r = s.search('egg', forLine: s.lines[0].span);
      expect(r, isNotEmpty);
      expect(r.length, lessThanOrEqualTo(20));
      expect(r.first.kcal, isNotNull);
      expect(s.search('egg').first.kcal, isNull);
      expect(s.search('protein bar').first.dataset, 'local');
    });
  });

  group('rewriting the amount (8.3)', () {
    // Rewrites line [i] of [text] in a session, or null when refused. On
    // success it also checks that reading the new text gives the amount asked
    // for.
    ({String text, int cursor})? rewrite(
      String text,
      int i,
      double q, {
      String unit = '',
      int? cursor,
    }) {
      final s = newSession()..setText(text, -1);
      return s.rewriteAmount(
        text,
        cursor ?? text.length,
        s.lines[i].span!,
        quantity: q,
        unit: unit,
      );
    }

    Line reparse(String text, int i) =>
        parser.parseMeal(text, -1, UserSnapshot.from(_data()))[i];

    test('a bare count', () {
      final r = rewrite('2 eggs', 0, 3)!;
      expect(r.text, '3 eggs');
      expect(reparse(r.text, 0).quantity, 3);
      expect(reparse(r.text, 0).baseQuantity, 150);
    });

    test('a unit', () {
      final r = rewrite('2 slices toast', 0, 100, unit: 'g')!;
      expect(r.text, '100 g toast');
      final l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel, l.baseQuantity), (100, 'g', 100));
    });

    test('a size word', () {
      expect(rewrite('2 large eggs', 0, 3)!.text, '3 eggs');
      final r = rewrite('2 eggs', 0, 3, unit: 'large')!;
      expect(r.text, '3 large eggs');
      expect(
        reparse(r.text, 0).baseQuantity,
        reparse('3 large eggs', 0).baseQuantity,
      );
    });

    test('a range becomes one number and is no longer assumed', () {
      for (final t in ['2 to 3 eggs', '2-3 eggs', '2 or 3 eggs']) {
        final before = reparse(t, 0);
        expect(before.markers, contains(Marker.assumed), reason: t);
        final r = rewrite(t, 0, 4)!;
        expect(r.text, '4 eggs', reason: t);
        expect(reparse(r.text, 0).quantity, 4);
        expect(reparse(r.text, 0).markers, isNot(contains(Marker.assumed)));
      }
    });

    test('a multiplier is folded into the new number', () {
      var r = rewrite('2 eggs x3', 0, 4)!;
      expect(r.text, '4 eggs');
      expect(reparse(r.text, 0).quantity, 4);
      r = rewrite('eggs x3', 0, 4)!;
      expect(reparse(r.text, 0).quantity, 4);
      expect(reparse(r.text, 0).foodText, 'eggs');
      r = rewrite('x3 eggs', 0, 5)!;
      expect(reparse(r.text, 0).quantity, 5);
    });

    test('an amount typed after the food', () {
      var r = rewrite('toast 2 slices', 0, 3, unit: 'slice')!;
      expect(r.text, 'toast 3 slice');
      var l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel, l.foodText), (3, 'slice', 'toast'));
      r = rewrite('eggs 2', 0, 3)!;
      expect(r.text, 'eggs 3');
      l = reparse(r.text, 0);
      expect((l.quantity, l.foodText), (3, 'eggs'));
    });

    test('a compound amount is replaced as a whole', () {
      final r = rewrite('1 cup 2 tbsp milk', 0, 300, unit: 'ml')!;
      expect(r.text, '300 ml milk');
      expect(reparse(r.text, 0).quantity, 300);
    });

    test('no amount: it goes before the first food word', () {
      var r = rewrite('toast', 0, 2, unit: 'slice')!;
      expect(r.text, '2 slice toast');
      var l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel, l.foodText), (2, 'slice', 'toast'));
      r = rewrite('coffee', 0, 1)!;
      expect(r.text, '1 coffee');
      r = rewrite('eggs, toast', 1, 150, unit: 'g')!;
      expect(r.text, 'eggs, 150 g toast');
    });

    test('leading filler stays in front of the amount', () {
      final r = rewrite('I had toast', 0, 2, unit: 'slice')!;
      expect(r.text, 'I had 2 slice toast');
      final l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel), (2, 'slice'));
      expect(l.foodRef, reparse('toast', 0).foodRef);
    });

    test('a name that starts with a filler word stays whole', () {
      final s = newSession(
        data: UserSnapshotData(
          version: 1,
          foods: const [
            UserFoodData(
              ref: 'local:3',
              name: 'My chili',
              kind: 'custom',
              baseUnit: 'g',
              baseAmount: 100,
              nutrients: {1008: 120},
            ),
          ],
        ),
      )..setText('my chili', 8);
      expect(s.lines.single.foodRef, 'local:3');
      final r = s.rewriteAmount(
        'my chili',
        8,
        s.lines.single.span!,
        quantity: 250,
        unit: 'g',
      )!;
      expect(r.text, '250 g my chili');
      s.setText(r.text, r.text.length);
      expect(s.lines.single.foodRef, 'local:3');
      expect(s.lines.single.baseQuantity, 250);
    });

    test('a leading a or an is an amount and is replaced', () {
      final r = rewrite('a banana', 0, 2)!;
      expect(r.text, '2 banana');
      expect(reparse(r.text, 0).quantity, 2);
    });

    test('only the line asked for changes', () {
      const t = '2 eggs, 2 slices sourdough toast, 1 tbsp butter';
      final r = rewrite(t, 1, 4, unit: 'slice')!;
      expect(r.text, '2 eggs, 4 slice sourdough toast, 1 tbsp butter');
      final before = parser.parseMeal(t, -1, UserSnapshot.from(_data()));
      final after = parser.parseMeal(r.text, -1, UserSnapshot.from(_data()));
      expect(after, hasLength(3));
      expect(after[0].foodRef, before[0].foodRef);
      expect(after[0].quantity, before[0].quantity);
      expect(after[1].foodText, before[1].foodText);
      expect(after[1].quantity, 4);
      expect(after[2].quantity, 1);
    });

    test('a pick stays on the line and the food does not change', () {
      final s = newSession()..setText('2 eggs, toast', 13);
      s.pickFood(s.lines[1].span!, _egg);
      final r = s.rewriteAmount(
        '2 eggs, toast',
        13,
        s.lines[1].span!,
        quantity: 100,
        unit: 'g',
      )!;
      s.setText(r.text, r.text.length);
      expect(picked(s.lines[1]), isTrue);
      expect(s.lines[1].baseQuantity, 100);
    });

    test('a unit that would change the text or the food is refused', () {
      // "1 egg eggs": the unit becomes food words.
      expect(rewrite('2 eggs', 0, 1, unit: 'egg'), isNull);
      // A phrase that is not one unit.
      expect(
        rewrite('2 slices toast', 0, 1, unit: 'medium or regular slice'),
        isNull,
      );
      // "cup, cooked" is cut at the comma and would pick another portion.
      expect(rewrite('2 eggs', 0, 1, unit: 'cup, cooked'), isNull);
      // A unit the food cannot convert.
      expect(rewrite('protein bar', 0, 1, unit: 'cup'), isNull);
      // Nothing was changed by any of them.
      final s = newSession()..setText('2 eggs', 6);
      expect(s.text, '2 eggs');
    });

    test('a quantity written as zero is refused', () {
      expect(rewrite('2 eggs', 0, 0.0004), isNull);
      expect(rewrite('2 eggs', 0, 0.0), isNull);
      expect(rewrite('2 eggs', 0, -1.0), isNull);
      expect(rewrite('2 eggs', 0, double.nan), isNull);
      expect(rewrite('2 eggs', 0, double.infinity), isNull);
    });

    test('a leftover "of" goes when the new amount has no unit', () {
      expect(rewrite('2 slices of toast', 0, 3)!.text, '3 toast');
      expect(
        rewrite('2 slices of toast', 0, 3, unit: 'slice')!.text,
        '3 slice of toast',
      );
      expect(
        rewrite('2 cups of milk', 0, 1, unit: 'cup')!.text,
        '1 cup of milk',
      );
    });

    test('a text that is not the session\'s text is refused', () {
      final s = newSession()..setText('2 eggs, toast', 13);
      final span = s.lines[0].span!;
      expect(s.rewriteAmount('toast', 5, span, quantity: 3), isNull);
      expect(
        s.rewriteAmount('2 eggs, toast', 13, const Span(40, 44), quantity: 3),
        isNull,
      );
      // A not found line has no amount to rewrite.
      final m = newSession()
        ..setText('my oatmeal, purple monkey dishwasher', 36);
      expect(
        m.rewriteAmount(m.text, 36, m.lines[1].span!, quantity: 2),
        isNull,
      );
    });

    test('a saved meal header takes a new multiplier (6.4)', () {
      final s = newSession()
        ..setText('my oatmeal, purple monkey dishwasher', 36);
      final header = s.lines[0];
      expect(header.state, LineState.aliasOrSavedMeal);
      var r = s.rewriteAmount(s.text, 36, header.span!, quantity: 2)!;
      expect(r.text, '2 my oatmeal, purple monkey dishwasher');
      expect(r.cursor, 38);
      var after = parser.parseMeal(r.text, -1, s.snapshot);
      expect(after[0].state, LineState.aliasOrSavedMeal);
      expect(after[0].savedMealId, header.savedMealId);
      expect(after[0].multiplier, 2);
      expect(after[1].foodText, 'purple monkey dishwasher');

      // A quantity already there is replaced; a range or a multiplier goes.
      for (final (t, want) in [
        ('half usual oatmeal', '1.5 usual oatmeal'),
        ('2-3 my oatmeal', '1.5 my oatmeal'),
        ('my oatmeal x2', 'my oatmeal 1.5'),
        ('2 servings of my oatmeal', '1.5 my oatmeal'),
      ]) {
        final h = newSession()..setText(t, -1);
        r = h.rewriteAmount(t, 0, h.lines[0].span!, quantity: 1.5)!;
        expect(r.text, want, reason: t);
        after = parser.parseMeal(r.text, -1, h.snapshot);
        expect(after.single.multiplier, 1.5, reason: t);
        expect(after.single.markers, isEmpty, reason: t);
      }

      // Quantity only: a unit is refused, and so is zero.
      expect(
        s.rewriteAmount(s.text, 0, header.span!, quantity: 2, unit: 'cup'),
        isNull,
      );
      expect(s.rewriteAmount(s.text, 0, header.span!, quantity: 0), isNull);
    });

    test('decimals are kept to three places', () {
      expect(rewrite('2 eggs', 0, 0.5)!.text, '0.5 eggs');
      expect(rewrite('2 eggs', 0, 1.25)!.text, '1.25 eggs');
      expect(rewrite('2 eggs', 0, 1 / 3)!.text, '0.333 eggs');
    });

    test('the cursor keeps its place around the change', () {
      var r = rewrite('2 eggs, toast', 0, 12, cursor: 13)!;
      expect(r.text, '12 eggs, toast');
      expect(r.cursor, 14);
      r = rewrite('toast, 2 eggs', 1, 12, cursor: 2)!;
      expect(r.cursor, 2);
      r = rewrite('2 slices toast', 0, 100, unit: 'g', cursor: 4)!;
      expect(r.text, '100 g toast');
      expect(r.cursor, 5);
      r = rewrite('2 slices toast', 0, 100, unit: 'g', cursor: 12)!;
      expect(r.text.substring(r.cursor), 'st');
      r = rewrite('toast', 0, 2, unit: 'slice', cursor: 5)!;
      expect(r.text, '2 slice toast');
      expect(r.cursor, 13);
    });
  });

  group('removing an item (8.3)', () {
    ({String text, int cursor})? remove(String text, int i, {int? cursor}) {
      final s = newSession()..setText(text, -1);
      return s.removeItem(text, cursor ?? text.length, s.lines[i].span!);
    }

    test(
      'the item goes with the separator after it, or before it at the end',
      () {
        expect(remove('2 eggs and toast', 0)!.text, 'toast');
        expect(remove('2 eggs and toast', 1)!.text, '2 eggs');
        expect(remove('2 eggs, toast, coffee', 1)!.text, '2 eggs, coffee');
        expect(remove('2 eggs, toast, coffee', 2)!.text, '2 eggs, toast');
        expect(remove('toast', 0)!.text, '');
        expect(remove('coffee with 2 tbsp half and half', 1)!.text, 'coffee');
        expect(
          remove('two eggs two slices of toast', 0)!.text,
          'two slices of toast',
        );
        expect(remove('2 eggs\n1 banana; coffee', 1)!.text, '2 eggs\ncoffee');
        expect(remove('my oatmeal, toast', 0)!.text, 'toast');
      },
    );

    test('every other item reads exactly as before', () {
      for (final t in [
        '2 eggs and toast',
        '2 eggs, 2 slices sourdough toast, 1 tbsp butter, coffee with 2 tbsp '
            'half and half',
        'black coffee two eggs and toast',
        'chicken 200g rice 1 cup cooked',
        'coffee with no sugar, toast',
        'I had two eggs and a banana',
        'toast, toast, toast',
      ]) {
        final before = parser.parseMeal(t, -1, UserSnapshot.from(_data()));
        for (var i = 0; i < before.length; i++) {
          final r = remove(t, i);
          expect(r, isNotNull, reason: '$t $i');
          final after = parser.parseMeal(
            r!.text,
            -1,
            UserSnapshot.from(_data()),
          );
          final want = [...before]..removeAt(i);
          expect(
            after.map((l) => '${l.foodText}|${l.quantity}|${l.foodRef}'),
            want.map((l) => '${l.foodText}|${l.quantity}|${l.foodRef}'),
            reason: '$t $i',
          );
        }
      }
    });

    test('the cursor keeps its place around the cut', () {
      expect(remove('2 eggs, toast', 0, cursor: 13)!.cursor, 5);
      expect(remove('2 eggs, toast', 0, cursor: 3)!.cursor, 0);
      expect(remove('2 eggs, toast', 1, cursor: 2)!.cursor, 2);
    });

    test('a text or span that is not the session\'s is refused', () {
      final s = newSession()..setText('2 eggs, toast', 13);
      expect(s.removeItem('toast', 5, s.lines[0].span!), isNull);
      expect(s.removeItem(s.text, 13, const Span(2, 6)), isNull);
      // Nothing changed.
      expect(s.text, '2 eggs, toast');
      expect(s.lines, hasLength(2));
    });

    test('picks on the other items stay on them, even among like items', () {
      final s = newSession()..setText('toast, toast, toast', 19);
      for (final (i, ref) in [(0, _egg), (1, _coffee), (2, _halfAndHalf)]) {
        expect(s.pickFood(s.lines[i].span!, ref), isTrue);
      }
      final r = s.removeItem(s.text, 19, s.lines[1].span!)!;
      expect(r.text, 'toast, toast');
      s.setText(r.text, r.cursor);
      expect(s.lines.map((l) => l.foodRef), [_egg, _halfAndHalf]);
      expect(s.lines.every(picked), isTrue);
    });
  });

  group('the amount set in the sheet (7.2)', () {
    // Sets the amount of line [i] in the sheet and puts the new text in the
    // box, as the screen does.
    void setAmount(ParseSession s, int i, double q, [String unit = '']) {
      final r = s.rewriteAmount(
        s.text,
        s.text.length,
        s.lines[i].span!,
        quantity: q,
        unit: unit,
      )!;
      s.setText(r.text, r.cursor);
    }

    bool set(Line l) => l.assumedAmountSetInSheet;

    test('marks a line whose amount was assumed', () {
      final s = newSession()..setText('2 eggs, toast', 13);
      expect(s.lines[1].markers, contains(Marker.assumed));
      expect(s.lines.any(set), isFalse);
      setAmount(s, 1, 2, 'slice');
      expect(s.text, '2 eggs, 2 slice toast');
      expect(set(s.lines[1]), isTrue);
      expect(set(s.lines[0]), isFalse);
      expect(s.lines[1].markers, isNot(contains(Marker.assumed)));
    });

    test('does not mark a line whose amount was typed', () {
      final s = newSession()..setText('2 eggs', 6);
      setAmount(s, 0, 3);
      expect(s.text, '3 eggs');
      expect(set(s.lines.single), isFalse);
    });

    test('follows its item through edits elsewhere, and a second change in '
        'the sheet', () {
      final k = _Keys(newSession(), 'toast');
      setAmount(k.s, 0, 2, 'slice');
      k.reload();
      k.type(', coffee', (t) => expect(set(k.lineAt(0)), isTrue, reason: t));
      void toastSet(String t) => expect(
        set(k.s.lines.firstWhere((l) => l.learnedKey == 'toast')),
        isTrue,
        reason: t,
      );
      k.moveTo(0);
      k.type(', ', toastSet);
      k.moveTo(0);
      k.type('1 egg', toastSet);
      expect(k.text, '1 egg, 2 slice toast, coffee');
      expect(k.s.lines.where(set), hasLength(1));
      // A second change in the sheet keeps it.
      setAmount(k.s, 1, 3, 'slice');
      expect(k.s.text, '1 egg, 3 slice toast, coffee');
      expect(set(k.s.lines[1]), isTrue);
    });

    test('is cleared by any edit to its item, for good', () {
      final k = _Keys(newSession(), 'toast');
      setAmount(k.s, 0, 2, 'slice');
      k.reload();
      k.moveTo(1);
      k.backspace(1); // " slice toast"
      expect(set(k.s.lines.single), isFalse);
      k.type('2');
      expect(k.text, '2 slice toast');
      expect(set(k.s.lines.single), isFalse);
    });

    test('is not made when the new text never arrives', () {
      final s = newSession()..setText('toast', 5);
      final r = s.rewriteAmount('toast', 5, s.lines[0].span!, quantity: 2)!;
      s.setText('toast, coffee', 13); // the user typed instead
      s.setText(r.text, r.cursor);
      expect(s.lines.any(set), isFalse);
    });

    test('a pick and the mark stay together on the line', () {
      final s = newSession()..setText('toast', 5);
      s.pickFood(s.lines[0].span!, _egg);
      expect(s.lines[0].markers, contains(Marker.assumed));
      setAmount(s, 0, 3);
      expect(s.text, '3 toast');
      expect(s.lines[0].foodRef, _egg);
      expect(picked(s.lines[0]), isTrue);
      expect(set(s.lines[0]), isTrue);
      expect(s.lines[0].baseQuantity, 150);
    });
  });

  group('the unit picker for a food that is not typed (9.3)', () {
    test('offers what the added line can hold, each checked', () {
      final snapshot = UserSnapshot.from(_data());
      for (final ref in [_egg, 'usda:2705384', 'local:1', _coffee]) {
        final choices = unitChoicesForFood(parser, snapshot, ref);
        expect(choices, isNotEmpty, reason: ref);
        for (final c in choices) {
          final l = foodLineFor(
            parser,
            snapshot,
            ref,
            quantity: 2,
            unit: c.unitText,
          )!;
          expect(l.baseQuantity, closeTo(2 * c.grams, 1e-9), reason: ref);
          expect(l.markers, isNot(contains(Marker.assumed)), reason: ref);
        }
      }
      // Milk: fl oz, never oz.
      final milk = unitChoicesForFood(
        parser,
        snapshot,
        'usda:2705384',
      ).map((c) => c.unitText);
      expect(milk, containsAll(['g', 'fl oz', 'cup', 'tbsp']));
      expect(milk, isNot(contains('oz')));
      expect(unitChoicesForFood(parser, snapshot, 'usda:1'), isEmpty);
    });
  });

  group('the unit picker (R42)', () {
    test('lists only amounts that read back as the same food and grams', () {
      for (final text in [
        '2 eggs',
        '1 cup rice',
        '200 g chicken',
        'toast',
        '2 yogurt',
      ]) {
        final s = newSession()..setText(text, -1);
        final span = s.lines[0].span!;
        final ref = s.lines[0].foodRef;
        final choices = s.unitChoices(span);
        expect(choices, isNotEmpty, reason: text);
        expect(
          choices.map((c) => c.unitText),
          containsAll(['g']),
          reason: text,
        );
        for (final c in choices) {
          expect(c.label.startsWith('Quantity not specified'), isFalse);
          final r = s.rewriteAmount(
            text,
            0,
            span,
            quantity: 1,
            unit: c.unitText,
          );
          expect(r, isNotNull, reason: '$text ${c.label}');
          final l = parser.parseMeal(r!.text, -1, s.snapshot)[0];
          expect(l.foodRef, ref, reason: '$text ${c.label}');
          expect(
            l.baseQuantity,
            closeTo(c.grams, 1e-9),
            reason: '$text ${c.label}',
          );
          expect(l.markers, isNot(contains(Marker.assumed)));
        }
      }
    });

    test('an egg offers grams, ounces and a bare count', () {
      final s = newSession()..setText('2 eggs', 6);
      final texts = s.unitChoices(s.lines[0].span!).map((c) => c.unitText);
      expect(texts, containsAll(['g', 'oz', '']));
    });

    test('a food measured in cups offers the volume units', () {
      final s = newSession()..setText('1 cup milk', 10);
      final texts = s.unitChoices(s.lines[0].span!).map((c) => c.unitText);
      expect(texts, containsAll(['g', 'fl oz', 'cup', 'tbsp']));
    });

    test('oz is not offered where it is read as a fluid ounce (4.2)', () {
      for (final t in ['1 cup milk', 'coffee', '1 cup orange juice']) {
        final s = newSession()..setText(t, -1);
        final choices = s.unitChoices(s.lines[0].span!);
        final texts = choices.map((c) => c.unitText);
        expect(texts, isNot(contains('oz')), reason: t);
        expect(texts, contains('fl oz'), reason: t);
      }
      // A food with no fl oz portion keeps oz as a weight ounce.
      final s = newSession()..setText('2 eggs', 6);
      final oz = s
          .unitChoices(s.lines[0].span!)
          .singleWhere((c) => c.unitText == 'oz');
      expect(oz.grams, closeTo(28.349523125, 1e-9));
    });

    test('a food of the user\'s measured in servings with no portions can '
        'have its amount changed', () {
      final data = UserSnapshotData(
        version: 1,
        foods: const [
          UserFoodData(
            ref: 'local:7',
            name: 'Grandmas stew',
            kind: 'recipe',
            baseUnit: 'serving',
            baseAmount: 1,
            nutrients: {1008: 300},
          ),
        ],
      );
      final s = newSession(data: data)..setText('grandmas stew', 13);
      expect(s.lines.single.foodRef, 'local:7');
      final choices = s.unitChoices(s.lines.single.span!);
      // No weight: grams and ounces cannot be converted (4.5).
      expect(choices.map((c) => c.unitText), unorderedEquals(['serving', '']));
      expect(choices.map((c) => c.grams), everyElement(1));
      for (final c in choices) {
        final r = s.rewriteAmount(
          s.text,
          13,
          s.lines.single.span!,
          quantity: 2,
          unit: c.unitText,
        )!;
        final l = parser.parseMeal(r.text, -1, s.snapshot).single;
        expect(l.foodRef, 'local:7');
        expect(l.baseQuantity, 2);
        expect(l.markers, isNot(contains(Marker.assumed)));
      }
    });

    test('a bare count and serving are offered when they read back', () {
      final s = newSession()..setText('2 eggs', 6);
      final choices = s.unitChoices(s.lines[0].span!);
      // The egg's own "1 egg" portion is the bare count; serving is the
      // default amount.
      expect(choices.where((c) => c.unitText == ''), hasLength(1));
      expect(choices.singleWhere((c) => c.unitText == '').label, 'egg');
      expect(
        choices.singleWhere((c) => c.unitText == 'serving').grams,
        closeTo(50, 1e-9),
      );
    });

    test('a line with no food has none', () {
      final s = newSession()..setText('purple monkey dishwasher', 24);
      expect(s.unitChoices(s.lines[0].span!), isEmpty);
      expect(s.unitChoices(const Span(50, 51)), isEmpty);
    });
  });

  group('the session always shows what a fresh parse shows', () {
    // Fragments that exercise splitting, fractions, ranges, multipliers,
    // aliases, user foods, half-typed words, a surrogate pair, curly quotes,
    // w/, &, tabs, no-break spaces and identical items.
    const fragments = [
      '2 eggs',
      ', ',
      ' and ',
      ' with ',
      'toast',
      '2 slices sourdough toast',
      '1 tbsp butter',
      'coffee with 2 tbsp half and half',
      '½',
      '¾ cup milk',
      'x3',
      ' ',
      'sl',
      '200 g chicken',
      'banana',
      'my oatmeal',
      'protein bar',
      '2-3 ',
      'a ',
      '\n',
      '😀',
      '2',
      'cup',
      'purple',
      ',',
      '1/2 ',
      'no sugar',
      '.',
      'Usual oatmeal',
      '3 large eggs',
      ' of ',
      'no sugar cola',
      'coffee with no sugar',
      '‘',
      '’',
      '“',
      '”',
      'it’s ',
      ' w/ ',
      ' & ',
      '\t',
      ' ',
      'toast, toast',
      '1 cup milk',
      '1 cup milk, 1 cup milk',
    ];
    const picks = [_egg, _coffee, _halfAndHalf, 'local:1', 'usda:1'];

    test('on a few hundred generated edit sequences, with an independent '
        'model of the picks', () {
      final rnd = Random(20261113);
      var checked = 0;
      var picksMade = 0;
      final model = _Model();
      List<_MItem> itemsOf(String text, UserSnapshot snapshot) => [
        for (final d in splitItems(text, names: snapshot.names))
          if (parser.parseItem(d, snapshot) case final l?)
            _MItem(
              d.span,
              l.learnedKey,
              d.cacheKey,
              l.state == LineState.aliasOrSavedMeal,
            ),
      ];
      for (var seq = 0; seq < 300; seq++) {
        var data = _data(version: 1);
        final s = newSession(data: data);
        bool known(String ref) => parser.foodFor(ref, s.snapshot) != null;
        final history = <String>[''];
        var text = '';
        model.picks = [];
        // A character backspaced in the step before, typed again in this one.
        (int, String)? retype;
        for (var step = 0; step < 14; step++) {
          final oldText = text;
          final roll = rnd.nextInt(14);
          if (retype != null) {
            final (at, c) = retype;
            text = text.substring(0, at) + c + text.substring(at);
            retype = null;
          } else if (roll == 12 && text.isNotEmpty) {
            final at = rnd.nextInt(text.length);
            retype = (at, text[at]);
            text = text.substring(0, at) + text.substring(at + 1);
          } else if (roll < 5) {
            final at = rnd.nextInt(text.length + 1);
            text =
                text.substring(0, at) +
                fragments[rnd.nextInt(fragments.length)] +
                text.substring(at);
          } else if (roll < 7 && text.isNotEmpty) {
            final a = rnd.nextInt(text.length);
            final b = min(text.length, a + 1 + rnd.nextInt(6));
            text = text.substring(0, a) + text.substring(b);
          } else if (roll < 8 && text.isNotEmpty) {
            final a = rnd.nextInt(text.length);
            final b = min(text.length, a + 1 + rnd.nextInt(8));
            text =
                text.substring(0, a) +
                fragments[rnd.nextInt(fragments.length)] +
                text.substring(b);
          } else if (roll == 8) {
            // The whole text replaced.
            text = [
              for (var k = 0; k < 1 + rnd.nextInt(3); k++)
                fragments[rnd.nextInt(fragments.length)],
            ].join(', ');
          } else if (roll == 9) {
            // Back to an earlier text (undo).
            text = history[rnd.nextInt(history.length)];
          } else if (roll == 10 && s.lines.isNotEmpty) {
            final l = s.lines[rnd.nextInt(s.lines.length)];
            final items = itemsOf(text, s.snapshot);
            if (rnd.nextBool()) {
              final ref = picks[rnd.nextInt(picks.length)];
              final ok = s.pickFood(l.span!, ref);
              expect(ok, model.pick(l.span!, ref, items, known(ref)));
              if (ok) picksMade++;
            } else {
              expect(s.clearPick(l.span!), model.clear(l.span!));
            }
          } else if (roll == 11 && rnd.nextInt(2) == 0) {
            data = _data(
              version: data.version + 1,
              learned: rnd.nextBool(),
              foods: rnd.nextInt(3) != 0,
            );
            s.setSnapshot(UserSnapshot.from(data));
            model
              ..edit(text, text, itemsOf(text, s.snapshot))
              ..foodsLeft(known);
          }
          final cursor = rnd.nextInt(text.length + 2) - 1;
          s.setText(text, cursor);
          checked++;
          if (text != history.last) history.add(text);

          // The independent model of 9.1 and R43, on a plain parse.
          final plain = parser.parseMeal(text, -1, s.snapshot);
          model
            ..edit(oldText, text, itemsOf(text, s.snapshot))
            ..foodsLeft(known);
          final shown = [
            for (final l in s.lines)
              if (l.markers.contains(Marker.yourPick))
                '${l.span!.start}-${l.span!.end} ${l.foodRef} ${l.learnedKey}',
          ]..sort();
          final why = '$seq $step "$oldText" to "$text"';
          expect(shown, model.shown(), reason: why);

          // Lines without a pick are the plain parse (with the session's
          // typing rule); with one, a session that has never seen the text
          // and is given the same picks.
          final fresh = ParseSession(parser, snapshot: s.snapshot)
            ..setText(text, cursor);
          expect(s.lines, hasLength(plain.length), reason: why);
          for (var i = 0; i < s.lines.length; i++) {
            final l = s.lines[i];
            if (l.markers.contains(Marker.yourPick)) {
              fresh.pickFood(l.span!, l.foodRef!);
              expect(
                _sum(l),
                _sum(fresh.lines[i]),
                reason: '$why line $i (pick)',
              );
            } else {
              final cursorLine = parser.parseMeal(text, cursor, s.snapshot)[i];
              expect(
                _sum(l),
                _sum(_expectedPlain(cursorLine, text, cursor)),
                reason: '$why line $i',
              );
            }
          }
        }
      }
      expect(checked, 4200);
      expect(picksMade, greaterThan(50));
      expect(
        model.restored,
        greaterThan(0),
        reason: 'no suspended pick came back',
      );
      for (final why in [
        _Model.movedOn,
        _Model.deleted,
        _Model.repicked,
        _Model.cleared,
        _Model.foodGone,
      ]) {
        expect(
          model.dropped[why] ?? 0,
          greaterThan(0),
          reason: 'no pick was dropped because $why: ${model.dropped}',
        );
      }
    });
  });

  group('speed (12.3)', () {
    test(
      'a keystroke through the session costs no more than a plain parse',
      () {
        const brief =
            '2 eggs, 2 slices sourdough toast, 1 tbsp butter, '
            'coffee with 2 tbsp half and half';
        final snapshot = UserSnapshot.from(
          UserSnapshotData(
            version: 1,
            foods: [
              for (var i = 0; i < 120; i++)
                UserFoodData(
                  ref: 'local:$i',
                  name: 'homemade dish $i${i % 7 == 0 ? ' and rice' : ''}',
                  kind: 'custom',
                  baseUnit: i.isEven ? 'g' : 'serving',
                  baseAmount: i.isEven ? 100 : 1,
                  portions: const [PortionData('1 serving', 150)],
                  nutrients: {1008: 100.0 + i, 203: 5},
                ),
            ],
            aliases: [for (var i = 0; i < 60; i++) AliasData('my meal $i', 1)],
            savedMeals: const [SavedMealData(id: 1, name: 'Saved meal')],
            historyCounts: {for (var i = 0; i < 200; i++) 'local:$i': i % 9},
          ),
        );
        double pct(List<double> sorted, double p) =>
            sorted[((sorted.length - 1) * p).round()];

        // Warm up, then time both on every prefix, one after the other.
        for (var pass = 0; pass < 3; pass++) {
          final s = ParseSession(parser, snapshot: snapshot);
          for (var n = 1; n <= brief.length; n++) {
            s.setText(brief.substring(0, n), n);
            parser.parseMeal(brief.substring(0, n), n, snapshot);
          }
        }
        final plain = <double>[];
        final session = <double>[];
        for (var pass = 0; pass < 15; pass++) {
          final s = ParseSession(parser, snapshot: snapshot);
          for (var n = 1; n <= brief.length; n++) {
            final t = brief.substring(0, n);
            var sw = Stopwatch()..start();
            parser.parseMeal(t, n, snapshot);
            plain.add(sw.elapsedMicroseconds / 1000);
            sw = Stopwatch()..start();
            s.setText(t, n);
            session.add(sw.elapsedMicroseconds / 1000);
          }
        }
        plain.sort();
        session.sort();
        final msg =
            'per keystroke over ${plain.length} keystrokes (ms): plain parse '
            'median ${pct(plain, 0.5).toStringAsFixed(3)}, p95 '
            '${pct(plain, 0.95).toStringAsFixed(3)}, max '
            '${plain.last.toStringAsFixed(3)}; session median '
            '${pct(session, 0.5).toStringAsFixed(3)}, p95 '
            '${pct(session, 0.95).toStringAsFixed(3)}, max '
            '${session.last.toStringAsFixed(3)}';
        // The cache makes it faster; it must never be slower.
        expect(
          pct(session, 0.95),
          lessThanOrEqualTo(pct(plain, 0.95)),
          reason: msg,
        );
        expect(
          pct(session, 0.5),
          lessThanOrEqualTo(pct(plain, 0.5)),
          reason: msg,
        );
        expect(pct(session, 0.95), lessThan(8.0), reason: msg);
        printOnFailure(msg);
      },
      tags: 'benchmark',
    );
  });
}
