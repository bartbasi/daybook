// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/services.dart';

import '../parser/normalize.dart';

// The 2024 Adult Compendium of Physical Activities (assets/met, built by
// tools/build_met_table.py). MET values and descriptions are exactly as
// published and are never rounded, blended or renamed. No network.
//
// What tasks 5.2 and 5.3 can rely on:
// - [MetTable.all] holds every row, sorted by code (the file's order). Codes
//   are unique. [MetTable.byCode] looks one up (null when there is none).
// - [MetActivity.metText] is the value as published ('9.3', and '8.00' for
//   18290); [MetActivity.met] is the same number for the maths.
// - [MetTable.search] is the "Other..." search: every word of the query must
//   be in the description or the major heading, any order, case and accents
//   ignored. Results keep code order. An empty query lists everything.
// - [MetTable.groups] are Running, Walking and Bicycling, in that order. A
//   group's [MetGroup.bands] are its rows that give a speed in mph, sorted
//   from the slowest (a row with no minimum, "less than", is first). Each band
//   holds the speed as the Compendium wrote it: [MetActivity.minMph] and
//   [MetActivity.maxMph] (equal for a single speed, only one set for "less
//   than" or "greater than"). Which band holds a pace is task 5.2's job.
// - [MetGroup.general] is the entry for a session with no distance.
// - Other Compendium rows are their own activities; a few rows of the three
//   headings (uphill, treadmill, backpack, stroller and so on) are not bands
//   because they describe other conditions, but they stay in [all] and in
//   search with their speeds recorded.
// - This file has no user-facing text. Screens use their own words from
//   strings.dart for the group names.

const _assetPath = 'assets/met/compendium_2024.csv';

/// One Compendium row.
class MetActivity {
  MetActivity({
    required this.code,
    required this.heading,
    required this.metText,
    required this.description,
    this.minMph,
    this.maxMph,
  }) : met = double.parse(metText);

  /// The five digit Compendium code, for example '12050'.
  final String code;

  /// The major heading, for example 'Running' or 'Conditioning Exercise'.
  final String heading;

  /// The MET value as published.
  final String metText;
  final double met;
  final String description;

  /// The speed range in mph as the description writes it. Both null: no speed
  /// given. Equal: one speed. Only [maxMph]: "less than". Only [minMph]:
  /// "greater than".
  final double? minMph;
  final double? maxMph;

  bool get hasSpeed => minMph != null || maxMph != null;

  late final String _key = foldText('$heading $description');
}

/// Running, Walking or Bicycling: the rows with speed bands, and the general
/// entry used when no distance is given.
class MetGroup {
  MetGroup._(this.name, this.general, this.bands);

  /// The Compendium heading: 'Running', 'Walking' or 'Bicycling'.
  final String name;
  final MetActivity general;

  /// Slowest first.
  final List<MetActivity> bands;

  bool contains(String code) =>
      general.code == code || bands.any((b) => b.code == code);
}

// The groups, in the order the cardio screen lists them. The band rows are
// chosen by code: the plain, flat-ground speed series of each heading. A test
// checks that every code exists and gives a speed.
const _groupDefs = <(String, String, List<String>)>[
  (
    'Running',
    '12145',
    [
      '12026', '12028', '12029', '12030', '12045', '12050', '12060', //
      '12070', '12080', '12090', '12100', '12110', '12115', '12120',
      '12130', '12132', '12134', '12135',
    ],
  ),
  (
    'Walking',
    '17190',
    [
      '17151', '17152', '17170', '17190', '17200', '17220', '17230', '17231', //
    ],
  ),
  (
    'Bicycling',
    '01014',
    ['01010', '01020', '01030', '01040', '01050', '01060'],
  ),
];

