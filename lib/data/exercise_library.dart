// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:convert';

import 'package:flutter/services.dart';

import '../parser/normalize.dart';
import 'database.dart';

// The exercise library: the bundled wger list (assets/exercises, built by
// tools/build_exercise_data.py) plus the exercises the user made. No network.
//
// What tasks 4.3 and 4.4 can rely on:
// - An exercise is stored in workouts and routines only as its [ref]
//   ('wger:<id>' or 'local:<id>') and the name at that time. Look it up with
//   [ExerciseLibrary.lookup]; a ref that no longer exists comes back as a
//   result with found false, so keep showing the stored name.
// - [ExerciseLibrary.all] and [ExerciseLibrary.search] list library and user
//   exercises in one list, sorted by name (accents and case ignored, then ref),
//   so the order is the same on every load. Archived user exercises are left
//   out of both but still resolve through lookup.
// - [LibraryExercise.credit], [license], [licenseUrl] and [url] are what the
//   detail screen shows. They are null for the user's own exercises. Credit
//   text never holds an email address (the build tool replaced those).
// - Descriptions are plain text, lines separated by '\n'.
// - [ExerciseLibrary.groupsOf] is the `musclesOf` function for the weekly
//   volume: the [VolumeGroup]s of an exercise's primary muscles, each once.
//   Screens turn each group into a word from strings.dart; this file has no
//   user-facing text. The enum order is the order of the weekly volume rows.
//   The mapping from wger's muscle names to groups is Daybook's own choice,
//   not wger's. A test fails if a refresh brings a muscle with no group.
// - [ExerciseLibrary.search] takes the picker chip as `group`: Chest,
//   Shoulders, Back, Abs, Calves, Arms or Legs (or a wger muscle name).

/// The muscle groups of the weekly volume, in the order the frames list
/// them. Glutes and abs are not in the frames; they are here so those sets
/// are not lost.
enum VolumeGroup {
  chest,
  shoulders,
  triceps,
  back,
  biceps,
  quads,
  hamstrings,
  glutes,
  calves,
  abs,
}

/// Daybook's own mapping from a wger primary muscle name to one group.
const volumeGroupOfMuscle = <String, VolumeGroup>{
  'Chest': VolumeGroup.chest,
  'Serratus anterior': VolumeGroup.chest,
  'Shoulders': VolumeGroup.shoulders,
  'Triceps': VolumeGroup.triceps,
  'Lats': VolumeGroup.back,
  'Trapezius': VolumeGroup.back,
  'Biceps': VolumeGroup.biceps,
  'Brachialis': VolumeGroup.biceps,
  'Quads': VolumeGroup.quads,
  'Hamstrings': VolumeGroup.hamstrings,
  'Glutes': VolumeGroup.glutes,
  'Calves': VolumeGroup.calves,
  'Soleus': VolumeGroup.calves,
  'Abs': VolumeGroup.abs,
  'Obliquus externus abdominis': VolumeGroup.abs,
};

// For an exercise with no primary muscle: the wger categories that name one
// group. Arms, Legs and Cardio name none.
const _groupOfCategory = <String, VolumeGroup>{
  'chest': VolumeGroup.chest,
  'shoulders': VolumeGroup.shoulders,
  'back': VolumeGroup.back,
  'abs': VolumeGroup.abs,
  'calves': VolumeGroup.calves,
};

// Picker chips that cover several groups, used to place the user's own
// exercises (which have no wger category).
const _chipGroups = <String, Set<VolumeGroup>>{
  'chest': {VolumeGroup.chest},
  'shoulders': {VolumeGroup.shoulders},
  'back': {VolumeGroup.back},
  'abs': {VolumeGroup.abs},
  'calves': {VolumeGroup.calves},
  'arms': {VolumeGroup.biceps, VolumeGroup.triceps},
  'legs': {
    VolumeGroup.quads,
    VolumeGroup.hamstrings,
    VolumeGroup.glutes,
    VolumeGroup.calves,
  },
};

final _foldedMuscleGroups = {
  for (final e in volumeGroupOfMuscle.entries) foldText(e.key): e.value,
};

const _assetPath = 'assets/exercises/wger_exercises.json';

/// One exercise, from wger or made by the user, in one shape.
class LibraryExercise {
  LibraryExercise({
    required this.ref,
    required this.name,
    this.aliases = const [],
    this.category,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.equipment = const [],
    this.description = '',
    this.license,
    this.licenseFull,
    this.licenseUrl,
    this.authors = const [],
    this.url,
    this.archived = false,
  });

