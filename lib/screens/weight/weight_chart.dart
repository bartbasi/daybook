// Daybook. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../math/weight_trend.dart';
import '../../strings.dart';
import '../../util/dates.dart';
import '../../util/units.dart';

/// One point on the chart: a local date and a weight in the display unit.
typedef ChartPoint = ({String date, double value});

/// Everything the chart draws, for one range. Built by [buildChartData] and
/// handed to [WeightChartPainter], so tests can check it without pixels.
class WeightChartData {
  const WeightChartData({
    required this.startDate,
    required this.endDate,
    required this.dots,
    required this.trend,
    required this.units,
  });

  /// The first and last day of the range, 'YYYY-MM-DD'.
  final String startDate;
  final String endDate;

  /// Every weigh-in in the range, oldest first.
  final List<ChartPoint> dots;

  /// The trend, one point for each day of the range from the first day the
  /// trend exists. It stays flat on days with no weigh-in.
  final List<ChartPoint> trend;
  final UnitSystem units;
}

/// The data for a range of [rangeDays] days ending today (30 means today and
/// the 29 days before), or for all weigh-ins when [rangeDays] is null. [rows]
/// are the weigh-ins that are not deleted. Returns null when there are none.
WeightChartData? buildChartData({
  required List<WeightEntry> rows,
  required String today,
  required int? rangeDays,
  required UnitSystem units,
}) {
  if (rows.isEmpty) return null;
  final points = weightTrend(
    rows.map((r) => (localDate: r.localDate, kg: r.weightKg)),
  );
  final lastDay = points.last.localDate.compareTo(today) > 0
      ? points.last.localDate
      : today;
  final start = rangeDays == null
      ? points.first.localDate
      : addDays(lastDay, 1 - rangeDays);

  final dots = <ChartPoint>[
    for (final r in rows.reversed)
      if (r.localDate.compareTo(start) >= 0 &&
          r.localDate.compareTo(lastDay) <= 0)
        (date: r.localDate, value: kgToWeight(r.weightKg, units)),
  ];

  final trend = <ChartPoint>[];
  var next = 0;
  TrendPoint? current;
  var day = start;
  while (day.compareTo(lastDay) <= 0) {
    while (next < points.length && points[next].localDate.compareTo(day) <= 0) {
      current = points[next++];
    }
    if (current != null) {
      trend.add((date: day, value: kgToWeight(current.trendKg, units)));
    }
    day = addDays(day, 1);
  }
  return WeightChartData(
    startDate: start,
    endDate: lastDay,
    dots: dots,
    trend: trend,
    units: units,
  );
}

int _dayNumber(String date) =>
    parseDate(date).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// The chart with a spoken label. Dots are hollow circles and the trend is a
/// thick solid line, so the two differ by shape and not only by color.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.data, required this.today});

  final WeightChartData data;
  final String today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final first = data.trend.first.value;
    final last = data.trend.last.value;
    final unit = S.unitWord(data.units);
    final from = S.monthDay(data.startDate, today);
    final to = S.monthDay(data.endDate, today);
    final label = data.trend.length < 2
        ? S.chartLabelOne(from, to, last.toStringAsFixed(1), unit)
        : S.chartLabel(
            from,
            to,
            first.toStringAsFixed(1),
            last.toStringAsFixed(1),
            unit,
          );
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: CustomPaint(
        size: Size.fromHeight(200 * scaler.scale(1).clamp(1.0, 1.5)),
        painter: WeightChartPainter(
          data: data,
          today: today,
          lineColor: scheme.onSurface,
          dotColor: scheme.onSurfaceVariant,
          dotFill: scheme.surface,
          gridColor: scheme.outlineVariant,
          textColor: scheme.onSurfaceVariant,
          labelColor: scheme.onSurface,
          textScaler: scaler,
        ),
      ),
    );
  }
}

class WeightChartPainter extends CustomPainter {
  WeightChartPainter({
    required this.data,
    required this.today,
    required this.lineColor,
    required this.dotColor,
    required this.dotFill,
    required this.gridColor,
    required this.textColor,
    required this.labelColor,
    required this.textScaler,
  });

