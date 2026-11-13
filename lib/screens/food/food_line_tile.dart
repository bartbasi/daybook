// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../data/nutrients.dart';
import '../../parser/line.dart';
import '../../strings.dart';

/// How a line is outlined. A state is never shown by color alone: each has its
/// own outline shape, and the marker words say the same thing again (grammar
/// 8.2): none for plain typing, thin for a match, dashed for a guess, thick
/// and hatched for not found, double for a saved meal header.
enum _Edge { none, thin, dashed, thick, doubled }

/// One line of the meal as the food screen draws it: a typed line, an added
/// line, a saved meal header, or an item under a header ([indent]).
///
/// [typed] is the text the user typed for the line (a slice of the box). Only
/// a not found line and a plain line use it.
class FoodLineTile extends StatelessWidget {
  const FoodLineTile({
    super.key,
    required this.line,
    this.typed = '',
    this.indent = false,
    this.current = false,
    this.onTap,
  });

  final Line line;
  final String typed;
  final bool indent;

  /// The line for the item under the cursor: drawn with a gray ring
  /// (frame 2).
  final bool current;
  final VoidCallback? onTap;

  /// The marker words a line carries, in the order they are shown and read.
  static List<String> markerWords(Line line) => [
    if (line.markers.contains(Marker.guess)) S.markerGuess,
    if (line.markers.contains(Marker.assumed)) S.markerAssumed,
    if (line.markers.contains(Marker.yourPick)) S.markerYourPick,
    if (line.markers.contains(Marker.scanned)) S.markerScanned,
  ];

  static IconData _icon(String word) => switch (word) {
    S.markerGuess => Icons.help_outline,
    S.markerAssumed => Icons.straighten,
    S.markerYourPick => Icons.push_pin_outlined,
    S.markerScanned => Icons.qr_code_scanner,
    _ => Icons.block,
  };

  /// What a screen reader says for the line. Starts with the marker words.
  static String spokenLabel(Line line, String typed) {
    if (line.plain) return typed;
    final kcal = line.nutrients[Nutrients.energy];
    switch (line.state) {
      case LineState.notFound:
        return S.spokenNotFound(typed);
      case LineState.aliasOrSavedMeal:
        final m = line.multiplier;
        return S.spokenHeader(
          line.foodName ?? '',
          m == null || m == 1 ? null : S.multiplierText(m),
          line.items.length,
          kcal,
        );
      default:
        return S.spokenLine(
          markerWords(line),
          line.foodName ?? '',
          _amount(line, spoken: true),
          kcal,
        );
    }
  }

  static String _amount(Line l, {bool spoken = false}) {
    final q = l.quantity, bq = l.baseQuantity;
    if (q == null || bq == null) return '';
    final unit = l.unitLabel ?? '';
    final bu = l.baseUnit ?? '';
    return spoken
        ? S.spokenAmount(q, unit, bq, bu)
        : S.amountText(q, unit, bq, bu);
  }

  @override
  Widget build(BuildContext context) {
    final _Edge edge;
    final Widget body;
    var hatch = false;
    if (line.plain) {
      edge = _Edge.none;
      body = Text(typed);
    } else if (line.state == LineState.notFound) {
      edge = _Edge.thick;
      hatch = true;
      body = _notFoundBody(context);
    } else if (line.state == LineState.aliasOrSavedMeal) {
      edge = _Edge.doubled;
      body = _headerBody(context);
    } else {
      final guess =
          line.markers.contains(Marker.guess) &&
          !line.markers.contains(Marker.yourPick);
      edge = guess ? _Edge.dashed : _Edge.thin;
      body = _foodBody(context);
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 24 : 0, 4, 0, 4),
      child: Semantics(
        container: true,
        button: onTap != null,
        label: spokenLabel(line, typed),
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: _Ring(
                on: current,
                child: _Outline(edge: edge, hatch: hatch, child: body),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numbers(BuildContext context, TextStyle? style) => Text(
    S.macros(
      line.nutrients[Nutrients.protein],
      line.nutrients[Nutrients.carbs],
      line.nutrients[Nutrients.fat],
    ),
    style: style,
  );

  Widget _foodBody(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodyMedium;
    final assumed = line.markers.contains(Marker.assumed);
    final words = markerWords(line);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(line.foodName ?? '')),
            const SizedBox(width: 8),
            Text(
              S.kcal(line.nutrients[Nutrients.energy]),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _amount(line),
                  style: small?.copyWith(
                    fontStyle: assumed ? FontStyle.italic : null,
                    decoration: assumed ? TextDecoration.underline : null,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
                ),
                for (final w in words) _Badge(word: w, icon: _icon(w)),
              ],
            ),
            _numbers(context, small),
          ],
        ),
        if (line.markers.contains(Marker.scanned))
          Text(S.offCredit, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _notFoundBody(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text(S.quoted(typed)),
          const Text(
            S.lineNotCounted,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: const [
          _Badge(word: S.markerNotFound, icon: Icons.block),
          Text(S.lineTapToPick),
        ],
      ),
    ],
  );

  Widget _headerBody(BuildContext context) {
    final m = line.multiplier;
    final name = line.foodName ?? '';
    final small = Theme.of(context).textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                S.headerTitle(name, m),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              S.kcal(line.nutrients[Nutrients.energy]),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(S.lineItems(line.items.length), style: small),
            _numbers(context, small),
          ],
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!on) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: child),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.word, required this.icon});

  final String word;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 2),
            Text(word, style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _Outline extends StatelessWidget {
  const _Outline({
    required this.edge,
    required this.hatch,
    required this.child,
  });

  final _Edge edge;
  final bool hatch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: child,
    );
    final radius = BorderRadius.circular(8);
    switch (edge) {
      case _Edge.none:
        return padded;
      case _Edge.thin:
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: radius,
          ),
          child: padded,
        );
      case _Edge.dashed:
        return CustomPaint(
          foregroundPainter: _DashedPainter(scheme.outline),
          child: padded,
        );
      case _Edge.thick:
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.onSurface, width: 3),
            borderRadius: radius,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: CustomPaint(
              painter: hatch ? _HatchPainter(scheme.outlineVariant) : null,
              child: padded,
            ),
          ),
        );
      case _Edge.doubled:
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: radius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: padded,
            ),
          ),
        );
    }
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    for (final PathMetric m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) => old.color != color;
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}
