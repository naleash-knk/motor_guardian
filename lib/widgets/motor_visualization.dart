import 'dart:math' as math;

import 'package:flutter/material.dart';

class MotorVisualization extends StatefulWidget {
  const MotorVisualization({
    super.key,
    required this.rpm,
    required this.vibration,
    required this.temperature,
    required this.current,
    required this.voltage,
    required this.isActive,
  });

  final double rpm;
  final double vibration;
  final double temperature;
  final double current;
  final double voltage;
  final bool isActive;

  @override
  State<MotorVisualization> createState() => _MotorVisualizationState();
}

class _MotorVisualizationState extends State<MotorVisualization>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant MotorVisualization oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    if (widget.isActive) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boundedWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final safeWidth = boundedWidth.clamp(220.0, 520.0);
        final height = (safeWidth * 0.78).clamp(220.0, 360.0);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final motion = widget.isActive ? _controller.value : 0.0;
            final vibrationActive = widget.vibration >= 1;
            final vibrationOffset = widget.isActive
                ? math.sin(motion * math.pi * 12) *
                    (vibrationActive ? 3.5 : 0.0)
                : 0.0;

            return Transform.translate(
              offset: Offset(vibrationOffset, 0),
              child: SizedBox(
                width: safeWidth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6A00).withValues(
                          alpha: widget.isActive
                              ? widget.temperature.clamp(0, 90) / 220
                              : 0.08,
                        ),
                        blurRadius:
                            22 + (widget.isActive ? widget.temperature * 0.18 : 0),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    size: Size(safeWidth, height),
                    painter: _MotorPainter(
                      progress: motion,
                      rpm: widget.rpm,
                      vibration: widget.vibration,
                      temperature: widget.temperature,
                      current: widget.current,
                      voltage: widget.voltage,
                      isActive: widget.isActive,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MotorPainter extends CustomPainter {
  _MotorPainter({
    required this.progress,
    required this.rpm,
    required this.vibration,
    required this.temperature,
    required this.current,
    required this.voltage,
    required this.isActive,
  });

  final double progress;
  final double rpm;
  final double vibration;
  final double temperature;
  final double current;
  final double voltage;
  final bool isActive;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.48, size.height * 0.56);
    _paintBackgroundGlow(canvas, size);
    _paintWires(canvas, size);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.18);
    _paintMotorShadow(canvas);
    _paintMotorFeet(canvas);
    _paintHousing(canvas);
    _paintRibbing(canvas);
    _paintEndCaps(canvas);
    _paintTerminalBox(canvas);
    _paintShaft(canvas);
    _paintFanCage(canvas);
    _paintFanCore(canvas);
    _paintNamePlate(canvas);
    _paintSpecularHighlight(canvas);
    _paintHeatGlow(canvas);
    canvas.restore();

    _paintWireEnergy(canvas, size);
    _paintVibrationWaves(canvas, size);
    _paintAirflow(canvas, size);
    _paintTelemetryBadges(canvas, size);
  }

  void _paintBackgroundGlow(Canvas canvas, Size size) {
    final glowRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.52),
      width: size.width * 0.72,
      height: size.height * 0.58,
    );
    final load = ((current / 12) + (voltage / 120)).clamp(0.0, 2.0) / 2;
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF77D5FF).withValues(alpha: isActive ? 0.10 + (load * 0.08) : 0.03),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
  }

  void _paintMotorShadow(Canvas canvas) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: const Offset(0, 0), width: 232, height: 138),
          const Radius.circular(42),
        ),
      );
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.58), 28, false);
  }

  void _paintMotorFeet(Canvas canvas) {
    final footPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF263243),
          Color(0xFF111923),
        ],
      ).createShader(const Rect.fromLTWH(-110, 58, 220, 52));

    final leftFoot = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-86, 56, 42, 22),
      const Radius.circular(8),
    );
    final rightFoot = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 56, 42, 22),
      const Radius.circular(8),
    );

    canvas.drawRRect(leftFoot, footPaint);
    canvas.drawRRect(rightFoot, footPaint);
    canvas.drawCircle(const Offset(-65, 67), 3, Paint()..color = const Color(0xFF8E9AAA));
    canvas.drawCircle(const Offset(51, 67), 3, Paint()..color = const Color(0xFF8E9AAA));
  }

  void _paintHousing(Canvas canvas) {
    final shell = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(-4, 0), width: 224, height: 134),
      const Radius.circular(40),
    );
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFC35E),
            const Color(0xFFFF8E2F),
            const Color(0xFFE25A17),
            const Color(0xFFAA340E),
          ],
          stops: const [0.0, 0.28, 0.66, 1.0],
        ).createShader(shell.outerRect),
    );

    canvas.drawRRect(
      shell,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _paintRibbing(Canvas canvas) {
    for (int i = 0; i < 8; i++) {
      final x = 26 + (i * 17);
      final rib = RRect.fromRectAndRadius(
        Rect.fromLTWH(x.toDouble(), -48, 10, 96),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rib,
        Paint()..color = const Color(0xFF2A1B14).withValues(alpha: 0.68),
      );
      canvas.drawRRect(
        rib,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.06),
      );
    }
  }

  void _paintEndCaps(Canvas canvas) {
    final capPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF43586F), Color(0xFF172230)],
      ).createShader(const Rect.fromLTWH(-140, -80, 280, 160));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-116, 0), width: 28, height: 132),
        const Radius.circular(12),
      ),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(112, 0), width: 32, height: 132),
        const Radius.circular(12),
      ),
      capPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
         Rect.fromCenter(center: Offset(-150, 0), width: 64, height: 30),
        const Radius.circular(14),
      ),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF0F3F7), Color(0xFF8F9BA8)],
        ).createShader(const Rect.fromLTWH(-182, -15, 64, 30)),
    );
    canvas.drawCircle(
      const Offset(-174, 0),
      20,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE089), Color(0xFFB37D1E)],
        ).createShader( Rect.fromCircle(center: Offset(-174, 0), radius: 20)),
    );
  }

  void _paintTerminalBox(Canvas canvas) {
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-40, -92, 70, 34),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF5E748B),
            Color(0xFF263443),
          ],
        ).createShader(box.outerRect),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  void _paintShaft(Canvas canvas) {
    final shaftRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-186, -10, 44, 20),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      shaftRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFE0E6EC),
            Color(0xFF7B8794),
            Color(0xFFD4DAE1),
          ],
        ).createShader(shaftRect.outerRect),
    );
  }

  void _paintFanCage(Canvas canvas) {
    canvas.drawCircle(
      const Offset(94, 0),
      36,
      Paint()..color = const Color(0xFF17212D),
    );
    canvas.drawCircle(
      const Offset(94, 0),
      32,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );

    for (int i = 0; i < 6; i++) {
      final x = 68 + (i * 10);
      canvas.drawLine(
        Offset(x.toDouble(), -24),
        Offset(x.toDouble(), 24),
        Paint()
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.12),
      );
    }
  }

  void _paintFanCore(Canvas canvas) {
    final fanCenter = const Offset(94, 0);
    final fanRadius = 26.0;

    canvas.drawCircle(
      fanCenter,
      fanRadius + 4,
      Paint()..color = const Color(0xFF1A2231).withValues(alpha: 0.86),
    );

    for (int i = 0; i < 6; i++) {
      final angle = (i * (math.pi * 2 / 6)) + (progress * math.pi * (rpm / 210));
      final bladePath = Path()
        ..moveTo(fanCenter.dx, fanCenter.dy)
        ..quadraticBezierTo(
          fanCenter.dx + math.cos(angle) * 18,
          fanCenter.dy + math.sin(angle) * 14,
          fanCenter.dx + math.cos(angle + 0.44) * 30,
          fanCenter.dy + math.sin(angle + 0.44) * 12,
        )
        ..quadraticBezierTo(
          fanCenter.dx + math.cos(angle + 0.9) * 22,
          fanCenter.dy + math.sin(angle + 0.9) * 10,
          fanCenter.dx,
          fanCenter.dy,
        );

      canvas.drawPath(
        bladePath,
        Paint()
          ..color =
              const Color(0xFFDEE5EE).withValues(alpha: isActive ? 0.78 : 0.34),
      );
    }

    canvas.drawCircle(fanCenter, 10, Paint()..color = const Color(0xFFBFC9D4));
    canvas.drawCircle(
      fanCenter,
      fanRadius + 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _paintNamePlate(Canvas canvas) {
    final plate = RRect.fromRectAndRadius(
       Rect.fromCenter(center: Offset(-16, 2), width: 94, height: 64),
      const Radius.circular(18),
    );
    canvas.drawRRect(plate, Paint()..color = const Color(0xFFE9E1D2));
    canvas.drawRRect(
      plate,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF8A6661),
    );

    final linePaint = Paint()
      ..color = const Color(0xFF916D68)
      ..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      final y = -16 + (i * 13);
      canvas.drawLine(Offset(-40, y.toDouble()), Offset(18, y.toDouble()), linePaint);
    }

    canvas.drawCircle(const Offset(-42, -24), 4, Paint()..color = const Color(0xFFC2C4C9));
    canvas.drawCircle(const Offset(20, 24), 4, Paint()..color = const Color(0xFFC2C4C9));
  }

  void _paintSpecularHighlight(Canvas canvas) {
    final highlightRect = Rect.fromLTWH(-74, -58, 150, 44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlightRect, const Radius.circular(24)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(highlightRect),
    );
  }

  void _paintHeatGlow(Canvas canvas) {
    final heatLevel = (temperature / 100).clamp(0.0, 1.0);
    if (!isActive || heatLevel <= 0.1) {
      return;
    }

    final glowRect = Rect.fromCenter(center: const Offset(-6, 0), width: 260, height: 170);
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF8C5A).withValues(alpha: 0.22 * heatLevel),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );
  }

  void _paintWires(Canvas canvas, Size size) {
    final start = Offset(size.width * 0.78, size.height * 0.74);
    final end = Offset(size.width * 0.98, size.height * 0.96);
    final control = Offset(size.width * 0.90, size.height * 0.80);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF343A48),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  void _paintWireEnergy(Canvas canvas, Size size) {
    if (!isActive) {
      return;
    }

    final intensity = ((current / 12) + (voltage / 120)) / 2;
    final start = Offset(size.width * 0.78, size.height * 0.74);
    final end = Offset(size.width * 0.98, size.height * 0.96);
    final control = Offset(size.width * 0.90, size.height * 0.80);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    for (int i = 0; i < 3; i++) {
      final t = ((progress + (i * 0.24)) % 1.0);
      final point = _quadPoint(start, control, end, t);
      canvas.drawCircle(
        point,
        3 + (intensity * 2),
        Paint()..color = const Color(0xFF77D5FF).withValues(alpha: 0.8),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF77D5FF).withValues(alpha: 0.22 + (intensity * 0.18)),
    );
  }

  void _paintVibrationWaves(Canvas canvas, Size size) {
    if (vibration < 1) {
      return;
    }

    final center = Offset(size.width * 0.78, size.height * 0.45);
    final color = temperature > 70 ? const Color(0xFFFF8C5A) : const Color(0xFFFFD166);

    for (int i = 0; i < 3; i++) {
      final radius = 18 + (i * 16) + (isActive ? progress * 12 : 0);
      canvas.drawCircle(
        center,
        radius + 10,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(
              alpha: isActive ? (0.22 - (i * 0.05)).clamp(0.05, 0.22) : 0.05),
      );
    }
  }

  void _paintAirflow(Canvas canvas, Size size) {
    if (!isActive || rpm <= 0) {
      return;
    }

    final airflowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB9EEFF).withValues(alpha: 0.18);

    for (int i = 0; i < 3; i++) {
      final y = (size.height * 0.42) + (i * 18) + (math.sin((progress + (i * 0.18)) * math.pi * 2) * 3);
      final path = Path()
        ..moveTo(size.width * 0.68, y)
        ..quadraticBezierTo(size.width * 0.8, y - 8, size.width * 0.92, y + 2);
      canvas.drawPath(path, airflowPaint);
    }
  }

  void _paintTelemetryBadges(Canvas canvas, Size size) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final badgeWidth = size.width < 300 ? 76.0 : size.width < 380 ? 84.0 : 92.0;
    final badgeHeight = size.width < 300 ? 26.0 : 30.0;
    final topInset = size.width < 300 ? 12.0 : 20.0;
    final sideInset = size.width < 300 ? 12.0 : 20.0;
    final bottomInset = size.width < 300 ? 38.0 : 52.0;
    _badge(
      canvas,
      textPainter,
      Offset(sideInset, topInset),
      isActive ? '${voltage.toStringAsFixed(1)} V' : '- V',
      const Color(0xFF77D5FF),
      badgeWidth,
      badgeHeight,
    );
    _badge(
      canvas,
      textPainter,
      Offset(size.width - badgeWidth - sideInset, topInset),
      isActive ? '${rpm.toStringAsFixed(0)} RPM' : '- RPM',
      const Color(0xFF5CE1E6),
      badgeWidth,
      badgeHeight,
    );
    _badge(
      canvas,
      textPainter,
      Offset(sideInset, size.height - bottomInset),
      isActive ? '${temperature.toStringAsFixed(0)} deg C' : '- deg C',
      const Color(0xFFFF8C5A),
      badgeWidth,
      badgeHeight,
    );
    _badge(
      canvas,
      textPainter,
      Offset(size.width - badgeWidth - sideInset, size.height - bottomInset),
      isActive ? '${current.toStringAsFixed(1)} A' : '- A',
      const Color(0xFFFFD166),
      badgeWidth,
      badgeHeight,
    );
  }

  void _badge(
    Canvas canvas,
    TextPainter painter,
    Offset offset,
    String label,
    Color color,
    double width,
    double height,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(offset.dx, offset.dy, width, height),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: 0.28),
    );

    painter.text = TextSpan(
      text: label,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: width < 80 ? 9.5 : 11,
      ),
    );
    painter.layout(maxWidth: width - 14);
    painter.paint(canvas, Offset(offset.dx + 7, offset.dy + ((height - painter.height) / 2)));
  }

  Offset _quadPoint(Offset p0, Offset p1, Offset p2, double t) {
    final mt = 1 - t;
    final x = (mt * mt * p0.dx) + (2 * mt * t * p1.dx) + (t * t * p2.dx);
    final y = (mt * mt * p0.dy) + (2 * mt * t * p1.dy) + (t * t * p2.dy);
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _MotorPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rpm != rpm ||
        oldDelegate.vibration != vibration ||
        oldDelegate.temperature != temperature ||
        oldDelegate.current != current ||
        oldDelegate.voltage != voltage ||
        oldDelegate.isActive != isActive;
  }
}