  final WeightChartData data;
  final String today;
  final Color lineColor;
  final Color dotColor;
  final Color dotFill;
  final Color gridColor;
  final Color textColor;
  final Color labelColor;
  final TextScaler textScaler;

  static const _steps = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];

  TextPainter _text(String s, Color color, {bool bold = false}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      ),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (data.trend.isEmpty) return;
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final p in [...data.dots, ...data.trend]) {
      lo = math.min(lo, p.value);
      hi = math.max(hi, p.value);
    }
    final pad = math.max((hi - lo) * 0.1, 0.5);
    lo -= pad;
    hi += pad;
    var step = _steps.last;
    for (final s in _steps) {
      if ((hi - lo) / s <= 4) {
        step = s;
        break;
      }
    }
    final lines = <double>[];
    for (var v = (lo / step).ceil() * step; v <= hi; v += step) {
      lines.add(v);
    }
    String fmt(double v) =>
        step >= 1 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

    final yLabels = [for (final v in lines) _text(fmt(v), textColor)];
    final endLabel = _text(
      data.trend.last.value.toStringAsFixed(1),
      labelColor,
      bold: true,
    );
    final dateStyleHeight = _text('Oct 14', textColor).height;
    var left = 0.0;
    for (final t in yLabels) {
      left = math.max(left, t.width);
    }
    left += 6;
    final right = endLabel.width + 6;
    final top = endLabel.height / 2 + 2;
    final bottom = dateStyleHeight + 8;
    final plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );

    final firstDay = _dayNumber(data.startDate);
    final span = _dayNumber(data.endDate) - firstDay;
    double x(String date) => span == 0
        ? plot.center.dx
        : plot.left + (_dayNumber(date) - firstDay) / span * plot.width;
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i < lines.length; i++) {
      final yy = y(lines[i]);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
      yLabels[i].paint(canvas, Offset(0, yy - yLabels[i].height / 2));
    }

    final path = Path();
    for (var i = 0; i < data.trend.length; i++) {
      final p = data.trend[i];
      final o = Offset(x(p.date), y(p.value));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    if (data.trend.length == 1) {
      final o = Offset(x(data.trend.first.date), y(data.trend.first.value));
      path.relativeLineTo(0.1, 0);
      canvas.drawCircle(o, 2.5, Paint()..color = lineColor);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );

    final fill = Paint()..color = dotFill;
    final ring = Paint()
      ..color = dotColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final d in data.dots) {
      final o = Offset(x(d.date), y(d.value));
      canvas.drawCircle(o, 3.5, fill);
      canvas.drawCircle(o, 3.5, ring);
    }

    final endPoint = Offset(x(data.trend.last.date), y(data.trend.last.value));
    endLabel.paint(
      canvas,
      Offset(
        math.min(endPoint.dx + 5, size.width - endLabel.width),
        endPoint.dy - endLabel.height / 2,
      ),
    );

    // Dates under the plot: the first, the middle if there is room, the last.
    final labelY = plot.bottom + 6;
    final startText = _text(S.monthDay(data.startDate, today), textColor);
    final endText = _text(S.monthDay(data.endDate, today), textColor);
    startText.paint(canvas, Offset(plot.left, labelY));
    final endLeft = math.max(
      plot.left + startText.width + 4,
      plot.right - endText.width,
    );
    endText.paint(canvas, Offset(endLeft, labelY));
    if (span >= 2) {
      final mid = addDays(data.startDate, span ~/ 2);
      final midText = _text(S.monthDay(mid, today), textColor);
      final midLeft = plot.center.dx - midText.width / 2;
      if (midLeft > plot.left + startText.width + 8 &&
          midLeft + midText.width < endLeft - 8) {
        midText.paint(canvas, Offset(midLeft, labelY));
      }
    }
  }

  @override
  bool shouldRepaint(WeightChartPainter old) =>
      old.data != data ||
      old.today != today ||
      old.lineColor != lineColor ||
      old.dotColor != dotColor ||
      old.dotFill != dotFill ||
      old.gridColor != gridColor ||
      old.textColor != textColor ||
      old.labelColor != labelColor ||
      old.textScaler != textScaler;
}
