// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../data/exercise_library.dart';
import '../../data/workout_data.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import 'exercise_picker.dart' show loadExerciseLibrary;

/// Sets by muscle (exercise-detail.html frame 2): completed sets of each of
/// the ten muscle groups for this week so far and the two weeks before,
/// Monday to Sunday. The numbers carry the comparison, not colour.
class WeeklyVolumeScreen extends StatefulWidget {
  const WeeklyVolumeScreen({super.key});

  @override
  State<WeeklyVolumeScreen> createState() => _WeeklyVolumeScreenState();
}

class _WeeklyVolumeScreenState extends State<WeeklyVolumeScreen> {
  List<Stream<Map<String, int>>>? _weeks;
  late String _today;
  var _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_weeks != null || _failed) return;
    final scope = AppScope.of(context);
    _today = scope.clock().localDate;
    loadExerciseLibrary(scope.db).then(
      (lib) {
        if (!mounted) return;
        Iterable<String> musclesOf(String ref) => [
          for (final g in lib.groupsOf(ref)) g.name,
        ];
        final monday = mondayOf(_today);
        setState(
          () => _weeks = [
            for (final day in [
              _today,
              addDays(monday, -7),
              addDays(monday, -14),
            ])
              scope.db.watchWeeklyVolume(day, musclesOf),
          ],
        );
      },
      onError: (Object _) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _weeks;
    return Scaffold(
      appBar: AppBar(title: const Text(S.weeklyScreenTitle)),
      body: SafeArea(
        child: ContentWidth(
          child: _failed
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(S.weeklyUnavailable),
                )
              : weeks == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<Map<String, int>>(
                  stream: weeks[0],
                  builder: (context, a) => StreamBuilder<Map<String, int>>(
                    stream: weeks[1],
                    builder: (context, b) => StreamBuilder<Map<String, int>>(
                      stream: weeks[2],
                      builder: (context, c) {
                        final x = a.data, y = b.data, z = c.data;
                        if (x == null || y == null || z == null) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return _table(context, x, y, z);
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _table(
    BuildContext context,
    Map<String, int> now,
    Map<String, int> before,
    Map<String, int> earlier,
  ) {
    final theme = Theme.of(context);
    final monday = mondayOf(_today);
    final labelA = S.monthDay(addDays(monday, -7), _today);
    final labelB = S.monthDay(addDays(monday, -14), _today);
    // At a large text size the three numbers do not fit beside the name, so
    // each group stacks: the name, then its three numbers with their weeks.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    const bold = TextStyle(fontWeight: FontWeight.bold);

    Widget cell(String text, {TextStyle? style}) => Expanded(
      flex: 2,
      child: Text(text, textAlign: TextAlign.end, style: style),
    );

    final rows = <Widget>[
      if (!stacked)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              cell('${S.weeklyThisWeek}\n${S.weeklySoFar}', style: bold),
              cell(labelA, style: bold),
              cell(labelB, style: bold),
            ],
          ),
        ),
      for (final g in VolumeGroup.values)
        Semantics(
          container: true,
          label: S.weeklyRowSpoken(
            S.groupName(g.name),
            now[g.name] ?? 0,
            labelA,
            before[g.name] ?? 0,
            labelB,
            earlier[g.name] ?? 0,
          ),
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.groupName(g.name), style: bold),
                      Text(
                        '${S.weeklyThisWeek} ${S.weeklySoFar}: '
                        '${now[g.name] ?? 0}',
                      ),
                      Text('$labelA: ${before[g.name] ?? 0}'),
                      Text('$labelB: ${earlier[g.name] ?? 0}'),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(S.groupName(g.name), style: bold),
                      ),
                      cell('${now[g.name] ?? 0}'),
                      cell('${before[g.name] ?? 0}'),
                      cell('${earlier[g.name] ?? 0}'),
                    ],
                  ),
          ),
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(S.weeklyNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        ...rows,
      ],
    );
  }
}
