import 'dart:async';

import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_brand.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _navigationTimer = Timer(
      const Duration(milliseconds: 1500),
      _openLoginPage,
    );
  }

  void _openLoginPage() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.surface,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF7FAFF), Color(0xFFEEF5FF)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const IzyTelBrandMark(size: 104),
                const SizedBox(height: 22),
                const IzyTelWordmark(
                  fontSize: 42,
                  showTagline: true,
                  centered: true,
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: 144,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: const LinearProgressIndicator(
                      minHeight: 4,
                      backgroundColor: IzyTelColors.primarySoft,
                      color: IzyTelColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Votre espace professionnel',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textMuted,
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
