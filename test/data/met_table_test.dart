// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:io';

import 'package:daybook/data/met_table.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bundle that holds one asset as text, or none when [text] is null.
class _FakeBundle extends AssetBundle {
  _FakeBundle(this.text);
  String? text;

  @override
  Future<ByteData> load(String key) async => throw StateError('use loadString');

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final t = text;
    if (t == null) throw StateError('Unable to load asset');
    return t;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MetTable table;
  late String raw;

  setUpAll(() async {
    table = await MetTable.load();
    raw = File('assets/met/compendium_2024.csv').readAsStringSync();
  });

  MetGroup grp(String name) => table.groups.firstWhere((g) => g.name == name);

  group('the bundled asset', () {
    test('every row loads: the file has as many rows as the table', () {
      final lines = raw.split('\n').where((l) => l.isNotEmpty).length - 1;
      expect(table.all.length, lines);
      expect(table.all.length, 1111);
    });

    test('codes are unique, five digits, and in order', () {
      final codes = [for (final a in table.all) a.code];
      expect(codes.toSet().length, codes.length);
      expect(codes, [...codes]..sort());
      for (final c in codes) {
        expect(c, matches(RegExp(r'^\d{5}$')));
      }
    });

    test('every row has a heading, a MET, a description', () {
      for (final a in table.all) {
        expect(a.heading, isNotEmpty, reason: a.code);
        expect(a.description, isNotEmpty, reason: a.code);
        expect(a.met, greaterThan(0), reason: a.code);
        expect(a.metText, matches(RegExp(r'^\d+\.\d+$')), reason: a.code);
        expect(a.met, double.parse(a.metText), reason: a.code);
      }
      expect({for (final a in table.all) a.heading}.length, 22);
    });

    test('the MET is shown as published', () {
      expect(table.byCode('18290')!.metText, '8.00');
      expect(table.byCode('01003')!.metText, '14.0');
      expect(table.byCode('12050')!.metText, '9.3');
    });

    test('spot values', () {
      expect(table.byCode('12050')!.met, 9.3);
      expect(table.byCode('02054')!.met, 3.5);
      expect(table.byCode('12060')!.met, 10.5);
      expect(table.byCode('17190')!.met, 3.8);
    });

    test('a wrapped row holds its whole description', () {
      expect(
        table.byCode('02050')!.description,
        endsWith('vigorous effort (Taylor Code 210)'),
      );
      expect(
        table.byCode('03039')!.description,
        endsWith('paso doble, jive)'),
      );
    });

    test('a description with quotes and commas survives', () {
      expect(
        table.byCode('02280')!.description,
        'Virtual Reality Fitness, Supernatural™ “Flow”, “Boxing" '
        'vigorous intensity',
      );
    });

    test('lookup of a code that is not there is null', () {
      expect(table.byCode('99999'), isNull);
      expect(table.byCode(''), isNull);
    });

    test('speeds are read as the file gives them', () {
      final a = table.byCode('12050')!;
      expect((a.minMph, a.maxMph), (6.0, 6.3));
      final single = table.byCode('12060')!;
      expect((single.minMph, single.maxMph), (6.7, 6.7));
      final less = table.byCode('17151')!;
      expect((less.minMph, less.maxMph), (null, 2.0));
      final more = table.byCode('01060')!;
      expect((more.minMph, more.maxMph), (20.0, null));
      final none = table.byCode('12145')!;
      expect(none.hasSpeed, isFalse);
    });

    test('loading twice shares one load', () async {
      expect(identical(await MetTable.load(), table), isTrue);
    });
  });

