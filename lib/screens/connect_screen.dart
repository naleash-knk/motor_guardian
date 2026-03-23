import 'package:flutter/material.dart';

import '../app_motion_background.dart';
import '../app_theme.dart';
import '../core/mqtt_service.dart';
import 'dashboard_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  bool _connecting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate() || _connecting) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _connecting = true);

    final mqtt = MQTTService();

    try {
      await mqtt.connect(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: DashboardScreen(mqtt),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $error')),
      );
      setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final progress = Curves.easeOutCubic.transform(_animationController.value);

          return Stack(
            fit: StackFit.expand,
            children: [
              AppMotionBackground(progress: progress),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 800;
                    final horizontalPadding = constraints.maxWidth < 420 ? 16.0 : 24.0;

                    return SingleChildScrollView(
                      padding: EdgeInsets.all(horizontalPadding),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                        child: compact
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _BrandHero(progress: progress),
                                  const SizedBox(height: 24),
                                  _ConnectPanel(
                                    formKey: _formKey,
                                    usernameController: _usernameController,
                                    passwordController: _passwordController,
                                    connecting: _connecting,
                                    onConnect: _connect,
                                    progress: progress,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: _BrandHero(progress: progress)),
                                  const SizedBox(width: 28),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 520),
                                        child: _ConnectPanel(
                                          formKey: _formKey,
                                          usernameController: _usernameController,
                                          passwordController: _passwordController,
                                          connecting: _connecting,
                                          onConnect: _connect,
                                          progress: progress,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppBrand.cyan.withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                        stops: [
                          (progress - 0.22).clamp(0, 1),
                          progress.clamp(0, 1),
                          (progress + 0.22).clamp(0, 1),
                        ],
                      ),
                    ),
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

class _BrandHero extends StatelessWidget {
  const _BrandHero({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final compact = width < 420;

    return Transform.translate(
      offset: Offset(-20 * (1 - progress), 28 * (1 - progress)),
      child: Opacity(
        opacity: progress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: compact ? 60 : 72,
              height: compact ? 60 : 72,
              padding: EdgeInsets.all(compact ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Image.asset(AppBrand.logoAsset),
            ),
            SizedBox(height: compact ? 20 : 28),
            Text(
              AppBrand.connectTitle,
              style: (compact ? theme.textTheme.headlineMedium : theme.textTheme.displaySmall),
            ),
            const SizedBox(height: 16),
            Text(
              AppBrand.slogan,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppBrand.mist.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectPanel extends StatelessWidget {
  const _ConnectPanel({
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.connecting,
    required this.onConnect,
    required this.progress,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool connecting;
  final VoidCallback onConnect;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 420;
    return Transform.translate(
      offset: Offset(24 * (1 - progress), 32 * (1 - progress)),
      child: Opacity(
        opacity: progress,
        child: Container(
          padding: EdgeInsets.all(compact ? 18 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 36,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: usernameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      onFieldSubmitted: (_) => onConnect(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icon(Icons.lock_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: connecting ? null : onConnect,
                child: connecting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
