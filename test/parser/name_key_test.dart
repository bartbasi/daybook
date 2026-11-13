// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:daybook/parser/line.dart';
import 'package:daybook/parser/name_key.dart';
import 'package:daybook/parser/parser.dart';
import 'package:daybook/parser/search_index.dart';
import 'package:daybook/parser/user_snapshot.dart';
import 'package:daybook/parser/user_snapshot_data.dart';
import 'package:flutter_test/flutter_test.dart';

// nameKey: the one way a stored name and typed text meet (grammar 6.1).

void main() {
  group('nameKey', () {
    test('the clean-up spellings give the same key', () {
      expect(nameKey('pb&j'), nameKey('pb and j'));
      expect(nameKey('pb&j'), 'pb and j');
      expect(nameKey('coffee w/ milk'), nameKey('coffee with milk'));
      expect(nameKey('2-percent latte'), nameKey('2% latte'));
      expect(nameKey('2% latte'), '2% latte');
      expect(nameKey('V-8 juice'), nameKey('v8 juice'));
      expect(nameKey('V-8 juice'), 'v8 juice');
    });

    test('lower case, punctuation and spacing', () {
      expect(nameKey('  Usual   BREAKFAST! '), 'usual breakfast');
      expect(nameKey("Mom's pie"), 'moms pie');
    });

    test('an accented name in composed and decomposed form', () {
      expect(nameKey('Café au lait'), 'cafe au lait');
      expect(nameKey('Café au lait'), nameKey('Café au lait'));
      expect(nameKey('jalapeño'), nameKey('jalapeño'));
    });

    test('no stemming and no filler removal', () {
      expect(nameKey('my oatmeals'), 'my oatmeals');
    });
  });

  group('an alias stored through nameKey expands when typed', () {
    final parser = Parser(SearchIndex.build(const []), (ref) => null);

    Line parse(String stored, String typed) {
      final data = UserSnapshotData(
        savedMeals: const [SavedMealData(id: 1, name: 'Snack')],
        aliases: [AliasData(nameKey(stored), 1)],
      );
      final lines = parser.parseMeal(typed, -1, UserSnapshot.from(data));
      expect(lines, hasLength(1), reason: '$stored / $typed');
      return lines.single;
    }

    for (final (stored, typed) in [
      ('pb&j', 'pb&j'),
      ('pb&j', 'pb and j'),
      ('pb and j', 'pb&j'),
      ('coffee w/ milk', 'coffee with milk'),
      ('coffee with milk', 'coffee w/ milk'),
      ('2-percent latte', '2% latte'),
      ('2% latte', '2-percent latte'),
      ('V-8 juice', 'v8 juice'),
      ('v8 juice', 'V-8 juice'),
    ]) {
      test('stored "$stored", typed "$typed"', () {
        final l = parse(stored, typed);
        expect(l.state, LineState.aliasOrSavedMeal);
        expect(l.savedMealId, 1);
      });
    }

    test('a saved meal name is found by any spelling', () {
      final data = UserSnapshotData(
        savedMeals: const [SavedMealData(id: 4, name: 'PB&J')],
      );
      final s = UserSnapshot.from(data);
      for (final t in ['pb&j', 'PB and J', 'pb and j']) {
        expect(parser.parseMeal(t, -1, s).single.savedMealId, 4, reason: t);
      }
    });
  });
}