  group('the groups', () {
    test('are Running, Walking, Bicycling in that order', () {
      expect([for (final g in table.groups) g.name], [
        'Running',
        'Walking',
        'Bicycling',
      ]);
    });

    test('general entries exist and are the agreed rows', () {
      final r = grp('Running').general;
      expect(
        (r.code, r.metText, r.description),
        ('12145', '10.5', 'Running, self-selected pace'),
      );
      final w = grp('Walking').general;
      expect((w.code, w.metText), ('17190', '3.8'));
      expect(
        w.description,
        'Walking, 2.8 to 3.4 mph, level, moderate pace, firm surface',
      );
      final b = grp('Bicycling').general;
      expect(
        (b.code, b.metText, b.description),
        ('01014', '7.0', 'Bicycling, general'),
      );
    });

    test('every band is a row of its own heading and gives a speed', () {
      for (final g in table.groups) {
        expect(g.bands, isNotEmpty);
        for (final b in g.bands) {
          expect(b.heading, g.name, reason: b.code);
          expect(b.hasSpeed, isTrue, reason: b.code);
          expect(identical(table.byCode(b.code), b), isTrue);
        }
        expect(g.general.heading, g.name);
      }
    });

    test('bands are listed in speed order, slowest first', () {
      for (final g in table.groups) {
        for (var i = 1; i < g.bands.length; i++) {
          final a = g.bands[i - 1];
          final b = g.bands[i];
          expect(
            (a.minMph ?? 0) <= (b.minMph ?? 0),
            isTrue,
            reason: '${a.code} before ${b.code}',
          );
        }
        final codes = [for (final b in g.bands) b.code];
        expect(codes.toSet().length, codes.length);
      }
    });

    test('Running bands read as the frame says', () {
      final run = grp('Running').bands;
      expect([for (final b in run) b.code], [
        '12026', '12028', '12029', '12030', '12045', '12050', '12060', //
        '12070', '12080', '12090', '12100', '12110', '12115', '12120',
        '12130', '12132', '12134', '12135',
      ]);
      final six = run.firstWhere((b) => b.code == '12050');
      expect((six.minMph, six.maxMph, six.metText), (6.0, 6.3, '9.3'));
    });

    test('Walking and Bicycling bands in order', () {
      expect([for (final b in grp('Walking').bands) b.code], [
        '17151', '17152', '17170', '17190', '17200', '17220', '17230', //
        '17231',
      ]);
      expect([for (final b in grp('Bicycling').bands) b.code], [
        '01010', '01020', '01030', '01040', '01050', '01060',
      ]);
      // The "less than" band comes first, the "greater than" band last.
      expect(grp('Walking').bands.first.minMph, isNull);
      expect(grp('Bicycling').bands.last.maxMph, isNull);
    });

    test('groupOf finds a band or general entry, and nothing else', () {
      expect(table.groupOf('12050')!.name, 'Running');
      expect(table.groupOf('12145')!.name, 'Running');
      expect(table.groupOf('17190')!.name, 'Walking');
      expect(table.groupOf('01014')!.name, 'Bicycling');
      expect(table.groupOf('02054'), isNull);
      expect(table.groupOf('12255'), isNull);
    });
  });

  group('search', () {
    test('words in any order, case ignored', () {
      final a = table.search('rowing stationary');
      expect(a, isNotEmpty);
      expect(
        [for (final x in table.search('STATIONARY Rowing')) x.code],
        [for (final x in a) x.code],
      );
      for (final x in a) {
        expect(x.description.toLowerCase(), contains('rowing'));
        expect(x.description.toLowerCase(), contains('stationary'));
      }
    });

    test('every word must match, and results are in code order', () {
      final all = table.search('running');
      final narrow = table.search('running 6.7');
      expect(narrow.length, lessThan(all.length));
      expect(narrow.map((a) => a.code), contains('12060'));
      final codes = [for (final a in all) a.code];
      expect(codes, [...codes]..sort());
    });

    test('the heading counts too', () {
      expect(
        table.search('dancing').map((a) => a.heading).toSet(),
        contains('Dancing'),
      );
    });

    test('an empty or blank query lists everything', () {
      expect(table.search('').length, table.all.length);
      expect(table.search('   ').length, table.all.length);
    });

    test('no match gives an empty list', () {
      expect(table.search('zzzzqqq'), isEmpty);
    });
  });

  group('a bad asset', () {
    test('a missing asset throws a FormatException naming the asset', () {
      expect(
        MetTable.load(bundle: _FakeBundle(null)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('assets/met/compendium_2024.csv'),
          ),
        ),
      );
    });

    test('a wrong header and a repeated code are refused', () async {
      expect(
        MetTable.load(bundle: _FakeBundle('code,name\n')),
        throwsA(isA<FormatException>()),
      );
      final lines = raw.split('\n');
      final dup = '${lines.take(3).join('\n')}\n${lines[2]}\n';
      await expectLater(
        MetTable.load(bundle: _FakeBundle(dup)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('Line 4'), isNot(contains('Bicycling'))),
          ),
        ),
      );
    });

    test('a file without the group rows is refused', () {
      final lines = raw.split('\n');
      final two = '${lines.take(3).join('\n')}\n';
      expect(
        MetTable.load(bundle: _FakeBundle(two)),
        throwsA(isA<FormatException>()),
      );
    });

    test('a failed load is not remembered', () async {
      final bundle = _FakeBundle(null);
      await expectLater(
        MetTable.load(bundle: bundle),
        throwsA(isA<FormatException>()),
      );
      bundle.text = raw;
      expect((await MetTable.load(bundle: bundle)).all.length, 1111);
    });
  });
}
