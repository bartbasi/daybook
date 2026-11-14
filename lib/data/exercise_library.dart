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
  String? get credit => authors.isEmpty ? null : authors.join(', ');

  late final String _nameKey = foldText(name);
  late final List<String> _aliasKeys = [for (final a in aliases) foldText(a)];
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
  /// decoded on the calling isolate.
  static Future<ExerciseLibrary> load({
    AssetBundle? bundle,
    List<LibraryExercise> userExercises = const [],
  }) async {
    final b = bundle ?? rootBundle;
    final wger = await (_wgerCache[b] ??= _readWger(b));
    return ExerciseLibrary._(wger, userExercises);
  }

  static Future<List<LibraryExercise>> _readWger(AssetBundle bundle) async {
    final data = jsonDecode(await bundle.loadString(_assetPath)) as List;
    return List.unmodifiable([
      for (final j in data) LibraryExercise.fromWger(j as Map<String, dynamic>),
    ]);
  }

  /// The same library with a new set of user exercises (use the rows from
  /// [ExerciseLibraryData.userExercises] after the user adds or edits one).
  ExerciseLibrary withUser(List<LibraryExercise> userExercises) =>
      ExerciseLibrary._(_wger, userExercises);

  /// The exercise for [ref] (`wger:<id>` or `local:<id>`), archived user
  /// exercises included.
  ExerciseLookup lookup(String ref) => ExerciseLookup._(ref, _byRef[ref]);

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
        if ((g == null || e._groupKeys.contains(g)) &&
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
