import 'dart:math' as math;

import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class BackofficeLineSeries {
  const BackofficeLineSeries({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double> values;
  final Color color;
}

class BackofficeLineChart extends StatefulWidget {
  const BackofficeLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 290,
  });

  final List<String> labels;
  final List<BackofficeLineSeries> series;
  final double height;

  @override
  State<BackofficeLineChart> createState() => _BackofficeLineChartState();
}

class _BackofficeLineChartState extends State<BackofficeLineChart> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.labels.isEmpty || widget.series.isEmpty) {
      return const _ChartEmpty(message: 'Pas encore assez de données pour tracer la période.');
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        const double leftPad = 46;
        const double rightPad = 14;
        final double plotWidth = math.max(1, width - leftPad - rightPad);
        final int count = widget.labels.length;

        void updateHover(Offset localPosition) {
          if (count <= 1) {
            if (_hoveredIndex != 0) setState(() => _hoveredIndex = 0);
            return;
          }
          final double x = (localPosition.dx - leftPad).clamp(0, plotWidth).toDouble();
          final int index = ((x / plotWidth) * (count - 1)).round().clamp(0, count - 1).toInt();
          if (_hoveredIndex != index) setState(() => _hoveredIndex = index);
        }

        final int? index = _hoveredIndex;
        final double markerX = index == null
            ? 0
            : leftPad + (count <= 1 ? 0 : plotWidth * index / (count - 1));
        final double tooltipWidth = math.min(230, math.max(180, width * .34));
        final double tooltipLeft = index == null
            ? 0
            : (markerX - tooltipWidth / 2).clamp(6, math.max(6, width - tooltipWidth - 6)).toDouble();

