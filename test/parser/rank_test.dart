// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/normalize.dart';
import 'package:daybook/parser/rank.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/split.dart';
import 'package:daybook/parser/tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'worked_examples.dart';

// Grammar 5.2 (joined words, typos), 5.4 (candidates and ranking), 5.5
// (confident match or guess), 5.6 (defaults from the real data), 5.7 (the
// correction sheet's search). Small cases use a tiny made-up food list; the
// rest use the real USDA database.

IndexFood _f(
  String ref,
  String description, {
  String dataset = 'fndds',
  double? energy,
  String? kind,
}) => IndexFood(
  ref: ref,
  description: description,
  dataset: dataset,
  energy: energy,
  kind: kind,
);

Ranker _ranker(
  List<IndexFood> usda, {
  List<IndexFood> user = const [],
  Map<String, int> history = const {},
}) => Ranker(
  SearchIndex.build(usda),
  user: user.isEmpty ? null : SearchIndex.build(user),
  history: history,
);

String _refs(Iterable<Candidate> c) => c.map((e) => e.ref).join(', ');

late List<IndexFood> _usdaFoods;
late SearchIndex _usdaIndex;
late int _readMs;
late int _buildMs;

Ranker _real({
  List<IndexFood> user = const [],
  Map<String, int> history = const {},
}) => Ranker(
  _usdaIndex,
  user: user.isEmpty ? null : SearchIndex.build(user),
  history: history,
);

final _turkeyChili = _f(
  'local:1',
  'Turkey chili',
  dataset: 'local',
  kind: 'recipe',
);
final _pbCookies = _f(
  'local:2',
  'Peanut butter cookies',
  dataset: 'local',
  kind: 'custom',
);

