import 'package:flutter/material.dart';

class AppMotionBackground extends StatelessWidget {
  const AppMotionBackground({
    super.key,
    required this.progress,
  });

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF040B15),
                Color(0xFF0A1830),
                Color(0xFF0E233C),
              ],
            ),
          ),
        ),
        Positioned(
          top: -120 + (40 * progress),
          right: -60,
          child: _GlowOrb(
            size: 280,
            color: const Color(0xFF5CE1E6).withValues(alpha: 0.20),
          ),
        ),
        Positioned(
          bottom: -160 + (50 * progress),
          left: -80,
          child: _GlowOrb(
            size: 340,
            color: const Color(0xFF3B82F6).withValues(alpha: 0.18),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _GridPainter(progress),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _AccentPainter(progress),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    const spacing = 36.0;
    final offset = progress * spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x + offset, 0), Offset(x - offset, size.height), paint);
    }

    for (double y = 0; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.progress != progress;
}

class _AccentPainter extends CustomPainter {
  _AccentPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final railPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x00000000),
          const Color(0x665CE1E6),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2));

    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.18, size.width, 2), railPaint);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.78, size.width, 2), railPaint);

    final nodePaint = Paint()..color = const Color(0x44FFFFFF);
    for (int i = 0; i < 6; i++) {
      final x = (size.width / 6) * i + ((progress * 18) % 18);
      canvas.drawCircle(Offset(x, size.height * 0.18), 3, nodePaint);
      canvas.drawCircle(Offset(size.width - x, size.height * 0.78), 3, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AccentPainter oldDelegate) => oldDelegate.progress != progress;
}