class MetTable {
  MetTable._(this.all) {
    _byCode = {for (final a in all) a.code: a};
    groups = List.unmodifiable([
      for (final (name, general, bands) in _groupDefs)
        MetGroup._(
          name,
          _need(general),
          List.unmodifiable(
            <MetActivity>[for (final c in bands) _need(c, speed: true)]
              ..sort(_bySpeed),
          ),
        ),
    ]);
  }

  /// Every row, sorted by code.
  final List<MetActivity> all;
  late final Map<String, MetActivity> _byCode;

  /// Running, Walking, Bicycling.
  late final List<MetGroup> groups;

  static final _cache = Expando<Future<MetTable>>();

  /// Loads the bundled table (once per bundle; a second call shares the
  /// first). A missing or bad asset throws a [FormatException] that names the
  /// asset (and the line), never its content. A failed load is not remembered.
  static Future<MetTable> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    final future = _cache[b] ??= _read(b);
    try {
      return await future;
    } catch (_) {
      if (identical(_cache[b], future)) _cache[b] = null;
      rethrow;
    }
  }

  static Future<MetTable> _read(AssetBundle bundle) async {
    final String text;
    try {
      text = await bundle.loadString(_assetPath, cache: false);
    } catch (_) {
      throw const FormatException('$_assetPath could not be loaded');
    }
    final lines = text.replaceAll('\r', '').split('\n')
      ..removeWhere((l) => l.isEmpty);
    if (lines.isEmpty || lines.first != _header) {
      throw const FormatException('$_assetPath has the wrong header');
    }
    final rows = <MetActivity>[];
    final seen = <String>{};
    for (var i = 1; i < lines.length; i++) {
      try {
        final f = _splitLine(lines[i]);
        if (f.length != 6) throw const FormatException('fields');
        double? mph(String s) => s.isEmpty ? null : double.parse(s);
        final a = MetActivity(
          code: f[0],
          heading: f[1],
          metText: f[2],
          description: f[3],
          minMph: mph(f[4]),
          maxMph: mph(f[5]),
        );
        if (a.code.isEmpty || a.description.isEmpty || !seen.add(a.code)) {
          throw const FormatException('row');
        }
        rows.add(a);
      } catch (_) {
        throw FormatException('Line ${i + 1} of $_assetPath has the wrong shape');
      }
    }
    rows.sort((a, b) => a.code.compareTo(b.code));
    try {
      return MetTable._(List.unmodifiable(rows));
    } catch (_) {
      throw const FormatException('$_assetPath is missing a group row');
    }
  }

  MetActivity _need(String code, {bool speed = false}) {
    final a = _byCode[code];
    if (a == null || (speed && !a.hasSpeed)) throw StateError('group row');
    return a;
  }

  /// The row for [code], or null.
  MetActivity? byCode(String code) => _byCode[code];

  /// The group that lists [code] as a band or as its general entry, or null.
  MetGroup? groupOf(String code) {
    for (final g in groups) {
      if (g.contains(code)) return g;
    }
    return null;
  }

  /// The rows whose description or heading holds every word of [query].
  List<MetActivity> search(String query) {
    final words = foldText(query).split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    return [
      for (final a in all)
        if (words.every(a._key.contains)) a,
    ];
  }
}

const _header = 'code,heading,met,description,min_mph,max_mph';

// Slowest first: by the lower edge (none counts as 0), then the upper edge
// (none counts as no limit), then code.
int _bySpeed(MetActivity a, MetActivity b) {
  final lo = (a.minMph ?? 0).compareTo(b.minMph ?? 0);
  if (lo != 0) return lo;
  final hi = (a.maxMph ?? double.infinity).compareTo(
    b.maxMph ?? double.infinity,
  );
  return hi != 0 ? hi : a.code.compareTo(b.code);
}

/// Splits one CSV line: fields separated by commas, a field in double quotes
/// may hold commas and doubled quotes. The file has no line breaks inside a
/// field.
List<String> _splitLine(String line) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cur.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      out.add(cur.toString());
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  if (quoted) throw const FormatException('quote');
  out.add(cur.toString());
  return out;
}