        return MouseRegion(
          onHover: (PointerHoverEvent event) => updateHover(event.localPosition),
          onExit: (_) => setState(() => _hoveredIndex = null),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: _LineChartPainter(
                      labels: widget.labels,
                      series: widget.series,
                      hoveredIndex: index,
                      textColor: BackofficePalette.muted,
                      gridColor: BackofficePalette.line,
                    ),
                  ),
                ),
                if (index != null)
                  Positioned(
                    left: tooltipLeft,
                    top: 8,
                    width: tooltipWidth,
                    child: IgnorePointer(
                      child: _LineTooltip(
                        label: widget.labels[index],
                        series: widget.series,
                        index: index,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.labels,
    required this.series,
    required this.hoveredIndex,
    required this.textColor,
    required this.gridColor,
  });

  final List<String> labels;
  final List<BackofficeLineSeries> series;
  final int? hoveredIndex;
  final Color textColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 46;
    const double right = 14;
    const double top = 42;
    const double bottom = 32;
    final Rect plot = Rect.fromLTWH(
      left,
      top,
      math.max(1, size.width - left - right),
      math.max(1, size.height - top - bottom),
    );

    double maxY = 0;
    for (final BackofficeLineSeries item in series) {
      for (final double value in item.values) {
        maxY = math.max(maxY, value);
      }
    }
    if (maxY <= 0) maxY = 1;
    maxY = _niceCeiling(maxY);

    final Paint gridPaint = Paint()
      ..color = gridColor.withValues(alpha: .9)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final double y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _paintText(
        canvas,
        _compactNumber(maxY * i / 4),
        Offset(2, y - 7),
        textColor,
        10,
        FontWeight.w600,
      );
    }

    final int count = labels.length;
    final int step = count <= 7 ? 1 : count <= 14 ? 2 : 5;
    for (int i = 0; i < count; i += step) {
      final double x = _xFor(plot, i, count);
      _paintCenteredText(canvas, labels[i], Offset(x, plot.bottom + 10), textColor, 10);
    }
    if (count > 1 && (count - 1) % step != 0) {
      _paintCenteredText(
        canvas,
        labels.last,
        Offset(plot.right, plot.bottom + 10),
        textColor,
        10,
      );
    }

    for (final BackofficeLineSeries item in series) {
      if (item.values.isEmpty) continue;
      final Paint linePaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final Paint pointPaint = Paint()..color = item.color;
      final Path path = Path();
      final int usable = math.min(count, item.values.length);
      for (int i = 0; i < usable; i++) {
        final double x = _xFor(plot, i, count);
        final double y = plot.bottom - (item.values[i] / maxY).clamp(0, 1).toDouble() * plot.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        if (count <= 12) canvas.drawCircle(Offset(x, y), 2.6, pointPaint);
      }
      canvas.drawPath(path, linePaint);
    }

    final int? hover = hoveredIndex;
    if (hover != null && hover >= 0 && hover < count) {
      final double x = _xFor(plot, hover, count);
      final Paint hoverLine = Paint()
        ..color = BackofficePalette.ink.withValues(alpha: .16)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), hoverLine);
      for (final BackofficeLineSeries item in series) {
        if (hover >= item.values.length) continue;
        final double y = plot.bottom - (item.values[hover] / maxY).clamp(0, 1).toDouble() * plot.height;
        canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = item.color);
      }
    }
  }

  double _xFor(Rect plot, int index, int count) {
    if (count <= 1) return plot.left;
    return plot.left + plot.width * index / (count - 1);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.labels != labels ||
        oldDelegate.series != series ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

class _LineTooltip extends StatelessWidget {
  const _LineTooltip({required this.label, required this.series, required this.index});

  final String label;
  final List<BackofficeLineSeries> series;
  final int index;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF7101828),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x29101828), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            ),
            const SizedBox(height: 5),
            for (final BackofficeLineSeries item in series)
              if (index < item.values.length)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _compactNumber(item.values[index]),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class BackofficeDonutDatum {
  const BackofficeDonutDatum({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class BackofficeDonutChart extends StatelessWidget {
  const BackofficeDonutChart({
    super.key,
    required this.data,
    required this.centerLabel,
    required this.centerValue,
    this.size = 190,
  });

  final List<BackofficeDonutDatum> data;
  final String centerLabel;
  final String centerValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _DonutPainter(data: data))),
          Padding(
            padding: EdgeInsets.all(size * .26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  centerValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.35,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  centerLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BackofficePalette.muted,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.data});

  final List<BackofficeDonutDatum> data;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2 - 10;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..color = BackofficePalette.line;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    final double total = data.fold<double>(0, (double sum, BackofficeDonutDatum item) => sum + math.max(0, item.value));
    if (total <= 0) return;
    double start = -math.pi / 2;
    const double gap = .035;
    for (final BackofficeDonutDatum item in data) {
      if (item.value <= 0) continue;
      final double sweep = math.pi * 2 * item.value / total;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.round
        ..color = item.color;
      canvas.drawArc(rect, start + gap / 2, math.max(.01, sweep - gap), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.data != data;
}

class BackofficeBarDatum {
  const BackofficeBarDatum({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.color,
    this.secondaryLabel,
  });

  final String label;
  final double value;
  final String displayValue;
  final Color color;
  final String? secondaryLabel;
}

class BackofficeHorizontalBarChart extends StatelessWidget {
  const BackofficeHorizontalBarChart({
    super.key,
    required this.data,
    this.maxRows = 8,
  });

  final List<BackofficeBarDatum> data;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final List<BackofficeBarDatum> visible = data.take(maxRows).toList(growable: false);
    if (visible.isEmpty) {
      return const _ChartEmpty(message: 'Aucune donnée disponible pour cette comparaison.');
    }
    final double maxValue = visible.fold<double>(0, (double value, BackofficeBarDatum item) => math.max(value, item.value));
    return Column(
      children: visible
          .map(
            (BackofficeBarDatum item) => Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _HorizontalBarRow(item: item, maxValue: maxValue <= 0 ? 1 : maxValue),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _HorizontalBarRow extends StatelessWidget {
  const _HorizontalBarRow({required this.item, required this.maxValue});

  final BackofficeBarDatum item;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final double ratio = (item.value / maxValue).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (item.secondaryLabel?.trim().isNotEmpty == true)
                    Text(
                      item.secondaryLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.displayValue,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: BackofficePalette.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: <Widget>[
                const Positioned.fill(child: ColoredBox(color: Color(0xFFE9EEF6))),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: ColoredBox(color: item.color),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BackofficeChartLegend extends StatelessWidget {
  const BackofficeChartLegend({super.key, required this.items});

  final List<BackofficeDonutDatum> items;

  @override
  Widget build(BuildContext context) {
    final double total = items.fold<double>(0, (double sum, BackofficeDonutDatum item) => sum + math.max(0, item.value));
    return Column(
      children: items
          .map(
            (BackofficeDonutDatum item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BackofficePalette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Text(
                    total <= 0 ? '0 %' : '${(item.value * 100 / total).round()} %',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BackofficePalette.muted,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _compactNumber(item.value),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.muted),
      ),
    );
  }
}

double _niceCeiling(double value) {
  if (value <= 10) return math.max(4, value.ceilToDouble());
  final double magnitude = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
  final double normalized = value / magnitude;
  final double nice = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return nice * magnitude;
}

String _compactNumber(double value) {
  if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(value.abs() >= 10000000 ? 0 : 1)}M';
  if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(value.abs() >= 10000 ? 0 : 1)}k';
  return value.round().toString();
}

void _paintText(
  Canvas canvas,
  String text,
  Offset offset,
  Color color,
  double size,
  FontWeight weight,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}

void _paintCenteredText(
  Canvas canvas,
  String text,
  Offset center,
  Color color,
  double size,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w600)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 64);
  painter.paint(canvas, Offset(center.dx - painter.width / 2, center.dy));
}
