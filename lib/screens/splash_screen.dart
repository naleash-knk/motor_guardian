import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_motion_background.dart';
import '../app_theme.dart';
import 'connect_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..forward();

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.08, 0.42, curve: Curves.easeOutBack),
  );

  late final Animation<double> _titleOpacity = CurvedAnimation(
    parent: _master,
    curve: const Interval(0.28, 0.58, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 3600), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 900),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: const ConnectScreen(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _master.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _master,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              AppMotionBackground(progress: _master.value),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.18),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    children: [
                      const Spacer(),
                      Transform.scale(
                        scale: Tween<double>(begin: 0.56, end: 1.0).evaluate(_logoScale),
                        child: Opacity(
                          opacity: _logoScale.value.clamp(0, 1),
                          child: _AnimatedLogo(progress: _master.value),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Opacity(
                        opacity: _titleOpacity.value,
                        child: Transform.translate(
                          offset: Offset(0, 24 * (1 - _titleOpacity.value)),
                          child: Column(
                            children: [
                              Text(
                                AppBrand.appName,
                                style: theme.textTheme.displayLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppBrand.slogan,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: AppBrand.mist.withValues(alpha: 0.82),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final glow = 18 + (22 * math.sin(progress * math.pi * 3).abs());

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 176,
          height: 176,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppBrand.cyan.withValues(alpha: 0.30),
                blurRadius: glow,
                spreadRadius: 6,
              ),
            ],
            gradient: const RadialGradient(
              colors: [Color(0xCC112742), Color(0x22112742), Colors.transparent],
            ),
          ),
        ),
        Transform.rotate(
          angle: progress * math.pi * 1.4,
          child: Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppBrand.cyan.withValues(alpha: 0.16),
              ),
            ),
          ),
        ),
        Container(
          width: 144,
          height: 144,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Image.asset(AppBrand.logoAsset, fit: BoxFit.contain),
        ),
      ],
    );
  }
}
