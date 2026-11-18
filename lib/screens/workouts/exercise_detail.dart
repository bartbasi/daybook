// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/exercise_library.dart';
import '../../data/settings_data.dart';
import '../../data/workout_data.dart';
import '../../math/training.dart';
import '../../strings.dart';
import '../../util/units.dart';
import 'exercise_picker.dart' show loadExerciseLibrary;
import 'workout_widgets.dart';

/// One exercise (exercise-detail.html frame 1): its muscles and equipment, the
/// records, the estimated 1-rep max by session, the history, and the wger text
/// with its author and license. Only the numbers and words of the data layer
/// are shown here.
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseRef, this.name});

  final String exerciseRef;

  /// What to call the exercise when it is no longer in the list.
  final String? name;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Stream<UnitSystem>? _units;
  Stream<Records>? _records;
  Stream<List<ExerciseSession>>? _history;
  LibraryExercise? _exercise;
  var _libraryDone = false;
  var _libraryFailed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_units != null) return;
    final db = AppScope.of(context).db;
    _units = db.watchUnits();
    _records = db.watchExerciseRecords(widget.exerciseRef);
    _history = db.watchExerciseHistory(widget.exerciseRef);
    loadExerciseLibrary(db).then(
      (lib) {
        if (!mounted) return;
        setState(() {
          _exercise = lib.lookup(widget.exerciseRef).exercise;
          _libraryDone = true;
        });
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            _libraryDone = true;
            _libraryFailed = true;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ex = _exercise;
    return Scaffold(
      appBar: AppBar(
        title: Text(ex?.name ?? widget.name ?? S.exerciseListTitle),
      ),
      body: SafeArea(
        child: ContentWidth(
          child: StreamBuilder<UnitSystem>(
            stream: _units,
            builder: (context, units) => StreamBuilder<Records>(
              stream: _records,
              builder: (context, records) =>
                  StreamBuilder<List<ExerciseSession>>(
                    stream: _history,
                    builder: (context, history) {
                      if (records.hasError || history.hasError) {
                        return const Center(child: Text(S.detailLoadFailed));
                      }
                      final u = units.data;
                      final r = records.data;
                      final h = history.data;
                      if (u == null || r == null || h == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _body(context, ex, u, r, h);
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LibraryExercise? ex,
    UnitSystem units,
    Records records,
    List<ExerciseSession> history,
  ) {
    final theme = Theme.of(context);
    final today = AppScope.of(context).clock().localDate;
    final unit = S.unitWord(units);
    String weight(DoneSet s) => '${setWeightText(s.weightKg!, units)} $unit';
    String set(DoneSet s) =>
        setValuesText((weightKg: s.weightKg, reps: s.reps), units);
    String est(double kgOrLb) => '${oneRepMaxText(kgOrLb, units)} $unit';
    double? estOf(DoneSet s) =>
        estimatedOneRepMaxIn(s.weightKg!, s.reps!, units);

    Widget head(String text) => Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    Widget card(String label, String big, String small) => Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Semantics(
            container: true,
            label: '$label, $big, $small',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                Text(big, style: theme.textTheme.titleLarge),
                Text(small, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );

    final heaviest = records.heaviest;
    final best = records.bestEstimate;
    final bestEst = best == null ? null : estOf(best);
    final credit = ex?.credit;
    final about = ex?.description.trim() ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_libraryFailed)
          const Text(S.pickerLoadFailed)
        else if (_libraryDone && ex == null)
          const Text(S.detailNotListed),
        if (ex != null)
          Text(
            S.detailMuscles(
              ex.primaryMuscles,
              ex.secondaryMuscles,
              ex.equipment,
            ),
          ),
        head(S.detailRecords),
        if (heaviest == null)
          const Text(S.detailNoRecords)
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                card(
                  S.detailHeaviest,
                  weight(heaviest),
                  S.detailHeaviestSmall(
                    heaviest.reps!,
                    S.monthDay(heaviest.localDate, today),
                  ),
                ),
                if (best != null && bestEst != null) ...[
                  const SizedBox(width: 12),
                  card(
                    S.detailEstimate,
                    est(bestEst),
                    S.detailFrom(set(best), S.monthDay(best.localDate, today)),
                  ),
                ],
              ],
            ),
          ),
        if (history.any((s) => s.bestEstimate != null)) ...[
          head(S.detailBySession),
          for (final s in history)
            if (s.bestEstimate != null)
              _SessionRow(
                date: S.dayShort(s.localDate, today),
                estimate: est(estOf(s.bestEstimate!)!),
                best: S.detailBest(set(s.bestEstimate!)),
              ),
        ],
        head(S.detailHistory),
        if (history.isEmpty) const Text(S.detailNoSets),
        for (final s in history)
          Semantics(
            container: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.dayShort(s.localDate, today),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text([for (final x in s.sets) set(x)].join(', ')),
                ],
              ),
            ),
          ),
        if (about.isNotEmpty) ...[head(S.detailAbout), Text(about)],
        if (credit != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.detailCredit(credit, ex!.licenseLabel),
                  style: theme.textTheme.bodySmall,
                ),
                // Plain text to copy for now. Task 8.3 makes both tappable
                // when url_launcher arrives.
                if (ex.licenseUrl != null)
                  SelectableText(
                    S.detailLicenseUrl(ex.licenseUrl!),
                    style: theme.textTheme.bodySmall,
                  ),
                if (ex.url != null)
                  SelectableText(
                    S.detailSourceUrl(ex.url!),
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.date,
    required this.estimate,
    required this.best,
  });

  final String date;
  final String estimate;
  final String best;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$date, $estimate, $best',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: Text(date)),
            Expanded(flex: 2, child: Text(estimate, textAlign: TextAlign.end)),
            Expanded(flex: 3, child: Text(best, textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
  }
}