  /// `wger:<id>` or `local:<id>`.
  final String ref;
  final String name;
  final List<String> aliases;
  final String? category;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> equipment;

  /// Plain text. Empty for user exercises and for a few wger ones.
  final String description;

  /// Short license name as wger gives it, for example 'CC-BY-SA 4'. Null for
  /// the user's own exercises.
  final String? license;
  final String? licenseFull;
  final String? licenseUrl;

  /// Authors, never an email address. Empty for the user's own exercises.
  final List<String> authors;

  /// The exercise's page on wger.de. Null for the user's own exercises.
  final String? url;
  final bool archived;

  bool get isUser => ref.startsWith('local:');

  /// The authors as one line, or null when there are none (user exercises).
  /// Two authors are joined with 'and', three or more with commas and a
  /// final 'and', so "Text by A and B, CC BY-SA 4.0" reads clearly.
  String? get credit {
    if (authors.isEmpty) return null;
    if (authors.length == 1) return authors.first;
    final head = authors.sublist(0, authors.length - 1);
    final sep = authors.length == 2 ? ' and ' : ', and ';
    return '${head.join(', ')}$sep${authors.last}';
  }

  /// The license as people write it: 'CC-BY-SA 4' is 'CC BY-SA 4.0',
  /// 'CC-BY-SA 3' is 'CC BY-SA 3.0', 'CC0' is 'CC0 1.0'. Anything else is
  /// shown as stored. [license] itself stays as wger gives it.
  String? get licenseLabel => switch (license) {
    'CC-BY-SA 4' => 'CC BY-SA 4.0',
    'CC-BY-SA 3' => 'CC BY-SA 3.0',
    'CC0' => 'CC0 1.0',
    final other => other,
  };

  late final String _nameKey = foldText(name);
  late final List<String> _aliasKeys = [for (final a in aliases) foldText(a)];

  /// The volume groups of the primary muscles, each once, in the order of
  /// the muscles. With no primary muscle, the group the category names (Chest,
  /// Shoulders, Back, Abs, Calves), else empty.
  late final List<VolumeGroup> groups = () {
    if (primaryMuscles.isEmpty) {
      final g = _groupOfCategory[foldText(category ?? '')];
      return g == null ? const <VolumeGroup>[] : [g];
    }
    return <VolumeGroup>{
      for (final m in primaryMuscles) ?_foldedMuscleGroups[foldText(m)],
    }.toList();
  }();

  late final List<String> _groupKeys = [
    for (final m in primaryMuscles) foldText(m),
    if (category != null) foldText(category!),
  ];

  factory LibraryExercise.fromWger(Map<String, dynamic> j) {
    List<String> strings(String key) => [
      for (final s in (j[key] as List)) s as String,
    ];
    return LibraryExercise(
      ref: 'wger:${j['id']}',
      name: j['name'] as String,
      aliases: strings('aliases'),
      category: (j['category'] as String).isEmpty
          ? null
          : j['category'] as String,
      primaryMuscles: strings('primary_muscles'),
      secondaryMuscles: strings('secondary_muscles'),
      equipment: strings('equipment'),
      description: j['description'] as String,
      license: j['license'] as String,
      licenseFull: j['license_full'] as String,
      licenseUrl: j['license_url'] as String,
      authors: strings('authors'),
      url: j['url'] as String,
    );
  }

  /// A row of the user's own `exercises` table. Muscles are comma separated.
  factory LibraryExercise.fromUser(Exercise row) {
    List<String> split(String s) => [
      for (final p in s.split(','))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    final eq = row.equipment?.trim() ?? '';
    return LibraryExercise(
      ref: 'local:${row.id}',
      name: row.name,
      category: row.category,
      primaryMuscles: split(row.primaryMuscles),
      secondaryMuscles: split(row.secondaryMuscles),
      equipment: eq.isEmpty ? const [] : [eq],
      archived: row.archived,
    );
  }
}

/// The answer to "which exercise is this ref". When [found] is false the ref
/// no longer exists (a deleted user exercise, or a wger id the bundled list
/// does not have); the caller keeps the name it stored.
class ExerciseLookup {
  const ExerciseLookup._(this.ref, this.exercise);
  final String ref;
  final LibraryExercise? exercise;
  bool get found => exercise != null;
}

class ExerciseLibrary {
  ExerciseLibrary._(this._wger, this._user) {
    final merged = [..._wger, ..._user]
      ..sort((a, b) {
        final c = a._nameKey.compareTo(b._nameKey);
        return c != 0 ? c : a.ref.compareTo(b.ref);
      });
    _byRef = {for (final e in merged) e.ref: e};
    all = List.unmodifiable([
      for (final e in merged)
        if (!e.archived) e,
    ]);
  }

