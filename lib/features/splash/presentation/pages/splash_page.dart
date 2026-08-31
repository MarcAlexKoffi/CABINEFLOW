import 'dart:async';

import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/services/session_preferences.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(
      begin: .94,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    unawaited(_resolveDestination());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolveDestination() async {
    if (_routing) return;
    _routing = true;

    final Future<void> minimumDisplay = Future<void>.delayed(
      const Duration(milliseconds: 1850),
    );
    final RememberedSessionPreference preference =
        await SessionPreferences.load();

    AuthLoginResult? access;
    if (preference.rememberMe) {
      access = await widget.authRepository.refreshCurrentAccess();
    } else {
      // Firebase Auth conserve nativement une session entre deux lancements.
      // Si l'utilisateur n'a pas demandé à être mémorisé, on la ferme au
      // prochain démarrage afin que la case ait un comportement réel.
      try {
        await widget.authRepository.logout();
      } catch (_) {
        // Une déconnexion réseau ne doit pas bloquer l'écran de connexion.
      }
    }

    await minimumDisplay;
    if (!mounted) return;

    if (preference.rememberMe && access?.isAuthenticated == true) {
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.dashboard, arguments: access!.user);
      return;
    }

    if (preference.rememberMe && access?.requiresAccessScreen == true) {
      Navigator.of(
        context,
      ).pushReplacementNamed(AppRoutes.pendingAccount, arguments: access);
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1747D1),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF0A2D91),
              Color(0xFF245BE5),
              Color(0xFF2E63EB),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxHeight < 720;
              final double illustrationHeight = (constraints.maxHeight * .56)
                  .clamp(compact ? 300.0 : 350.0, 520.0);

              return Stack(
                children: <Widget>[
                  const Positioned(
                    top: -130,
                    right: -100,
                    child: _BlueGlow(size: 330, opacity: .20),
                  ),
                  const Positioned(
                    left: -120,
                    bottom: 40,
                    child: _BlueGlow(size: 300, opacity: .15),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      compact ? 18 : 28,
                      24,
                      compact ? 22 : 30,
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 34,
                              height: 34,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(28),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: Colors.white.withAlpha(42),
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/izyTel_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'IzyTel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.4,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        FadeTransition(
                          opacity: _fade,
                          child: ScaleTransition(
                            scale: _scale,
                            child: SizedBox(
                              height: illustrationHeight,
                              width: double.infinity,
                              child: Image.asset(
                                'assets/images/New_splash_illustration.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        FadeTransition(
                          opacity: _fade,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Simple. Rapide. Izy.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 23 : 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.45,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                'Vos opérations télécom, réunies au même endroit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(205),
                                  fontSize: compact ? 12.5 : 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.35,
                                ),
                              ),
                              SizedBox(height: compact ? 20 : 26),
                              SizedBox(
                                width: 42,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    minHeight: 3.5,
                                    backgroundColor: Colors.white.withAlpha(45),
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlueGlow extends StatelessWidget {
  const _BlueGlow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              Colors.lightBlueAccent.withValues(alpha: opacity),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
