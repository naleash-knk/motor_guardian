import 'package:flutter/material.dart';

class ChartLine {
  const ChartLine({
    required this.label,
    required this.color,
    required this.values,
  });

  final String label;
  final Color color;
  final List<double> values;
}

class TelemetryChart extends StatelessWidget {
  const TelemetryChart({
    super.key,
    required this.lines,
    this.unit,
    this.minY,
    this.maxY,
  });

  final List<ChartLine> lines;
  final String? unit;
  final double? minY;
  final double? maxY;

  @override
  Widget build(BuildContext context) {
    final hasValues = lines.any((line) => line.values.isNotEmpty);

    return Column(
      children: [
        Expanded(
          child: hasValues
              ? CustomPaint(
                  painter: _TelemetryChartPainter(
                    lines: lines,
                    unit: unit,
                    minY: minY,
                    maxY: maxY,
                  ),
                  child: Container(),
                )
              : Center(
                  child: Text(
                    'Turn on the motor to receive values',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
        if (hasValues) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            children: lines
                .map(
                  (line) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: line.color,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        line.label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _TelemetryChartPainter extends CustomPainter {
  _TelemetryChartPainter({
    required this.lines,
    required this.unit,
    required this.minY,
    required this.maxY,
  });

  final List<ChartLine> lines;
  final String? unit;
  final double? minY;
  final double? maxY;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(44, 10, 12, 28);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );

    final background = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.01),
        ],
      ).createShader(chartRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(chartRect, const Radius.circular(22)),
      background,
    );

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final y = chartRect.top + (chartRect.height * i / 4);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);
    }

    final allValues = lines.expand((line) => line.values).toList();
    if (allValues.isEmpty) {
      return;
    }

    final rawMin = allValues.reduce((a, b) => a < b ? a : b);
    final rawMax = allValues.reduce((a, b) => a > b ? a : b);
    final dynamicRange = (rawMax - rawMin).abs();
    final paddingValue = dynamicRange < 0.001 ? (rawMax.abs() * 0.08) + 1 : dynamicRange * 0.18;
    final resolvedMin = minY ?? (rawMin - paddingValue);
    final resolvedMax = maxY ?? (rawMax + paddingValue);
    final range = (resolvedMax - resolvedMin).abs() < 0.001 ? 1.0 : (resolvedMax - resolvedMin);

    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < 5; i++) {
      final factor = 1 - (i / 4);
      final value = resolvedMin + (range * factor);
      final y = chartRect.top + (chartRect.height * i / 4);
      labelPainter.text = TextSpan(
        text: _formatAxisValue(value, unit),
        style: const TextStyle(
          color: Color(0xFF8FA6BF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
      labelPainter.layout(maxWidth: 36);
      labelPainter.paint(canvas, Offset(0, y - 7));
    }

    for (final line in lines) {
      if (line.values.length < 2) {
        continue;
      }

      final path = Path();
      final fill = Path();
      Offset? previousPoint;

      for (int i = 0; i < line.values.length; i++) {
        final x = chartRect.left + (chartRect.width * i / (line.values.length - 1));
        final normalized = (line.values[i] - resolvedMin) / range;
        final y = chartRect.bottom - (chartRect.height * normalized);
        final point = Offset(x, y);

        if (i == 0) {
          path.moveTo(point.dx, point.dy);
          fill.moveTo(x, chartRect.bottom);
          fill.lineTo(point.dx, point.dy);
        } else {
          final mid = Offset((previousPoint!.dx + point.dx) / 2, (previousPoint.dy + point.dy) / 2);
          path.quadraticBezierTo(previousPoint.dx, previousPoint.dy, mid.dx, mid.dy);
          fill.lineTo(point.dx, point.dy);
        }
        previousPoint = point;
      }

      if (previousPoint != null) {
        path.lineTo(previousPoint.dx, previousPoint.dy);
      }

      fill
        ..lineTo(chartRect.right, chartRect.bottom)
        ..close();

      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              line.color.withValues(alpha: 0.22),
              line.color.withValues(alpha: 0.02),
            ],
          ).createShader(chartRect),
      );

      canvas.drawPath(
        path,
        Paint()
          ..color = line.color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );

      for (int i = 0; i < line.values.length; i++) {
        final x = chartRect.left + (chartRect.width * i / (line.values.length - 1));
        final normalized = (line.values[i] - resolvedMin) / range;
        final y = chartRect.bottom - (chartRect.height * normalized);
        canvas.drawCircle(Offset(x, y), 2.6, Paint()..color = line.color);
      }
    }
  }

  String _formatAxisValue(double value, String? unit) {
    final formatted = value.abs() >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    if (unit == null || unit.isEmpty) {
      return formatted;
    }
    return '$formatted$unit';
  }

  @override
  bool shouldRepaint(covariant _TelemetryChartPainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY;
  }
}