  final List<LibraryExercise> _wger;
  final List<LibraryExercise> _user;
  late final Map<String, LibraryExercise> _byRef;

  /// Every listed exercise, sorted by name. Archived user exercises are not
  /// in it.
  late final List<LibraryExercise> all;

  static final _wgerCache = Expando<Future<List<LibraryExercise>>>();

  /// Loads the bundled wger list (once per bundle; a second call shares the
  /// first) with [userExercises] merged in. The file is under 1 MB, so it is
  /// decoded on the calling isolate. A missing or bad asset throws a
  /// [FormatException] that names the asset (and the entry number), never its
  /// content, and a failed load is not remembered: the next call tries again.
  static Future<ExerciseLibrary> load({
    AssetBundle? bundle,
    List<LibraryExercise> userExercises = const [],
  }) async {
    final b = bundle ?? rootBundle;
    final future = _wgerCache[b] ??= _readWger(b);
    try {
      return ExerciseLibrary._(await future, userExercises);
    } catch (_) {
      if (identical(_wgerCache[b], future)) _wgerCache[b] = null;
      rethrow;
    }
  }

  static Future<List<LibraryExercise>> _readWger(AssetBundle bundle) async {
    final String text;
    try {
      // Not cached by the bundle, so the 0.7 MB string is not kept.
      text = await bundle.loadString(_assetPath, cache: false);
    } catch (_) {
      throw const FormatException('$_assetPath could not be loaded');
    }
    final Object? data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      throw const FormatException('$_assetPath is not valid JSON');
    }
    if (data is! List) {
      throw const FormatException('$_assetPath is not a list');
    }
    final out = <LibraryExercise>[];
    for (var i = 0; i < data.length; i++) {
      try {
        out.add(LibraryExercise.fromWger(data[i] as Map<String, dynamic>));
      } catch (_) {
        throw FormatException('Entry $i of $_assetPath has the wrong shape');
      }
    }
    return List.unmodifiable(out);
  }

  /// The same library with a new set of user exercises (use the rows from
  /// [ExerciseLibraryData.userExercises] after the user adds or edits one).
  ExerciseLibrary withUser(List<LibraryExercise> userExercises) =>
      ExerciseLibrary._(_wger, userExercises);

  /// The exercise for [ref] (`wger:<id>` or `local:<id>`), archived user
  /// exercises included.
  ExerciseLookup lookup(String ref) => ExerciseLookup._(ref, _byRef[ref]);

  /// The volume groups of the exercise for [ref], each once: the
  /// `musclesOf` function for the workout data layer. Empty for an unknown
  /// ref, an exercise whose muscles map to no group, and an exercise with no
  /// muscle whose category names no single group (Arms, Legs, Cardio).
  List<VolumeGroup> groupsOf(String ref) =>
      _byRef[ref]?.groups ?? const <VolumeGroup>[];

  /// The listed exercises whose name or an alias holds every word of [query]
  /// (case and accents ignored), sorted by name. An empty query lists
  /// everything. [group] keeps one muscle or category at a time: it is
  /// compared with each exercise's primary muscles and its category, so
  /// 'Chest', 'Triceps' and 'Legs' all work.
  List<LibraryExercise> search(String query, {String? group}) {
    final words = foldText(query).split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final g = (group == null || group.trim().isEmpty)
        ? null
        : foldText(group.trim());
    return [
      for (final e in all)
        if ((g == null ||
                e._groupKeys.contains(g) ||
                (e.isUser &&
                    e.groups.any(
                      (v) => _chipGroups[g]?.contains(v) ?? false,
                    ))) &&
            words.every(
              (w) =>
                  e._nameKey.contains(w) ||
                  e._aliasKeys.any((a) => a.contains(w)),
            ))
          e,
    ];
  }
}

extension ExerciseLibraryData on AppDatabase {
  /// The user's own exercises in the library's shape, archived ones included
  /// (the library hides them from lists but still resolves their refs).
  Future<List<LibraryExercise>> userExercises() async => [
    for (final row in await select(exercises).get())
      LibraryExercise.fromUser(row),
  ];
}
