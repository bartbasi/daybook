// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_scope.dart';
import '../../clock.dart';
import '../../data/database.dart';
import '../../data/goal_data.dart';
import '../../data/nutrients.dart';
import '../../data/settings_data.dart';
import '../../math/calorie_budget.dart';
import '../../strings.dart';
import '../../util/units.dart';
import '../my_foods/food_editor.dart' show foodNumberProblem, parseFoodNumber;
import 'other_nutrients_screen.dart';

// The Goals screen (goals.html frames 1 to 5).
//
// One scrolling screen. The result is at the top with its working shown. It
// does no arithmetic of its own: every number comes from lib/math or from
// lib/data/goal_data.dart, and is rounded only with [roundForDisplay].
//
// What the card shows:
// - Goals saved and nothing changed since: the stored goal is the big number.
//   The working lines are worked out again from today's weigh-in and profile.
//   If they no longer come to the stored goal, one sentence says so and
//   Recalculate updates it (review note 4). The lines are each rounded from
//   the unrounded working, and no equation is printed (note 5).
// - Anything else: the working from the inputs as they stand, "New, from your
//   latest weigh-in", kept when Save is tapped.
// - Own number on: the card stays above, dimmed, with words saying it is not
//   used.
// Nothing is written until Save or Recalculate. Past days keep their goals.

/// The plain words for a refusal from the data layer.
String goalProblemText(GoalProblem p) => switch (p) {
  GoalProblem.needsWeight => S.goalsNeedWeight,
  GoalProblem.needsProfile => S.goalsProfileMissing,
  GoalProblem.ownNumberNotPositive => S.goalsOwnBad,
  GoalProblem.macrosIncomplete => S.goalsMacrosIncomplete,
  GoalProblem.badAddBack => S.goalsAddBackBad,
  GoalProblem.badRate => S.goalsBadRate,
  GoalProblem.badActivity => S.goalsBadActivity,
  GoalProblem.noGoals => S.goalsNoGoals,
  GoalProblem.calculatedNotPositive => S.goalsNotUsable,
};

/// Where a refusal is shown: beside what caused it.
String _problemPlace(GoalProblem p) => switch (p) {
  GoalProblem.needsWeight => 'card',
  GoalProblem.needsProfile => 'profile',
  GoalProblem.ownNumberNotPositive => 'own',
  GoalProblem.macrosIncomplete => 'macros',
  GoalProblem.badAddBack => 'addBack',
  GoalProblem.badRate => 'rate',
  GoalProblem.badActivity => 'activity',
  GoalProblem.noGoals => 'card',
  GoalProblem.calculatedNotPositive => 'card',
};

String _activityName(ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary => S.goalsSedentary,
  ActivityLevel.lightlyActive => S.goalsLightly,
  ActivityLevel.moderatelyActive => S.goalsModerately,
  ActivityLevel.veryActive => S.goalsVery,
  ActivityLevel.extraActive => S.goalsExtra,
};

String _activityNote(ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary => S.goalsSedentaryNote,
  ActivityLevel.lightlyActive => S.goalsLightlyNote,
  ActivityLevel.moderatelyActive => S.goalsModeratelyNote,
  ActivityLevel.veryActive => S.goalsVeryNote,
  ActivityLevel.extraActive => S.goalsExtraNote,
};

/// The inputs that decide the calculated goal, to tell whether they changed.
typedef _Inputs = (
  Sex?,
  String?,
  int?,
  ActivityLevel?,
  Target?,
  double?,
  UnitSystem?,
);

