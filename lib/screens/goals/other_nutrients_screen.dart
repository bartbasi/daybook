// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../data/nutrients.dart';
import '../../strings.dart';
import '../my_foods/food_editor.dart' show foodNumberProblem, parseFoodNumber;

// The Other nutrients list (goals.html frame 3 note). Each tracked nutrient
// has its goal: the Daily Value unless the user changed it. Total sugar and
// trans fat have no Daily Value, so no goal until the user gives one.
//
// Changes are held by the Goals screen and written when it saves, because a
// goals row is one save (saving only these would work the calorie goal out
// again). [onChanged] gets the whole map of the user's own goals each time.

class OtherNutrientsScreen extends StatefulWidget {
  const OtherNutrientsScreen({
    super.key,
    required this.overrides,
    required this.onChanged,
  });

  /// The user's own goals so far, by nutrient id.
  final Map<int, double> overrides;
  final ValueChanged<Map<int, double>> onChanged;

  @override
  State<OtherNutrientsScreen> createState() => _OtherNutrientsScreenState();
}

class _OtherNutrientsScreenState extends State<OtherNutrientsScreen> {
  late Map<int, double> _own = Map.of(widget.overrides);

  /// Calories and the three macros come first in the list of tracked
  /// nutrients, and their goals are in the goals row itself.
  static final _listed = Nutrients.tracked.skip(4).toList();

  void _set(Map<int, double> next) {
    setState(() => _own = next);
    widget.onChanged(Map.of(next));
  }

  static String _amount(double v) =>
      v == v.roundToDouble() ? S.count(v.round()) : S.numberText(v);

  String _sub(Nutrient n) {
    final own = _own[n.id];
    final dv = Nutrients.dailyValueOf(n.id);
    if (own != null) {
      return S.otherRowSub(
        _amount(own),
        S.nutrientUnit(n.unit),
        S.otherYourGoal,
      );
    }
    if (dv != null) {
      return S.otherRowSub(
        _amount(dv),
        S.nutrientUnit(n.unit),
        S.otherDailyValue,
      );
    }
    return S.otherNoGoal;
  }

  Future<void> _edit(Nutrient n) async {
    final result = await showDialog<_Edit>(
      context: context,
      builder: (_) => _EditDialog(
        nutrient: n,
        current: _own[n.id],
        hasDaily: Nutrients.dailyValueOf(n.id) != null,
      ),
    );
    if (result == null || !mounted) return;
    final next = Map.of(_own);
    if (result.value == null) {
      next.remove(n.id);
    } else {
      next[n.id] = result.value!;
    }
    _set(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(S.otherTitle)),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(S.otherIntro),
              ),
              for (final n in _listed)
                Semantics(
                  container: true,
                  label: '${S.nutrientName(n.id)}. ${_sub(n)}',
                  excludeSemantics: true,
                  button: true,
                  child: ListTile(
                    minTileHeight: 56,
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.nutrientName(n.id)),
                    subtitle: Text(_sub(n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _edit(n),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the edit dialog hands back: a goal, or null to go back to the Daily
/// Value (or to no goal).
class _Edit {
  const _Edit(this.value);
  final double? value;
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.nutrient,
    required this.current,
    required this.hasDaily,
  });

  final Nutrient nutrient;
  final double? current;
  final bool hasDaily;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final _text = TextEditingController(
    text: widget.current == null ? '' : S.numberText(widget.current!),
  );
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseFoodNumber(_text.text);
    if (v == null || v <= 0) {
      setState(() => _error = foodNumberProblem(_text.text, S.otherBad));
      return;
    }
    Navigator.of(context).pop(_Edit(v));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nutrient;
    return AlertDialog(
      title: Text(S.otherEditTitle(S.nutrientName(n.id))),
      scrollable: true,
      content: TextField(
        controller: _text,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: S.otherField,
          suffixText: S.nutrientUnit(n.unit),
          errorText: _error,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.of(context).pop(const _Edit(null)),
            child: Text(widget.hasDaily ? S.otherUseDaily : S.otherClear),
          ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(S.otherCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: _save,
          child: const Text(S.save),
        ),
      ],
    );
  }
}
