// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';
import 'dart:math';

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/parse_session.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
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

UserSnapshotData _data({int version = 1, bool learned = false}) =>
    UserSnapshotData(
      version: version,
      foods: [
        const UserFoodData(
          ref: 'local:1',
          name: 'Protein bar',
          kind: 'custom',
          baseUnit: 'g',
          baseAmount: 50,
          portions: [PortionData('1 bar', 50)],
          nutrients: {1008: 200, 203: 20},
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
    l.items.map(_sum).join(';'),
  ].join('|');
}

void main() {
  late Parser parser;
  late Database db;

  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_session');
    addTearDown(() {
      // A worker stopped in the middle of its start may still hold the file
      // on Windows; the folder is in the system temp folder anyway.
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Left for the system to clean up.
      }
    });
    final path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    db = sqlite3.open(path, mode: OpenMode.readOnly);
    addTearDown(db.close);
    parser = Parser(SearchIndex.build(readUsdaFoods(db)), sqliteUsdaFoods(db));
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
      // And it does not come back when the words do.
      s.setText('3 slices toast', 14);
      expect(picked(s.lines[0]), isFalse);
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
      s.setText('2 eggs, 2 sl', 8); // at the start of the item
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
    // Rewrites line [i] of [text] and checks that parsing the new text gives
    // the amount asked for, and that nothing but the amount changed.
    ({String text, int cursor}) rewrite(
      String text,
      int i,
      double q, {
      String unit = '',
      int? cursor,
    }) {
      final lines = parser.parseMeal(text, -1, UserSnapshot.from(_data()));
      return ParseSession.withAmount(
        text,
        cursor ?? text.length,
        lines[i],
        quantity: q,
        unit: unit,
      );
    }

    Line reparse(String text, int i) =>
        parser.parseMeal(text, -1, UserSnapshot.from(_data()))[i];

    test('a bare count', () {
      final r = rewrite('2 eggs', 0, 3);
      expect(r.text, '3 eggs');
      expect(reparse(r.text, 0).quantity, 3);
      expect(reparse(r.text, 0).baseQuantity, 150);
    });

    test('a unit', () {
      final r = rewrite('2 slices toast', 0, 100, unit: 'g');
      expect(r.text, '100 g toast');
      final l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel, l.baseQuantity), (100, 'g', 100));
    });

    test('a size word', () {
      expect(rewrite('2 large eggs', 0, 3).text, '3 eggs');
      final r = rewrite('2 eggs', 0, 3, unit: 'large');
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
        final r = rewrite(t, 0, 4);
        expect(r.text, '4 eggs', reason: t);
        expect(reparse(r.text, 0).quantity, 4);
        expect(reparse(r.text, 0).markers, isNot(contains(Marker.assumed)));
      }
    });

    test('a multiplier is folded into the new number', () {
      var r = rewrite('2 eggs x3', 0, 4);
      expect(r.text, '4 eggs');
      expect(reparse(r.text, 0).quantity, 4);
      r = rewrite('eggs x3', 0, 4);
      expect(reparse(r.text, 0).quantity, 4);
      expect(reparse(r.text, 0).foodText, 'eggs');
      r = rewrite('x3 eggs', 0, 5);
      expect(reparse(r.text, 0).quantity, 5);
    });

    test('an amount typed after the food', () {
      var r = rewrite('toast 2 slices', 0, 3, unit: 'slice');
      expect(r.text, 'toast 3 slice');
      var l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel, l.foodText), (3, 'slice', 'toast'));
      r = rewrite('eggs 2', 0, 3);
      expect(r.text, 'eggs 3');
      l = reparse(r.text, 0);
      expect((l.quantity, l.foodText), (3, 'eggs'));
    });

    test('a compound amount is replaced as a whole', () {
      final r = rewrite('1 cup 2 tbsp milk', 0, 300, unit: 'ml');
      expect(r.text, '300 ml milk');
      expect(reparse(r.text, 0).quantity, 300);
    });

    test('no amount: the quantity and unit go at the start of the item', () {
      var r = rewrite('toast', 0, 2, unit: 'slice');
      expect(r.text, '2 slice toast');
      var l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel, l.foodText), (2, 'slice', 'toast'));
      r = rewrite('coffee', 0, 1);
      expect(r.text, '1 coffee');
      r = rewrite('eggs, toast', 1, 150, unit: 'g');
      expect(r.text, 'eggs, 150 g toast');
    });

    test('a leading a or an is an amount and is replaced', () {
      final r = rewrite('a banana', 0, 2);
      expect(r.text, '2 banana');
      expect(reparse(r.text, 0).quantity, 2);
    });

    test('leading filler stays', () {
      final r = rewrite('I had toast', 0, 2, unit: 'slice');
      final l = reparse(r.text, 0);
      expect((l.quantity, l.unitLabel), (2, 'slice'));
      expect(l.foodRef, reparse('toast', 0).foodRef);
    });

    test('only the line asked for changes', () {
      const t = '2 eggs, 2 slices sourdough toast, 1 tbsp butter';
      final r = rewrite(t, 1, 4, unit: 'slice');
      expect(r.text, '2 eggs, 4 slice sourdough toast, 1 tbsp butter');
      final before = parser.parseMeal(t, -1, UserSnapshot.from(_data()));
      final after = parser.parseMeal(r.text, -1, UserSnapshot.from(_data()));
      expect(after, hasLength(3));
      expect(
        _sum(after[0]).replaceAll(RegExp(r'Span\(\d+, \d+\)'), ''),
        _sum(before[0]).replaceAll(RegExp(r'Span\(\d+, \d+\)'), ''),
      );
      expect(after[1].foodText, before[1].foodText);
      expect(after[1].quantity, 4);
      expect(after[2].foodText, before[2].foodText);
      expect(after[2].quantity, 1);
    });

    test('a unit with a comma keeps only the part before it', () {
      expect(rewrite('2 eggs', 0, 1, unit: 'cup, cooked').text, '1 cup eggs');
    });

    test('decimals are kept to three places', () {
      expect(rewrite('2 eggs', 0, 0.5).text, '0.5 eggs');
      expect(rewrite('2 eggs', 0, 1.25).text, '1.25 eggs');
      expect(rewrite('2 eggs', 0, 1 / 3).text, '0.333 eggs');
    });

    test('a quantity that is not above zero leaves the text alone', () {
      for (final q in [0.0, -1.0, double.nan, double.infinity]) {
        final r = rewrite('2 eggs', 0, q, cursor: 3);
        expect(r.text, '2 eggs');
        expect(r.cursor, 3);
      }
    });

    test('the cursor keeps its place around the change', () {
      // Cursor after the item: moves with the text.
      var r = rewrite('2 eggs, toast', 0, 12, cursor: 13);
      expect(r.text, '12 eggs, toast');
      expect(r.cursor, 14);
      // Cursor before the amount: stays.
      r = rewrite('toast, 2 eggs', 1, 12, cursor: 2);
      expect(r.cursor, 2);
      // Cursor inside the old amount: ends up at the end of the new one.
      r = rewrite('2 slices toast', 0, 100, unit: 'g', cursor: 4);
      expect(r.text, '100 g toast');
      expect(r.cursor, 5);
      // Cursor in the food words: stays with them.
      r = rewrite('2 slices toast', 0, 100, unit: 'g', cursor: 12);
      expect(r.text.substring(r.cursor), 'st');
      // An insert at the start of the item.
      r = rewrite('toast', 0, 2, unit: 'slice', cursor: 5);
      expect(r.text, '2 slice toast');
      expect(r.cursor, 13);
    });

    test('a line with no span leaves the text alone', () {
      final r = ParseSession.withAmount(
        '2 eggs',
        1,
        const Line(state: LineState.matched),
        quantity: 3,
      );
      expect(r.text, '2 eggs');
      expect(r.cursor, 1);
    });
  });

  group('the session always shows what a fresh parse shows', () {
    // Fragments that exercise splitting, fractions, ranges, multipliers,
    // aliases, user foods, half-typed words and a surrogate pair.
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
    ];
    const picks = [_egg, _coffee, _halfAndHalf, 'local:1', 'usda:1'];

    test('on a few hundred generated edit sequences', () {
      final rnd = Random(20261113);
      var checked = 0;
      var picksMade = 0;
      for (var seq = 0; seq < 300; seq++) {
        var data = _data(version: 1);
        final s = newSession(data: data);
        var text = '';
        for (var step = 0; step < 12; step++) {
          final roll = rnd.nextInt(10);
          if (roll < 5) {
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
          } else if (roll == 8 && s.lines.isNotEmpty) {
            final l = s.lines[rnd.nextInt(s.lines.length)];
            if (rnd.nextBool()) {
              if (s.pickFood(l.span!, picks[rnd.nextInt(picks.length)])) {
                picksMade++;
              }
            } else {
              s.clearPick(l.span!);
            }
          } else if (roll == 9 && rnd.nextInt(4) == 0) {
            data = _data(version: data.version + 1, learned: rnd.nextBool());
            s.setSnapshot(UserSnapshot.from(data));
          }
          final cursor = rnd.nextInt(text.length + 2) - 1;
          s.setText(text, cursor);
          checked++;

          // Without a pick: the plain parse. With one: a session that has
          // never seen the text before, given the same picks.
          final plain = parser.parseMeal(text, cursor, s.snapshot);
          final fresh = ParseSession(parser, snapshot: s.snapshot)
            ..setText(text, cursor);
          expect(
            s.lines,
            hasLength(plain.length),
            reason: '$seq $step "$text"',
          );
          for (var i = 0; i < s.lines.length; i++) {
            final l = s.lines[i];
            if (l.markers.contains(Marker.yourPick)) {
              fresh.pickFood(l.span!, l.foodRef!);
              expect(
                _sum(l),
                _sum(fresh.lines[i]),
                reason: '$seq $step "$text" line $i (pick)',
              );
            } else {
              expect(
                _sum(l),
                _sum(plain[i]),
                reason: '$seq $step "$text" line $i',
              );
            }
          }
        }
      }
      expect(checked, 3600);
      expect(picksMade, greaterThan(50));
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
    );
  });
}