class _Height {
  const _Height(this.cm, this.error, {this.empty = false});
  final double? cm;
  final String? error;
  final bool empty;
}

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late AppDatabase _db;
  late Clock _clock;
  var _started = false;
  var _loaded = false;
  var _loadFailed = false;
  var _units = UnitSystem.imperial;
  late String _today;

  GoalsForDay? _saved;
  WeightEntry? _weight;
  _Inputs? _baseline;

  // The form.
  Sex? _sex;
  String? _birth;
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _cm = TextEditingController();
  ActivityLevel? _activity = ActivityLevel.lightlyActive;
  Target _target = Target.lose;
  WeeklyRate? _rate;
  var _own = false;
  final _ownText = TextEditingController();
  var _addBack = 100;
  var _mode = MacroMode.grams;
  final _grams = List.generate(3, (_) => TextEditingController());
  final _percents = List.generate(3, (_) => TextEditingController());
  var _overrides = <int, double>{};

  final _nodes = <String, FocusNode>{};
  final _keys = <String, GlobalKey>{};
  final _errors = <String, String>{};
  String? _message;
  var _busy = false;
  var _writing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final scope = AppScope.of(context);
    _db = scope.db;
    _clock = scope.clock;
    _today = _clock().localDate;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_feet, _inches, _cm, _ownText, ..._grams, ..._percents]) {
      c.dispose();
    }
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  FocusNode _node(String key) => _nodes.putIfAbsent(key, FocusNode.new);
  GlobalKey _key(String key) => _keys.putIfAbsent(key, GlobalKey.new);

  Future<void> _load() async {
    if (_loadFailed) setState(() => _loadFailed = false);
    try {
      final units = await _db.getUnits();
      final profile = await _db.getProfile();
      final saved = await _db.goalsForDay(_today);
      final weight = await _db.weightOnOrBefore(_today);
      if (!mounted) return;
      setState(() {
        _units = units;
        _weight = weight;
        _saved = saved;
        _sex = switch (profile?.sex) {
          'male' => Sex.male,
          'female' => Sex.female,
          _ => null,
        };
        _birth = profile?.birthDate;
        _setHeight(profile?.heightCm);
        _rate = WeeklyRate(_target, WeeklyRate.amounts(units)[1], units);
        if (saved != null) _fromSaved(saved);
        _baseline = saved == null ? null : _inputs();
        _loaded = true;
      });
    } catch (_) {
      // No form on a failed load: Save from a default form would overwrite
      // what is stored.
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _fromSaved(GoalsForDay g) {
    _activity = g.activity;
    final rate = g.rate;
    _rate = rate;
    _target =
        rate?.target ??
        (g.row.targetKgPerWeek < 0
            ? Target.lose
            : g.row.targetKgPerWeek > 0
            ? Target.gain
            : Target.stay);
    _own = g.isOwnNumber;
    _ownText.text = g.isOwnNumber && g.calories != null ? '${g.calories}' : '';
    _addBack = g.addBackPercent;
    _mode = g.macroMode;
    final set = _mode == MacroMode.grams ? _grams : _percents;
    final r = g.row;
    final values = [r.proteinTarget, r.carbsTarget, r.fatTarget];
    for (var i = 0; i < 3; i++) {
      set[i].text = values[i] == null ? '' : S.numberText(values[i]!);
    }
    _overrides = Map.of(g.nutrientOverrides);
  }

  void _setHeight(double? cm) {
    if (cm == null) {
      _feet.clear();
      _inches.clear();
      _cm.clear();
      return;
    }
    _cm.text = S.numberText(cm);
    final total = (cmToIn(cm) * 100).round() / 100;
    var feet = (total / 12).floor();
    var inches = (total - feet * 12 * 1.0);
    inches = (inches * 100).round() / 100;
    if (inches >= 12) {
      feet += 1;
      inches = 0;
    }
    _feet.text = '$feet';
    _inches.text = S.numberText(inches);
  }

  // What the form says now.

  _Height _height() {
    if (_units == UnitSystem.metric) {
      final t = _cm.text.trim();
      if (t.isEmpty) return const _Height(null, null, empty: true);
      final v = parseFoodNumber(t);
      if (v == null || v < 50 || v > 275) {
        return const _Height(null, S.goalsHeightRangeMetric);
      }
      return _Height(v, null);
    }
    final f = _feet.text.trim();
    final i = _inches.text.trim();
    if (f.isEmpty && i.isEmpty) return const _Height(null, null, empty: true);
    final feet = int.tryParse(f);
    final inches = i.isEmpty ? 0.0 : parseFoodNumber(i);
    if (feet == null ||
        feet < 1 ||
        feet > 8 ||
        inches == null ||
        inches >= 12) {
      return const _Height(null, S.goalsHeightRange);
    }
    return _Height(inToCm(feet * 12 + inches), null);
  }

  bool get _birthInFuture => _birth != null && _birth!.compareTo(_today) >= 0;

  _Inputs _inputs() {
    final cm = _height().cm;
    return (
      _sex,
      _birth,
      cm == null ? null : (cm * 10).round(),
      _activity,
      _rate?.target,
      _rate?.amount,
      _rate?.units,
    );
  }

  bool get _dirty => _inputs() != _baseline;

  /// Whether the other nutrient goals differ from the saved ones.
  bool get _overridesChanged => !mapEquals(
    _overrides,
    _saved?.nutrientOverrides ?? const <int, double>{},
  );

  /// Whether the macros as typed (or their mode) differ from the saved ones.
  bool get _macrosChanged {
    final s = _saved;
    if (s == null) {
      return _grams.any((c) => c.text.trim().isNotEmpty) ||
          _percents.any((c) => c.text.trim().isNotEmpty);
    }
    if (_mode != s.macroMode) return true;
    final stored = [s.row.proteinTarget, s.row.carbsTarget, s.row.fatTarget];
    final set = _mode == MacroMode.grams ? _grams : _percents;
    final values = _macroValues();
    for (var i = 0; i < 3; i++) {
      final empty = set[i].text.trim().isEmpty;
      if (stored[i] == null) {
        if (!empty) return true;
      } else if (empty || values[i] != stored[i]) {
        return true;
      }
    }
    return false;
  }

  /// True when the whole form is what is saved: the calorie inputs, the own
  /// number, the add-back, the macros and the other nutrient goals.
  bool get _formIsSaved {
    final s = _saved;
    return s != null &&
        !_dirty &&
        _own == s.isOwnNumber &&
        (!_own || _ownValue() == s.calories) &&
        _addBack == s.addBackPercent &&
        !_macrosChanged &&
        !_overridesChanged;
  }

  int? _ownValue() {
    final v = int.tryParse(_ownText.text.trim());
    return v != null && v > 0 ? v : null;
  }

  CalorieWorking? _working() {
    final cm = _height().cm;
    final w = _weight;
    final a = _activity;
    final r = _rate;
    final sex = _sex;
    final birth = _birth;
    if (cm == null ||
        w == null ||
        a == null ||
        r == null ||
        sex == null ||
        birth == null ||
        _birthInFuture) {
      return null;
    }
    return calorieWorking(
      sex: sex,
      birthDate: birth,
      day: _today,
      weightKg: w.weightKg,
      heightCm: cm,
      activity: a,
      rate: r,
    );
  }

  /// The stored calculated goal is the one in use and nothing it depends on
  /// was changed.
  bool get _clean {
    final s = _saved;
    return s != null &&
        !s.isOwnNumber &&
        s.calories != null &&
        !_dirty &&
        !_own;
  }

  /// The calorie goal in use, as the whole number that is shown or stored.
  int? get _goalInUse {
    if (_own) return _ownValue();
    if (_clean) return _saved!.calories;
    final w = _working();
    if (w == null) return null;
    final goal = roundForDisplay(w.goal);
    return goal > 0 ? goal : null;
  }

  /// The macros as the form has them, whatever is valid so far.
  List<double?> _macroValues() {
    final set = _mode == MacroMode.grams ? _grams : _percents;
    return [
      for (final c in set)
        _mode == MacroMode.grams
            ? parseFoodNumber(c.text)
            : _wholePercent(c.text)?.toDouble(),
    ];
  }

  /// 100 less the percents as typed (a field that is not a whole percent
  /// counts as 0): what is left to give out, negative when over.
  int get _percentsLeft {
    final v = _macroValues();
    return percentLeft(
      v[0]?.round() ?? 0,
      v[1]?.round() ?? 0,
      v[2]?.round() ?? 0,
    );
  }

  /// Percent mode with something typed that cannot be saved yet: a field that
  /// is not a whole percent, or percents that do not add to 100.
  bool get _percentsBlockSave {
    if (_mode != MacroMode.percent) return false;
    if (_percents.every((c) => c.text.trim().isEmpty)) return false;
    return _macroValues().any((v) => v == null) || _percentsLeft != 0;
  }

  int? _wholePercent(String text) {
    final v = int.tryParse(text.trim());
    return v != null && v >= 0 && v <= 100 ? v : null;
  }

  void _changed() => setState(() {});

  // Save and Recalculate.

  Future<void> _adopt(GoalsForDay saved) async {
    final profile = await _db.getProfile();
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _sex = switch (profile?.sex) {
        'male' => Sex.male,
        'female' => Sex.female,
        _ => _sex,
      };
      _baseline = _inputs();
    });
  }

  /// Checks every field. Returns what to save, or null with the problems set
  /// beside their causes (nothing is written then).
  GoalInput? _check() {
    final errors = <String, String>{};
    final h = _height();
    if (_own) {
      if (_ownValue() == null) errors['own'] = S.goalsOwnBad;
      if (_birthInFuture) errors['birth'] = S.goalsBornFuture;
      if (h.error != null) errors['height'] = h.error!;
    } else {
      if (_sex == null) errors['sex'] = S.goalsSexMissing;
      if (_birth == null) {
        errors['birth'] = S.goalsBornMissing;
      } else if (_birthInFuture) {
        errors['birth'] = S.goalsBornFuture;
      }
      if (h.cm == null) errors['height'] = h.error ?? S.goalsHeightBad;
      // The card already says there is no weigh-in, in plain words.
      if (_weight == null) errors['weight'] = S.goalsNeedWeight;
    }
    if (_activity == null) errors['activity'] = S.goalsBadActivity;
    if (_rate == null) errors['rate'] = S.goalsRateMissing;

    // Macros: all three or none.
    final set = _mode == MacroMode.grams ? _grams : _percents;
    final filled = [for (final c in set) c.text.trim().isNotEmpty];
    final values = _macroValues();
    if (filled.any((f) => f)) {
      for (var i = 0; i < 3; i++) {
        if (filled[i] && values[i] == null) {
          errors['m$i'] = _mode == MacroMode.grams
              ? foodNumberProblem(set[i].text, S.foodEditNumberBad)
              : S.goalsPercentBad;
        }
      }
      if (!filled.every((f) => f)) {
        errors['macros'] = S.goalsMacrosIncomplete;
      } else if (!errors.keys.any((k) => k.startsWith('m')) &&
          _mode == MacroMode.percent) {
        final sum = 100 - _percentsLeft;
        if (sum != 100) errors['macros'] = S.goalsPercentsDontAdd(sum);
      }
    }

    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
        _message = S.goalsFix;
      });
      _revealFirst(errors.keys);
      return null;
    }
    setState(_errors.clear);
    final given = filled.every((f) => f);
    return GoalInput(
      sex: _sex,
      birthDate: _birth,
      heightCm: h.cm,
      activity: _activity!,
      rate: _rate!,
      ownCalories: _own ? _ownValue() : null,
      addBackPercent: _addBack,
      macroMode: _mode,
      protein: given ? values[0] : null,
      carbs: given ? values[1] : null,
      fat: given ? values[2] : null,
      nutrientOverrides: Map.of(_overrides),
    );
  }

  static const _order = [
    'weight',
    'card',
    'profile',
    'sex',
    'birth',
    'height',
    'activity',
    'rate',
    'own',
    'addBack',
    'm0',
    'm1',
    'm2',
    'macros',
  ];

  /// Puts the cursor in the first field with a problem, or scrolls to the
  /// first problem that has no field.
  void _revealFirst(Iterable<String> keys) {
    for (final k in _order) {
      if (!keys.contains(k)) continue;
      final field = switch (k) {
        'own' => 'own',
        'height' => _units == UnitSystem.metric ? 'cm' : 'feet',
        'm0' || 'm1' || 'm2' => k,
        _ => null,
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (field != null) {
          _node(field).requestFocus();
        } else {
          final ctx = _key(k == 'weight' ? 'card' : k).currentContext;
          if (ctx != null) Scrollable.ensureVisible(ctx);
        }
      });
      return;
    }
  }

  void _showProblem(GoalProblem p) {
    setState(() {
      _errors
        ..clear()
        ..[_problemPlace(p)] = goalProblemText(p);
      _message = S.goalsFix;
    });
    _revealFirst([_problemPlace(p)]);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final input = _check();
      if (input == null) return;
      setState(() => _writing = true);
      final GoalsForDay saved;
      try {
        saved = await _db.saveGoals(input, _clock());
      } on GoalRefused catch (e) {
        _showProblem(e.problem);
        return;
      } on PercentsDontAddUp {
        if (mounted) {
          setState(() {
            _errors['macros'] = S.goalsPercentsDontAdd(0);
            _message = S.goalsFix;
          });
        }
        return;
      } catch (_) {
        if (mounted) setState(() => _message = S.goalsSaveFailed);
        return;
      } finally {
        if (mounted) setState(() => _writing = false);
      }
      await _adopt(saved);
      if (mounted) setState(() => _message = S.goalsSaved(saved.calories));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recalculate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _errors.clear();
      _writing = true;
    });
    try {
      final saved = await _db.recalculateGoals(_clock());
      await _adopt(saved);
      if (mounted) {
        setState(() => _message = S.goalsRecalculated(saved.calories));
      }
    } on GoalRefused catch (e) {
      _showProblem(e.problem);
    } catch (_) {
      if (mounted) setState(() => _message = S.goalsRecalcFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
        });
      }
    }
  }

  Future<void> _pickBorn() async {
    final today = parseToday();
    // A stored birth date before 1900 (an import can bring one) would make
    // the picker assert, so it opens on a date it can show.
    final first = DateTime(1900);
    final stored = _birth == null ? null : DateTime.tryParse(_birth!);
    final initial = stored == null || stored.isBefore(first)
        ? DateTime(1990)
        : stored;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: first,
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birth =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      _errors.remove('birth');
    });
  }

  DateTime parseToday() => DateTime.parse(_today);

  // Layout.

  bool _big(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(10) > 13;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_writing,
      child: Scaffold(
        appBar: AppBar(title: const Text(S.goalsTitle)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ContentWidth(
                  child: _loadFailed
                      ? _failed(context)
                      : _loaded
                      ? _form(context)
                      : const SizedBox.shrink(),
                ),
              ),
              if (!_loadFailed) _bar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gap([double h = 16]) => SizedBox(height: h);

  /// A failed load: the words and a way to try again, and no form.
  Widget _failed(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(S.goalsLoadFailed),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _load,
          child: const Text(S.tryAgain),
        ),
      ],
    ),
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );

  Widget _small(BuildContext context, String text, {bool muted = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: muted
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      );

  /// A problem in plain words, right where it applies.
  Widget _err(BuildContext context, String key) {
    final text = _errors[key];
    return KeyedSubtree(
      key: _key(key),
      child: text == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
    );
  }

  Widget _form(BuildContext context) {
    final theme = Theme.of(context);
    final big = _big(context);
    final calc = _working();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _card(context, calc),
          _label(context, S.goalsAbout),
          _err(context, 'profile'),
          Text(S.goalsSex, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          _choices<Sex>(
            value: _sex,
            options: const [
              (Sex.male, S.goalsMale),
              (Sex.female, S.goalsFemale),
            ],
            onPick: (v) => setState(() {
              _sex = v;
              _errors.remove('sex');
            }),
          ),
          _err(context, 'sex'),
          _gap(),
          if (big) ...[
            _born(),
            _gap(),
            ..._heightFields(big),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _born()),
                const SizedBox(width: 12),
                Expanded(child: Column(children: _heightFields(big))),
              ],
            ),
          _err(context, 'height'),
          _label(context, S.goalsWeight),
          if (_weight != null)
            Text(
              S.goalsLatestWeight(
                formatWeight(_weight!.weightKg, _units),
                S.unitWord(_units),
                S.dayWord(_weight!.localDate, _today),
              ),
            ),
          _small(context, S.goalsWeightNote),
          _label(context, S.goalsActivity),
          for (final a in ActivityLevel.values) _activityRow(context, a),
          _err(context, 'activity'),
          _label(context, S.goalsTarget),
          _choices<Target>(
            value: _target,
            options: const [
              (Target.lose, S.goalsLose),
              (Target.stay, S.goalsStay),
              (Target.gain, S.goalsGain),
            ],
            onPick: _pickTarget,
          ),
          if (_target != Target.stay) ..._rateChips(context),
          _err(context, 'rate'),
          _label(context, S.goalsOwnHeader),
          ..._ownPart(context, calc),
          _label(context, S.goalsAddBack),
          _choices<int>(
            value: _addBack,
            options: [for (final p in addBackChoices) (p, S.percentOption(p))],
            onPick: (v) => setState(() => _addBack = v),
          ),
          _small(context, _addBackExample()),
          _err(context, 'addBack'),
          _label(context, S.goalsMacros),
          _choices<MacroMode>(
            value: _mode,
            options: const [
              (MacroMode.grams, S.goalsGrams),
              (MacroMode.percent, S.goalsPercent),
            ],
            onPick: (v) => setState(() {
              _mode = v;
              _errors.removeWhere((k, _) => k.startsWith('m'));
            }),
          ),
          const SizedBox(height: 8),
          ..._macros(context, big),
          const SizedBox(height: 8),
          ListTile(
            minTileHeight: 56,
            contentPadding: EdgeInsets.zero,
            title: const Text(S.goalsOther),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(S.goalsOtherSub),
                if (_overridesChanged) const Text(S.goalsOtherUnsaved),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OtherNutrientsScreen(
                  overrides: Map.of(_overrides),
                  saved: Map.of(_saved?.nutrientOverrides ?? const {}),
                  onChanged: (m) => setState(() => _overrides = m),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// One choice out of a few, as chips that wrap: each is a word and a mark.
  Widget _choices<T>({
    required T? value,
    required List<(T, String)> options,
    required ValueChanged<T> onPick,
  }) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final (v, label) in options)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: ChoiceChip(
            label: Text(label),
            selected: v == value,
            showCheckmark: true,
            onSelected: _busy ? null : (_) => onPick(v),
          ),
        ),
    ],
  );

  Widget _born() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _busy ? null : _pickBorn,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: S.goalsBorn,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
                errorText: _errors['birth'],
                errorMaxLines: 4,
              ),
              child: Text(
                _birth == null ? '' : S.monthDay(_birth!, _today),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        KeyedSubtree(key: _key('birth'), child: const SizedBox.shrink()),
      ],
    );
  }

  static const _numberKeys = TextInputType.numberWithOptions(decimal: true);

  InputDecoration _decoration(String label, {String? error, String? suffix}) =>
      InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: error,
        errorMaxLines: 4,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: const OutlineInputBorder(),
      );

  List<Widget> _heightFields(bool big) {
    if (_units == UnitSystem.metric) {
      return [
        TextField(
          controller: _cm,
          focusNode: _node('cm'),
          keyboardType: _numberKeys,
          onChanged: (_) => _changed(),
          decoration: _decoration(S.goalsCentimeters, suffix: S.unitCm),
        ),
      ];
    }
    final feet = TextField(
      controller: _feet,
      focusNode: _node('feet'),
      keyboardType: TextInputType.number,
      onChanged: (_) => _changed(),
      decoration: _decoration(S.goalsFeet, suffix: S.unitFt),
    );
    final inches = TextField(
      controller: _inches,
      focusNode: _node('inches'),
      keyboardType: _numberKeys,
      onChanged: (_) => _changed(),
      decoration: _decoration(S.goalsInches, suffix: S.unitIn),
    );
    return [
      if (big) ...[
        feet,
        _gap(),
        inches,
      ] else
        Row(
          children: [
            Expanded(child: feet),
            const SizedBox(width: 8),
            Expanded(child: inches),
          ],
        ),
    ];
  }

  Widget _activityRow(BuildContext context, ActivityLevel a) {
    final selected = _activity == a;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: InkWell(
        key: ValueKey('activity-${a.name}'),
        onTap: _busy
            ? null
            : () => setState(() {
                _activity = a;
                _errors.remove('activity');
              }),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: [
                          Text(
                            _activityName(a),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(S.goalsFactor(_factor(a))),
                        ],
                      ),
                      Text(
                        _activityNote(a),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _factor(ActivityLevel a) => a.factor.toString();

  void _pickTarget(Target t) {
    setState(() {
      _target = t;
      _errors.remove('rate');
      final r = _rate;
      if (t == Target.stay) {
        _rate = WeeklyRate.stay;
      } else if (r == null || r.target == Target.stay) {
        _rate = WeeklyRate(t, WeeklyRate.amounts(_units)[1], _units);
      } else {
        _rate = WeeklyRate(t, r.amount, r.units);
      }
    });
  }

  List<Widget> _rateChips(BuildContext context) {
    final r = _rate;
    final unit = S.unitWord(_units);
    // A saved rate that is not one of the offered ones (after a switch of
    // units) is shown as it is, with no chip selected.
    final offered =
        r != null &&
        r.target != Target.stay &&
        r.units == _units &&
        WeeklyRate.amounts(_units).contains(r.amount);
    return [
      _label(context, S.goalsPerWeek),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final amount in WeeklyRate.amounts(_units))
            Semantics(
              label: S.goalsRateChipSpoken(S.numberText(amount), unit),
              selected: offered && r.amount == amount,
              button: true,
              excludeSemantics: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: ChoiceChip(
                  label: Text(S.goalsRateChip(S.numberText(amount), unit)),
                  selected: offered && r.amount == amount,
                  showCheckmark: true,
                  // The list's own element, never a computed value.
                  onSelected: _busy
                      ? null
                      : (_) => setState(() {
                          _rate = WeeklyRate(_target, amount, _units);
                          _errors.remove('rate');
                        }),
                ),
              ),
            ),
        ],
      ),
      if (r != null && r.target != Target.stay && !offered)
        _small(
          context,
          S.goalsRateKept(
            S.numberText(r.amount),
            S.unitWord(r.units),
            r.target == Target.lose
                ? S.goalsLose.toLowerCase()
                : S.goalsGain.toLowerCase(),
          ),
        ),
    ];
  }

  Widget? _lowNotice(int? goal) {
    if (goal == null || !isLowIntake(goal, _sex)) return null;
    return Padding(
      key: const ValueKey('low-intake'),
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        _sex == Sex.male ? S.goalsLowIntakeMen : S.goalsLowIntakeWomen,
      ),
    );
  }

  List<Widget> _ownPart(BuildContext context, CalorieWorking? calc) {
    final notice = _own ? _lowNotice(_ownValue()) : null;
    return [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text(S.goalsOwnToggle),
        value: _own,
        onChanged: _busy
            ? null
            : (v) => setState(() {
                _own = v;
                _errors.remove('own');
              }),
      ),
      if (_own) ...[
        TextField(
          controller: _ownText,
          focusNode: _node('own'),
          keyboardType: TextInputType.number,
          onChanged: (_) => _changed(),
          style: Theme.of(context).textTheme.titleLarge,
          decoration: _decoration(
            S.goalsOwnField,
            suffix: S.goalsKcalADay,
            error: _errors['own'],
          ),
        ),
        if (calc != null)
          _small(context, S.goalsOwnNotUsed(roundForDisplay(calc.goal))),
        ?notice,
      ],
    ];
  }

  String _addBackExample() {
    const run = 383.0;
    final budget = DayBudget(
      goal: 0,
      exerciseKcal: run,
      addBackPercent: _addBack,
      foodKcal: 0,
    );
    return S.goalsAddBackExample(roundForDisplay(run), budget.shownAddBack);
  }

  // The card at the top.

  Widget _card(BuildContext context, CalorieWorking? calc) {
    final theme = Theme.of(context);
    final saved = _saved;
    final clean = _clean;
    final children = <Widget>[];
    if (!_own && !clean && _weight == null) {
      children.add(const Text(S.goalsNeedWeight));
    } else if (!_own && !clean && calc == null) {
      children.add(const Text(S.goalsNeedProfile));
    } else if (clean || calc != null) {
      final shown = clean ? saved!.calories! : roundForDisplay(calc!.goal);
      final usable = shown > 0;
      if (calc != null) {
        final rate = _rate!;
        final kcal = roundForDisplay(calc.adjustment).abs();
        children.addAll([
          Text(S.goalsResting(roundForDisplay(calc.resting))),
          Text(
            S.goalsActivityLine(
              _factor(calc.activity),
              _activityName(calc.activity),
              roundForDisplay(calc.maintenance),
            ),
          ),
          Text(switch (rate.target) {
            Target.lose => S.goalsRateLose(
              kcal,
              S.numberText(rate.amount),
              S.unitWord(rate.units),
            ),
            Target.gain => S.goalsRateGain(
              kcal,
              S.numberText(rate.amount),
              S.unitWord(rate.units),
            ),
            Target.stay => S.goalsRateStay,
          }),
        ]);
      }
      if (usable) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MergeSemantics(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  Text(S.count(shown), style: theme.textTheme.displaySmall),
                  const Text(S.goalsKcalADay),
                ],
              ),
            ),
          ),
        );
      } else if (!_own && _errors['card'] == null) {
        // Said once: a refused Save puts the same words in the error slot.
        children.add(
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(S.goalsNotUsable),
          ),
        );
      }
      if (clean) {
        children.add(
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(S.goalsCalculated(S.monthDay(saved!.effectiveFrom, _today))),
              // Only when nothing is unsaved: Recalculate writes the stored
              // values, so an unsaved edit would be lost.
              if (_formIsSaved)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _busy ? null : _recalculate,
                  child: const Text(S.goalsRecalculate),
                ),
            ],
          ),
        );
        if (calc != null && roundForDisplay(calc.goal) != saved.calories) {
          children.add(const Text(S.goalsDrifted));
        }
      } else {
        final w = _weight!;
        children.add(
          _small(
            context,
            S.goalsNewFromWeighIn(
              formatWeight(w.weightKg, _units),
              S.unitWord(_units),
              S.dayWord(w.localDate, _today),
            ),
            muted: true,
          ),
        );
      }
      final notice = _own || !usable ? null : _lowNotice(shown);
      if (notice != null) children.add(notice);
    }
    children.add(_err(context, 'card'));
    if (children.length == 1) return children.first;
    return Opacity(
      opacity: _own ? 0.6 : 1,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  // Macros.

  List<Widget> _macros(BuildContext context, bool big) {
    const ids = [Nutrients.protein, Nutrients.carbs, Nutrients.fat];
    final set = _mode == MacroMode.grams ? _grams : _percents;
    final values = _macroValues();
    final goal = _goalInUse;
    final allValid = values.every((v) => v != null);
    final anyText = set.any((c) => c.text.trim().isNotEmpty);
    MacroBreakdown? breakdown;
    int? percentSum;
    if (_mode == MacroMode.grams) {
      breakdown = MacroBreakdown(
        proteinG: values[0] ?? 0,
        carbsG: values[1] ?? 0,
        fatG: values[2] ?? 0,
      );
    } else {
      percentSum = 100 - _percentsLeft;
      if (allValid && goal != null && percentSum == 100) {
        breakdown = macrosFromPercent(
          calories: goal.toDouble(),
          proteinPercent: values[0]!.round(),
          carbsPercent: values[1]!.round(),
          fatPercent: values[2]!.round(),
        );
      }
    }
    String? result(int i) {
      final b = breakdown;
      if (b == null || values[i] == null) return null;
      if (_mode == MacroMode.grams) {
        final kcal = [b.shownProteinKcal, b.shownCarbsKcal, b.shownFatKcal][i];
        return S.goalsKcal(kcal);
      }
      final g = [b.proteinG, b.carbsG, b.fatG][i];
      return S.goalsGramsOut(roundForDisplay(g));
    }

    final rows = <Widget>[];
    for (var i = 0; i < 3; i++) {
      final field = TextField(
        controller: set[i],
        focusNode: _node('m$i'),
        keyboardType: _mode == MacroMode.grams
            ? _numberKeys
            : TextInputType.number,
        onChanged: (_) => _changed(),
        decoration: _decoration(
          S.nutrientName(ids[i]),
          suffix: _mode == MacroMode.grams ? S.unitG : S.unitPercent,
          // In percent mode Save is off while a field cannot be read, so the
          // field says why as it is typed.
          error:
              _errors['m$i'] ??
              (_mode == MacroMode.percent &&
                      set[i].text.trim().isNotEmpty &&
                      values[i] == null
                  ? S.goalsPercentBad
                  : null),
        ),
      );
      final out = result(i);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: big
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [field, if (out != null) _small(context, out)],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 96,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(out ?? '', textAlign: TextAlign.end),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    final total = Padding(
      key: const ValueKey('macro-total'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              S.goalsTotal,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_mode == MacroMode.grams && allValid)
            Text(
              S.goalsKcal(breakdown!.shownTotalKcal),
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          else if (_mode == MacroMode.percent && allValid)
            Text(
              S.percentOption(percentSum!),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );

    final notes = <Widget>[];
    if (_mode == MacroMode.grams && allValid && goal != null) {
      final diff = breakdown!.shownDifferenceFrom(goal);
      notes.add(
        _small(
          context,
          diff == 0
              ? S.goalsMatches
              : diff > 0
              ? S.goalsMoreThanGoal(diff)
              : S.goalsLessThanGoal(-diff),
        ),
      );
    }
    if (_mode == MacroMode.percent && anyText) {
      notes.add(
        _small(context, S.goalsPercentAdds(percentSum!, _percentsLeft)),
      );
      if (breakdown != null && goal != null) {
        final p = values[0]!.round();
        notes.add(
          _small(
            context,
            S.goalsPercentNote(
              p,
              goal,
              breakdown.shownProteinKcal,
              roundForDisplay(breakdown.proteinG),
            ),
          ),
        );
      }
    }
    return [...rows, total, ...notes, _err(context, 'macros')];
  }

  // The bar.

  Widget _bar(BuildContext context) {
    final theme = Theme.of(context);
    final stacked = _big(context);
    final button = FilledButton(
      style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
      onPressed: _busy || _percentsBlockSave ? null : _save,
      child: const Text(S.save),
    );
    return Material(
      color: theme.colorScheme.surfaceContainer,
      elevation: 3,
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_message != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(_message!),
                  ),
                ),
              if (stacked) ...[
                const Text(S.goalsApplies),
                const SizedBox(height: 4),
                button,
              ] else
                Row(
                  children: [
                    const Expanded(child: Text(S.goalsApplies)),
                    const SizedBox(width: 8),
                    button,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