void main() {
  setUpAll(() {
    final dir = Directory.systemTemp.createTempSync('daybook_rank');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/usda.sqlite';
    File(path).writeAsBytesSync(
      gzip.decode(File('assets/food/usda.sqlite.gz').readAsBytesSync()),
    );
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    final sw = Stopwatch()..start();
    _usdaFoods = readUsdaFoods(db);
    _readMs = sw.elapsedMilliseconds;
    db.close();
    sw.reset();
    _usdaIndex = SearchIndex.build(_usdaFoods);
    _buildMs = sw.elapsedMilliseconds;
  });

  group('the index', () {
    test('reads every food of the real database', () {
      expect(_usdaFoods.length, 13598);
      expect(_usdaFoods.first.ref, startsWith('usda:'));
      expect(_usdaFoods.every((f) => f.energy != null), isTrue);
      expect(_usdaFoods.map((f) => f.dataset).toSet(), {
        'fndds',
        'sr_legacy',
        'foundation',
      });
    });

    test('5.2 joined words: "sourdough" finds "sour dough"', () {
      final r = _ranker([
        _f('usda:1', 'Bread, sour dough, toasted'),
        _f('usda:2', 'Bread, white, toasted'),
      ]);
      final m = r.match('sourdough toast');
      expect(m.top!.ref, 'usda:1', reason: '5.2 joined words');
      // "sour" and "dough" are covered by the pair, so they are not extra.
      expect(m.top!.extra, 0, reason: '5.4 extra words: joined pair covers');
      expect(m.state, LineState.matched);
      expect(r.match('sour dough toast').top!.ref, 'usda:1');
      expect(r.match('sourdough').top!.ref, 'usda:1');
    });

    test('5.2 joined words only join neighbors in one segment', () {
      final r = _ranker([_f('usda:1', 'Bread, sour, dough')]);
      expect(r.match('sourdough').ref, isNull);
    });

    test('the real data: sourdough toast and sour dough toast agree', () {
      final r = _real();
      expect(r.match('sourdough toast').ref, 'usda:2707647');
      expect(r.match('sour dough toast').ref, 'usda:2707647');
    });
  });

  group('5.2 step 3: ie and ies on the real data', () {
    test('cookie and cookies both find "Cookie, NFS" as matched', () {
      final r = _real();
      for (final w in ['cookie', 'cookies']) {
        final m = r.match(w);
        expect(m.top!.description, 'Cookie, NFS', reason: '5.2 step 3: $w');
        expect(m.state, LineState.matched, reason: '$w: ${m.reason}');
      }
    });

    test('pie and pies both find "Pie, NFS" as matched', () {
      final r = _real();
      for (final w in ['pie', 'pies']) {
        final m = r.match(w);
        expect(m.top!.description, 'Pie, NFS', reason: '5.2 step 3: $w');
        expect(m.state, LineState.matched, reason: '$w: ${m.reason}');
      }
    });

    test('brownie and brownies meet', () {
      final r = _real();
      expect(r.match('brownies').ref, r.match('brownie').ref);
      expect(r.match('brownie').top, isNotNull);
    });

    test('berries and berry meet; fries is as before', () {
      final r = _real();
      expect(r.match('berries').words, r.match('berry').words);
      expect(r.match('fries').ref, 'usda:2709456');
    });
  });

  group('5.2 typos', () {
    final foods = [
      _f('usda:1', 'Banana, raw'),
      _f('usda:2', 'Broccoli, raw'),
      _f('usda:3', 'Chicken, NFS'),
      _f('usda:4', 'Egg, NFS'),
    ];
    final r = _ranker(foods);

    test('the four examples of the grammar, on the real data', () {
      final real = _real();
      final cases = {
        'bananna': 'banana',
        'chiken': 'chicken',
        'brocoli': 'broccoli',
        'oatmeel': 'oatmeal',
      };
      cases.forEach((typed, word) {
        final m = real.match(typed);
        expect(m.words, [word], reason: '5.2 typos: $typed becomes $word');
        expect(m.corrected, isTrue);
        expect(
          m.state,
          LineState.guess,
          reason: '5.2: a corrected line is always a guess ($typed)',
        );
        expect(m.top, isNotNull);
      });
      expect(real.match('bananna').top!.description, 'Banana, raw');
    });

    test('a corrected word is a guess even with a perfect food', () {
      final m = r.match('bananna');
      expect(m.top!.extra, 0);
      expect(m.state, LineState.guess, reason: '5.2 and 5.5 rule 1');
      expect(r.match('banana').state, LineState.matched);
    });

    test('limit 1 for 4 to 7 letters, one deleted or wrong letter', () {
      expect(r.match('bnana').words, ['banana']); // 5 letters
      expect(r.match('bnnana').words, ['banana']); // 6 letters
      expect(r.match('chickan').words, ['chicken']); // 7 letters
    });

    test('limit 1 for 4 to 7 letters: two edits are left alone', () {
      expect(r.match('bxnxna').words, ['bxnxna'], reason: '6 letters, 2 edits');
      expect(r.match('bxnxna').state, LineState.notFound);
      expect(r.match('chxcxen').words, ['chxcxen'], reason: '7 letters');
    });

    test('limit 2 for 8 letters or more', () {
      expect(r.match('brocxxli').words, ['broccoli']); // 2 edits, 8 letters
      expect(r.match('brxcxxli').words, ['brxcxxli']); // 3 edits
    });

    test('a swap of two neighboring letters counts as 1', () {
      expect(editDistance('abnana', 'banana', 1), 1);
      expect(editDistance('banaan', 'banana', 1), 1);
      expect(r.match('abnana').words, ['banana']); // 6 letters, limit 1
      expect(editDistance('abcd', 'cdab', 2), greaterThan(2));
    });

    test('edit distance basics', () {
      expect(editDistance('banana', 'banana', 2), 0);
      expect(editDistance('banana', 'bananna', 2), 1);
      expect(editDistance('kitten', 'sitting', 5), 3);
      expect(editDistance('a', 'abcd', 2), greaterThan(2));
    });

    test('words of 3 letters or fewer are never corrected', () {
      expect(r.match('egx').words, ['egx']);
      expect(r.match('egx').state, LineState.notFound);
    });

    test('a word that is in the index is left alone', () {
      final m = r.match('banana');
      expect(m.corrected, isFalse);
      expect(m.words, ['banana']);
    });

    test('a half-typed word is left alone (no prefix matching)', () {
      for (final w in ['banan', 'brocc', 'chick']) {
        final m = r.match(w);
        expect(m.words, [w], reason: '5.2: $w is the start of an indexed word');
        expect(m.corrected, isFalse);
        expect(m.state, LineState.notFound);
      }
      // On the real data, "sourd" and "sourdoug" match nothing.
      final real = _real();
      expect(real.match('sourd').state, LineState.notFound);
      expect(real.match('sourdoug').state, LineState.notFound);
    });

    test('only letters are corrected', () {
      expect(r.match('v8x9').words, ['v8x9']);
    });

    test('a tie goes to the word used by more foods', () {
      final t = _ranker([
        _f('usda:1', 'Mild salsa'),
        _f('usda:2', 'Mild cheese'),
        _f('usda:3', 'Milk, whole'),
      ]);
      // "mile" is 1 away from both "mild" (2 foods) and "milk" (1 food).
      expect(t.match('mile').words, ['mild']);
    });

    test('then to the alphabetical order', () {
      final t = _ranker([
        _f('usda:1', 'Mild salsa'),
        _f('usda:2', 'Milk, whole'),
      ]);
      expect(t.match('mile').words, ['mild']); // "mild" before "milk"
    });

    test('the closest word wins over a more used one', () {
      final t = _ranker([
        _f('usda:1', 'Chicken'),
        _f('usda:2', 'Chicken soup'),
        _f('usda:3', 'Chickpea'),
      ]);
      // "chicken" is 0 away from itself: never corrected. "chickan" is 1 away
      // from "chicken" and 3 from "chickpea".
      expect(t.match('chickan').words, ['chicken']);
    });

    test('a corrected word that repeats another counts once', () {
      expect(r.match('banana bananna').words, ['banana']);
    });
  });

  group('5.4 candidates', () {
    test('half of the words, rounded up, are enough', () {
      final r = _ranker([_f('usda:1', 'Breakfast bar, NFS')]);
      // 2 words, 1 found: a candidate (5.4 and example 77).
      expect(r.match('zorbo bar').ref, 'usda:1');
      // 3 words need 2.
      expect(r.match('zorbo quux bar').state, LineState.notFound);
      // 4 words need 2.
      expect(r.match('zorbo quux wxyz bar').state, LineState.notFound);
      expect(r.match('zorbo bar breakfast quux').ref, 'usda:1');
      // 1 word needs 1.
      expect(r.match('bar').ref, 'usda:1');
    });

    test('a food with more of the words comes first (key 1)', () {
      final r = _ranker([
        _f('usda:1', 'Rice, cooked'),
        _f('usda:2', 'Beans and white rice'),
        _f('usda:3', 'Beans, cooked'),
      ]);
      final m = r.match('rice beans');
      expect(m.top!.ref, 'usda:2', reason: '5.4 key 1');
      expect(m.ranked.map((c) => c.matched), [2, 1, 1]);
    });

    test('fewer extra words come first (key 3)', () {
      final r = _ranker([
        _f('usda:1', 'Egg salad'),
        _f('usda:2', 'Egg, whole, cooked'),
        _f('usda:3', 'Egg substitute, powder'),
      ]);
      final m = r.match('egg');
      expect(m.ranked.map((c) => c.ref), ['usda:2', 'usda:1', 'usda:3']);
      expect(m.ranked.map((c) => c.extra), [0, 1, 2]);
    });

    test('neutral words and NS as to segments are not extra', () {
      final r = _ranker([
        _f('usda:1', 'Coffee, NS as to type'),
        _f('usda:2', 'Coffee, brewed, regular, plain, fresh, includes raw'),
      ]);
      for (final c in r.match('coffee').ranked) {
        expect(c.extra, 0, reason: '5.4 neutral words: ${c.description}');
      }
    });

    test('more times logged comes first (key 4)', () {
      final r = _ranker(
        [_f('usda:1', 'Soup, bean'), _f('usda:2', 'Soup, tomato')],
        history: {'usda:2': 3},
      );
      final m = r.match('soup');
      expect(m.top!.ref, 'usda:2', reason: '5.4 key 4');
      expect(m.top!.timesLogged, 3);
    });

    test('generic before not generic (key 5)', () {
      final r = _ranker([
        _f('usda:1', 'Cheese, plain'),
        _f('usda:2', 'Cheese, NFS'),
        _f('usda:3', 'Cheese, NS as to type'),
      ]);
      final m = r.match('cheese');
      expect(m.top!.generic, isTrue, reason: '5.4 key 5');
      expect(m.ranked.last.ref, 'usda:1');
    });

    test('the source order: local, FNDDS, SR Legacy, Foundation (key 6)', () {
      final r = _ranker(
        [
          _f('usda:1', 'Bread, white', dataset: 'foundation'),
          _f('usda:2', 'Bread, white', dataset: 'sr_legacy'),
          _f('usda:3', 'Bread, white', dataset: 'fndds'),
        ],
        user: [_f('local:9', 'Bread, white', dataset: 'local', kind: 'custom')],
      );
      final m = r.match('bread');
      expect(_refs(m.ranked), 'local:9, usda:3, usda:2, usda:1');
    });

    test('a shorter description comes first (key 7)', () {
      final r = _ranker([
        _f('usda:1', 'Soup, tomato'),
        _f('usda:2', 'Soup, bean'),
      ]);
      expect(_refs(r.match('soup').ranked), 'usda:2, usda:1');
    });

    test('the food reference text ends every tie (key 8)', () {
      final r = _ranker([
        _f('usda:2', 'Bread, white'),
        _f('usda:10', 'Bread, white'),
        _f('usda:1', 'Bread, white'),
      ]);
      // Text order, not number order.
      expect(_refs(r.match('bread').ranked), 'usda:1, usda:10, usda:2');
    });

    test('the same words, foods and history give the same order', () {
      final foods = [
        for (var i = 0; i < 40; i++)
          _f(
            'usda:$i',
            i.isEven ? 'Soup, bean $i' : 'Soup, tomato, canned $i',
            dataset: i % 3 == 0 ? 'sr_legacy' : 'fndds',
            energy: 50.0 + i,
          ),
      ];
      final a = _ranker(foods, history: {'usda:7': 2});
      final b = _ranker(foods.reversed.toList(), history: {'usda:7': 2});
      for (final q in ['soup', 'soup bean', 'tomato soup', 'canned']) {
        expect(
          _refs(b.match(q).ranked),
          _refs(a.match(q).ranked),
          reason: '5.4: deterministic for "$q"',
        );
        expect(_refs(b.search(q)), _refs(a.search(q)));
      }
    });
  });

  group('5.4 key 2 and 5.5: the user\'s own foods', () {
    test('"Turkey chili" wins for "chili" (fixture of 11.1)', () {
      final r = _ranker(
        [_f('usda:2706373', 'Chili, NFS', energy: 118)],
        user: [_turkeyChili],
      );
      final m = r.match('chili');
      expect(m.top!.ref, 'local:1', reason: 'example 74, key 2');
      expect(m.top!.fits, isTrue);
      expect(m.top!.extra, 1); // "turkey" is an extra word
      expect(m.state, LineState.matched, reason: '5.5 rule 2: it fits');
      expect(m.ranked[1].ref, 'usda:2706373');
    });

    test('without the recipe the line is "Chili, NFS" (example 74)', () {
      final m = _real().match('chili');
      expect(m.ref, 'usda:2706373');
      expect(m.state, LineState.matched);
    });

    test('"Peanut butter cookies" does not win for "butter" (example 75)', () {
      final r = _ranker(
        [_f('usda:2710154', 'Butter, NFS', energy: 717)],
        user: [_pbCookies],
      );
      final m = r.match('butter');
      expect(m.top!.ref, 'usda:2710154', reason: 'example 75, key 2');
      expect(m.state, LineState.matched);
      // The cookies are still a candidate, ranked by the other keys.
      final cookies = m.ranked.firstWhere((c) => c.ref == 'local:2');
      expect(cookies.fits, isFalse);
      expect(cookies.extra, 2);
    });

    test('every query word must be in the name', () {
      final r = _ranker([_f('usda:1', 'Chili, NFS')], user: [_turkeyChili]);
      // "chili pepper": local has "chili" only, and "pepper" is not in it.
      final m = r.match('chili pepper');
      expect(m.ranked.firstWhere((c) => c.ref == 'local:1').fits, isFalse);
    });

    test('the last word of the name must be typed', () {
      final r = _ranker([_f('usda:1', 'Turkey, NFS')], user: [_turkeyChili]);
      final m = r.match('turkey');
      expect(m.ranked.firstWhere((c) => c.ref == 'local:1').fits, isFalse);
      expect(m.top!.ref, 'usda:1');
    });

    test('both words typed: the recipe still wins', () {
      final r = _ranker([_f('usda:1', 'Chili, NFS')], user: [_turkeyChili]);
      final m = r.match('turkey chili');
      expect(m.top!.ref, 'local:1');
      expect(m.top!.fits, isTrue);
      expect(m.top!.extra, 0);
    });

    test('a scanned product that was never logged does not jump the queue', () {
      final usda = [_f('usda:1', 'Yogurt, NFS', energy: 63)];
      final off = _f(
        'local:5',
        'Chobani yogurt',
        dataset: 'local',
        kind: 'off',
        energy: 60,
      );
      final r = _ranker(usda, user: [off]);
      final m = r.match('yogurt');
      expect(m.top!.ref, 'usda:1', reason: '5.4 key 2: not logged, no fit');
      final scanned = m.ranked.firstWhere((c) => c.ref == 'local:5');
      expect(scanned.fits, isFalse);
      expect(scanned.extra, 1); // still a candidate
    });

    test('a scanned product logged at least once does jump the queue', () {
      final usda = [_f('usda:1', 'Yogurt, NFS', energy: 63)];
      final off = _f(
        'local:5',
        'Chobani yogurt',
        dataset: 'local',
        kind: 'off',
        energy: 60,
      );
      final r = _ranker(usda, user: [off], history: {'local:5': 1});
      final m = r.match('yogurt');
      expect(m.top!.ref, 'local:5', reason: '5.4 key 2: logged once');
      expect(m.top!.fits, isTrue);
      expect(m.state, LineState.matched);
    });

    test('R37: trailing words with a digit are skipped for "fits"', () {
      final usda = [_f('usda:1', 'Yogurt, Greek, NFS', energy: 60)];
      final off = _f(
        'local:7',
        'Fage Greek yogurt 0%',
        dataset: 'local',
        kind: 'off',
        energy: 59,
      );
      final notLogged = _ranker(usda, user: [off]).match('greek yogurt');
      final c = notLogged.ranked.firstWhere((c) => c.ref == 'local:7');
      expect(c.fits, isFalse, reason: 'R37: never logged does not fit');
      expect(notLogged.top!.ref, 'usda:1');

      final logged = _ranker(
        usda,
        user: [off],
        history: {'local:7': 1},
      ).match('greek yogurt');
      expect(
        logged.top!.ref,
        'local:7',
        reason: 'R37: logged, last word skips 0%',
      );
      expect(logged.top!.fits, isTrue);
      expect(logged.state, LineState.matched);
    });

    test('R37: custom foods and recipes read the name the same way', () {
      final r = _ranker(
        [_f('usda:1', 'Soup, NFS')],
        user: [
          _f('local:8', 'Tomato soup 12', dataset: 'local', kind: 'custom'),
        ],
      );
      expect(r.match('soup').top!.ref, 'local:8');
      // A name that is only digits keeps its last word.
      final r2 = _ranker(
        [_f('usda:1', 'Soup, NFS')],
        user: [_f('local:9', '7 up', dataset: 'local', kind: 'custom')],
      );
      expect(r2.match('up').top!.fits, isTrue);
    });

    test('a custom food or recipe fits without being logged', () {
      final r = _ranker(
        [_f('usda:1', 'Soup, NFS')],
        user: [_f('local:3', 'Grandma soup', dataset: 'local', kind: 'custom')],
      );
      expect(r.match('soup').top!.ref, 'local:3');
    });
  });

  group('5.5 matched or guess', () {
    test('extra words make a guess (rule 2)', () {
      final r = _ranker([_f('usda:1', 'Cream, half and half', energy: 130)]);
      final m = r.match('half and half');
      expect(m.state, LineState.guess);
      expect(m.top!.extra, 1);
      expect(m.reason, startsWith('5.5 rule 2'));
    });

    test('a food the user logged before matches despite extra words', () {
      final r = _ranker(
        [_f('usda:1', 'Cream, half and half', energy: 130)],
        history: {'usda:1': 1},
      );
      expect(r.match('half and half').state, LineState.matched);
    });

    test('a query word that was not found makes a guess (rule 1)', () {
      final r = _ranker([_f('usda:1', 'Pizza, NFS', energy: 270)]);
      final m = r.match('leftover pizza');
      expect(m.top!.ref, 'usda:1');
      expect(m.state, LineState.guess);
      expect(m.reason, startsWith('5.5 rule 1'));
    });

    test('no candidate, or no food words, is not found', () {
      final r = _ranker([_f('usda:1', 'Pizza, NFS')]);
      expect(r.match('asdfgh').state, LineState.notFound);
      expect(r.match('').state, LineState.notFound);
      expect(r.match('I had').state, LineState.notFound);
      expect(r.match('').ranked, isEmpty);
    });

    group('rule 3: the 10 percent energy tie', () {
      Ranker withEnergy(double top, double other) => _ranker([
        _f('usda:1', 'Yogurt, NFS', energy: top),
        _f('usda:2', 'Yogurt, NS as to type', energy: other),
      ]);

      test('equal foods within 10 percent are a match', () {
        final m = withEnergy(100, 105).match('yogurt');
        expect(m.top!.ref, 'usda:1');
        expect(m.state, LineState.matched);
        expect(withEnergy(100, 110).match('yogurt').state, LineState.matched);
        expect(withEnergy(100, 90).match('yogurt').state, LineState.matched);
      });

      test('equal foods further apart are a guess', () {
        final m = withEnergy(100, 111).match('yogurt');
        expect(m.state, LineState.guess, reason: '5.5 rule 3');
        expect(m.reason, startsWith('5.5 rule 3'));
        expect(withEnergy(100, 89).match('yogurt').state, LineState.guess);
      });

      test('5 kcal is the limit when it is larger than 10 percent', () {
        expect(withEnergy(20, 25).match('yogurt').state, LineState.matched);
        expect(withEnergy(20, 15).match('yogurt').state, LineState.matched);
        expect(withEnergy(20, 25.5).match('yogurt').state, LineState.guess);
      });

      test('only foods that tie on keys 1 to 5 count', () {
        // Not generic: key 5 separates it from the top.
        final r = _ranker([
          _f('usda:1', 'Egg, NFS', energy: 140),
          _f('usda:2', 'Egg, boiled', energy: 300),
        ]);
        // "boiled" is an extra word too (key 3), so it does not tie either.
        expect(r.match('egg').state, LineState.matched);
        // Same keys 1 to 4 but different key 5.
        final r2 = _ranker([
          _f('usda:1', 'Egg, NFS', energy: 140),
          _f('usda:2', 'Egg, raw', energy: 300),
        ]);
        expect(r2.match('egg').top!.ref, 'usda:1');
        expect(r2.match('egg').state, LineState.matched);
        // History separates them as well.
        final r3 = _ranker(
          [
            _f('usda:1', 'Egg, NFS', energy: 140),
            _f('usda:2', 'Egg, NS as to type', energy: 300),
          ],
          history: {'usda:2': 1},
        );
        expect(r3.match('egg').top!.ref, 'usda:2');
        expect(r3.match('egg').state, LineState.matched);
      });

      test('a food with no energy does not decide the tie', () {
        final r = _ranker([
          _f('usda:1', 'Yogurt, NFS', energy: 100),
          _f('usda:2', 'Yogurt, NS as to type'),
        ]);
        expect(r.match('yogurt').state, LineState.matched);
      });
    });
  });

  group('5.6 defaults from the real data', () {
    // Typed text, the description of the top candidate, and its state.
    final table = <(String, String, LineState)>[
      ('egg', 'Egg, whole, cooked, NS as to cooking method', LineState.matched),
      (
        'eggs',
        'Egg, whole, cooked, NS as to cooking method',
        LineState.matched,
      ),
      ('butter', 'Butter, NFS', LineState.matched),
      ('toast', 'Bread, NS as to major flour, toasted', LineState.matched),
      ('sourdough toast', 'Bread, sour dough, toasted', LineState.matched),
      ('coffee', 'Coffee, NS as to type', LineState.matched),
      ('milk', 'Milk, NFS', LineState.matched),
      ('half and half', 'Cream, half and half', LineState.guess),
      ('rice', 'Rice, cooked, NFS', LineState.matched),
      (
        'chicken',
        'Chicken, NS as to part and cooking method, NS as to skin eaten',
        LineState.matched,
      ),
      ('salmon', 'Fish, salmon, NFS', LineState.guess),
      ('cream', 'Ice cream, NFS', LineState.guess),
      ('tea', 'Tea, ginger', LineState.guess),
      ('pizza', 'Pizza rolls', LineState.guess),
      ('walnuts', 'Walnut oil', LineState.guess),
    ];
    for (final (typed, name, state) in table) {
      test('"$typed" gives "$name" as ${state.name}', () {
        final m = _real().match(typed);
        expect(
          m.top?.description,
          name,
          reason: 'grammar 5.6 row "$typed": top candidate',
        );
        expect(
          m.state,
          state,
          reason: 'grammar 5.6 row "$typed": state (${m.reason})',
        );
      });
    }

    test('5.5: the common foods named as matched are matched', () {
      final r = _real();
      for (final w in [
        'eggs', 'butter', 'toast', 'coffee', 'milk', 'banana', 'oatmeal',
        'rice', 'bread', 'cheese', 'peanut butter', 'olive oil', 'honey', //
      ]) {
        final m = r.match(w);
        expect(
          m.state,
          LineState.matched,
          reason: 'grammar 5.5 "$w" is matched, but: ${m.reason} ${m.top}',
        );
      }
    });

    test('5.5: yogurt, chicken breast and wine are guesses', () {
      final r = _real();
      for (final w in ['yogurt', 'chicken breast', 'wine']) {
        final m = r.match(w);
        expect(
          m.state,
          LineState.guess,
          reason: 'grammar 5.5 "$w" is a guess, got ${m.reason} ${m.top}',
        );
      }
      expect(_real().match('yogurt').reason, startsWith('5.5 rule 3'));
    });

    test('5.5: one extra word is not enough (open question 5, option a)', () {
      final r = _real();
      expect(r.match('lemonade').state, LineState.guess);
      expect(r.match('walnuts').state, LineState.guess);
    });

    test('5.5: history turns "half and half" into a match (example 3)', () {
      final r = _real(history: {'usda:2705594': 1});
      final m = r.match('half and half');
      expect(m.ref, 'usda:2705594');
      expect(m.state, LineState.matched);
    });

    test('5.3: each synonym row gives the food it names', () {
      final r = _real();
      String top(String typed) => r.match(typed).top!.description;
      // Rows checked by a worked example: the food ref.
      final refs = {
        'french toast': 'usda:2708331', // example 54
        'toast': 'usda:2707592', // examples 4 and 39
        'black coffee': 'usda:2710373', // example 46
        'dr pepper': 'usda:2710545', // example 71
        '7 up': 'usda:173205', // example 73
        '7up': 'usda:173205', // example 73
        'v8': 'usda:2709731', // example 72
        'fries': 'usda:2709456', // example 15
        'pb': 'usda:2707537', // examples 33 and 57
        'burger': 'usda:2706920', // example 15
      };
      refs.forEach((typed, ref) {
        expect(r.match(typed).ref, ref, reason: '5.3 row "$typed"');
      });
      // Rows whose food the grammar describes in words.
      expect(top('melba toast'), 'Melba toast');
      expect(
        top('pb and j').toLowerCase(),
        contains('peanut butter and jelly'),
      );
      expect(top('pbj').toLowerCase(), contains('peanut butter and jelly'));
      expect(top('oj').toLowerCase(), contains('orange juice'));
      expect(top('evoo').toLowerCase(), contains('olive oil'));
      expect(top('mac').toLowerCase(), contains('macaroni'));
      expect(top('mayo').toLowerCase(), contains('mayonnaise'));
      expect(top('coke').toLowerCase(), contains('cola'));
      expect(top('soda').toLowerCase(), contains('soft drink'));
      expect(top('yoghurt').toLowerCase(), contains('yogurt'));
      expect(top('donut').toLowerCase(), contains('doughnut'));
    });

    test(
      'R36: an item that is all negation is flagged, not just not found',
      () {
        final r = _real();
        for (final t in ['no sugar', 'without milk']) {
          final m = r.match(t);
          expect(m.allNegated, isTrue, reason: 'R36: "$t"');
          expect(m.state, LineState.notFound);
          expect(m.ranked, isEmpty);
        }
        // Ordinary not found items are not flagged.
        for (final t in ['asdfgh', '', 'I had', 'coffee without sugar']) {
          expect(r.match(t).allNegated, isFalse, reason: '"$t"');
        }
        expect(r.match('coffee without sugar').ref, 'usda:2710373');
      },
    );

    test('5.3: the rows added later find a sensible food', () {
      final r = _real();
      // skim milk and nonfat milk: the fat free (skim) milk.
      for (final t in ['skim milk', 'nonfat milk']) {
        final m = r.match(t);
        expect(m.top!.description, 'Milk, fat free (skim)', reason: t);
        expect(m.state, LineState.matched, reason: '$t: ${m.reason}');
      }
      expect(
        r.match('chocolate skim milk').top!.description,
        'Chocolate milk, fat free (skim)',
      );
      // bbq: barbecue. Alone it is a generic "Barbecue meat" guess.
      expect(r.match('bbq').top!.description, 'Barbecue meat, NFS');
      expect(r.match('bbq').state, LineState.guess);
      expect(r.match('bbq chicken').top!.description, 'Barbecue chicken');
      expect(r.match('bbq chicken').state, LineState.matched);
      expect(r.match('bbq sauce').top!.description, 'Barbecue sauce');
      // cereal alone: the ready-to-eat generic entry, not the hot cereal.
      final c = r.match('cereal');
      expect(c.top!.description, 'Cereal, ready-to-eat, NFS');
      expect(c.state, LineState.matched, reason: c.reason);
      // The protected phrases keep their meaning.
      expect(r.match('cooked cereal').top!.description, 'Cereal, cooked, NFS');
      expect(
        r.match('cereal bar').top!.description,
        'Cereal or Granola bar, NFS',
      );
    });

    test('5.3: "coke" is not turned into "cake", "v8" not into a blend', () {
      final r = _real();
      expect(
        r.match('coke').top!.description.toLowerCase(),
        isNot(contains('cake')),
      );
      expect(r.match('v8').top!.description, isNot(contains('V-FUSION')));
    });

    test('5.3: "toast" without a synonym would only find French toast', () {
      // The synonym is what makes plain "toast" a bread.
      final m = _real().match('toast');
      expect(m.top!.description, startsWith('Bread'));
    });
  });

  group('5.7 the correction sheet search', () {
    test('lists foods that match at least one word, best first', () {
      final r = _ranker([
        _f('usda:1', 'Apple pie'),
        _f('usda:2', 'Apple, raw'),
        _f('usda:3', 'Banana, raw'),
        _f('usda:4', 'Pie, cherry'),
      ]);
      final hits = r.search('apple pie');
      expect(_refs(hits), 'usda:1, usda:2, usda:4');
      expect(hits.first.matched, 2);
      expect(hits.skip(1).every((c) => c.matched == 1), isTrue);
    });

    test('shows the top 20', () {
      final r = _ranker([
        for (var i = 0; i < 50; i++) _f('usda:${100 + i}', 'Apple type $i'),
        _f('usda:1', 'Banana'),
      ]);
      final hits = r.search('apple');
      expect(hits, hasLength(20), reason: '5.7 top 20');
      expect(r.search('apple', limit: 5), hasLength(5));
      expect(_refs(hits), _refs(r.search('apple')));
      // The best 20 in rank order: shorter descriptions first.
      expect(hits.first.description, 'Apple type 0');
    });

    test('a query with no match, or no words, lists nothing', () {
      final r = _ranker([_f('usda:1', 'Banana')]);
      expect(r.search('zzzzzz'), isEmpty);
      expect(r.search(''), isEmpty);
      expect(r.search('the of'), isEmpty);
    });

    test('uses the same normalizing: plurals, synonyms, typos', () {
      final r = _ranker([
        _f('usda:1', 'Banana, raw'),
        _f('usda:2', 'Doughnut, NFS'),
      ]);
      expect(r.search('bananas').first.ref, 'usda:1');
      expect(r.search('donut').first.ref, 'usda:2');
      expect(r.search('bananna').first.ref, 'usda:1');
    });

    test('the real data: one word lists 20 foods, both words first', () {
      final hits = _real().search('chicken rice');
      expect(hits, hasLength(20));
      expect(hits.first.matched, 2);
      for (final c in hits) {
        final words = descriptionSegments(c.description)
            .expand((s) => s)
            .toSet();
        expect(
          words.contains('chicken') || words.contains('rice'),
          isTrue,
          reason: '5.7: ${c.description} matches one word',
        );
      }
      // Ranked the same way as an item: all with two words come first.
      final matched = hits.map((c) => c.matched).toList();
      expect(matched, [...matched]..sort((a, b) => b.compareTo(a)));
    });

    test('the user\'s foods are listed too, and key 2 applies', () {
      final hits = _real(user: [_turkeyChili]).search('chili');
      expect(hits.first.ref, 'local:1');
    });
  });

  group('8.3 alternatives for the correction sheet', () {
    test('the pick plus up to 7 others, in rank order', () {
      final r = _ranker([
        for (var i = 0; i < 12; i++) _f('usda:${i + 1}', 'Soup, $i'),
      ]);
      final m = r.match('soup');
      expect(m.ranked, hasLength(Ranker.rankedCount));
      final alt = r.alternatives(m, currentRef: m.ref);
      expect(alt, hasLength(7));
      expect(alt.map((c) => c.ref), m.ranked.skip(1).map((c) => c.ref));
    });

    test('skips the current food when it is not the top one', () {
      final r = _ranker([
        for (var i = 0; i < 12; i++) _f('usda:${i + 1}', 'Soup, $i'),
      ]);
      final m = r.match('soup');
      final other = m.ranked[3].ref;
      final alt = r.alternatives(m, currentRef: other);
      expect(alt.map((c) => c.ref), isNot(contains(other)));
      expect(alt, hasLength(7));
      expect(alt.first.ref, m.ranked.first.ref);
    });

    test('a short list stays short', () {
      final r = _ranker([_f('usda:1', 'Soup, a'), _f('usda:2', 'Soup, b')]);
      final m = r.match('soup');
      expect(r.alternatives(m, currentRef: m.ref), hasLength(1));
    });
  });

  group('the worked examples that need only matching', () {
    // Examples that need an alias, a saved meal or a learned row (task 2.5).
    const skipped = {
      47: 'saved meal',
      48: 'saved meal',
      49: 'saved meal',
      50: 'saved meal',
      51: 'learned match',
      52: 'learned match',
    };
    final userFoods = {'local:1': _turkeyChili, 'local:2': _pbCookies};

    LineState expectedState(ExpectedLine l) {
      switch (l.state) {
        case ExpectedState.notFound:
          return LineState.notFound;
        case ExpectedState.guess:
          return LineState.guess;
        default:
          // Amount assumed without the Guess marker is a confident match.
          return l.markers.contains(ExpectedMarker.guess)
              ? LineState.guess
              : LineState.matched;
      }
    }

    List<String> run(
      int number,
      String input,
      ExampleSetup setup,
      List<ExpectedLine> lines,
    ) {
      final problems = <String>[];
      final user = [for (final r in setup.userFoods) userFoods[r]!];
      final r = _real(user: user, history: setup.history);
      final items = splitItems(
        input,
        userNames: [for (final f in userFoods.values) f.description],
      );
      final where = 'example $number (grammar 11.2)';
      if (items.length != lines.length) {
        problems.add(
          '$where: the split gives ${items.length} items '
          '${items.map((i) => '"${i.foodText}"').toList()} but '
          '${lines.length} lines are expected (task 2.1 split)',
        );
        return problems;
      }
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final exp = lines[i];
        final at = '$where line ${i + 1} "${item.foodText}"';
        final m = item.hasFoodWords ? r.match(item.foodText) : null;
        final gotState = m?.state ?? LineState.notFound;
        final wantState = expectedState(exp);
        if (gotState != wantState) {
          problems.add(
            '$at: expected ${wantState.name} but got ${gotState.name} '
            '(${m?.reason ?? 'no food words'}) ${m?.top}',
          );
        }
        if (exp.ref != null && m?.ref != exp.ref) {
          problems.add(
            '$at: expected ${exp.ref} ${exp.name ?? ''} but got ${m?.top} '
            '[${m?.reason}]',
          );
        }
      }
      return problems;
    }

    for (final e in workedExamples) {
      final why = skipped[e.number];
      test(
        'example ${e.number}: ${e.input.replaceAll('\n', ' / ')}',
        skip: why == null ? false : 'needs a $why (task 2.5)',
        () {
          final problems = <String>[];
          if (e.lines.isEmpty) {
            for (final input in [e.input, ...e.alternateInputs]) {
              final items = splitItems(input);
              expect(
                items.where((i) => i.hasFoodWords),
                isEmpty,
                reason: 'example ${e.number}: no food words in "$input"',
              );
            }
            return;
          }
          problems.addAll(run(e.number, e.input, e.setup, e.lines));
          for (final v in e.variants) {
            problems.addAll(
              run(
                e.number,
                e.input,
                v.setup,
                v.lines,
              ).map((p) => '${v.description}: $p'),
            );
          }
          expect(problems, isEmpty, reason: problems.join('\n'));
        },
      );
    }
  });

  group('speed (the strict budget is task 2.5)', () {
    test('build the index and rank the brief\'s example', () {
      // Build once more, to time it with the data already read.
      final sw = Stopwatch()..start();
      final again = SearchIndex.build(_usdaFoods);
      final buildMs = sw.elapsedMilliseconds;
      expect(again.length, _usdaFoods.length);

      final r = Ranker(again);
      // The five items of the brief's example, as their food words.
      const items = [
        'eggs',
        'sourdough toast',
        'butter',
        'coffee',
        'half and half',
      ];
      sw
        ..reset()
        ..start();
      for (final t in items) {
        r.match(t);
      }
      final coldUs = sw.elapsedMicroseconds;

      final runs = <int>[];
      for (var k = 0; k < 200; k++) {
        sw
          ..reset()
          ..start();
        for (final t in items) {
          r.match(t);
        }
        runs.add(sw.elapsedMicroseconds);
      }
      runs.sort();
      final median = runs[runs.length ~/ 2];
      final p95 = runs[(runs.length * 0.95).floor()];

      // Typing the last item one letter at a time: each step re-ranks it.
      const typed = 'half and half';
      final steps = <int>[];
      for (var n = 1; n <= typed.length; n++) {
        sw
          ..reset()
          ..start();
        r.match(typed.substring(0, n));
        steps.add(sw.elapsedMicroseconds);
      }
      steps.sort();

      printOnFailure(
        'BENCH read $_readMs ms, index build $_buildMs ms (second build '
        '$buildMs ms); 5 items cold ${(coldUs / 1000).toStringAsFixed(2)} ms, '
        'warm median ${(median / 1000).toStringAsFixed(2)} ms, '
        'p95 ${(p95 / 1000).toStringAsFixed(2)} ms; one item per keystroke '
        'max ${(steps.last / 1000).toStringAsFixed(2)} ms',
      );

      // Generous limits, so a slow CI machine cannot make this flaky.
      expect(buildMs, lessThan(10000), reason: '12.3: index build');
      expect(coldUs, lessThan(2000000), reason: '12.3: 5 items cold');
      expect(p95, lessThan(500000), reason: '12.3: 5 items warm p95');
      expect(steps.last, lessThan(500000), reason: '12.3: one keystroke');
    });

    test('misspelled words are corrected once, then remembered', () {
      final r = Ranker(_usdaIndex);
      const text = 'chocolatte strawbery brocoli bananna chiken';
      final sw = Stopwatch()..start();
      final first = r.match(text);
      final firstUs = sw.elapsedMicroseconds;
      final runs = <int>[];
      for (var k = 0; k < 50; k++) {
        sw
          ..reset()
          ..start();
        final m = r.match(text);
        runs.add(sw.elapsedMicroseconds);
        expect(m.words, first.words, reason: 'same answer every time');
      }
      runs.sort();
      // A new Ranker on the same USDA index reuses the index's near words.
      sw
        ..reset()
        ..start();
      Ranker(_usdaIndex).match(text);
      final newRankerUs = sw.elapsedMicroseconds;
      printOnFailure(
        'TYPO 5 misspelled words: first ${firstUs / 1000} ms, repeat median '
        '${runs[25] / 1000} ms, new Ranker ${newRankerUs / 1000} ms',
      );
      expect(first.corrected, isTrue);
      expect(first.words, [
        'chocolate',
        'strawberry',
        'broccoli',
        'banana',
        'chicken',
      ]);
      expect(firstUs, lessThan(1000000));
      expect(runs[25], lessThan(100000), reason: 'repeat is cheap');
      expect(runs[25], lessThanOrEqualTo(firstUs));
    });

    test(
      'the fillers and synonyms lists the index uses are the shared data',
      () {
        expect(fillerWords, contains('the'));
        expect(synonyms, contains('toast'));
      },
    );
  });
}
