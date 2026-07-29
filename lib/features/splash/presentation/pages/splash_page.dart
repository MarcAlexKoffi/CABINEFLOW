import 'dart:async';

import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/shared/widgets/app_logo.dart';
import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() {
    return _SplashPageState();
  }
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  Timer? _navigationTimer;

  late final AnimationController _dotsController;

  @override
  void initState() {
    super.initState();

    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _navigationTimer = Timer(
      const Duration(milliseconds: 2500),
      _openLoginPage,
    );
  }

  void _openLoginPage() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _dotsController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.15),
            radius: 1.45,
            colors: [Color(0xFF1A2A40), AppColors.black],
            stops: [0, 0.68],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: AppLogo(
                      size: 96,
                      titleFontSize: 32,
                      icon: Icons.all_inbox_rounded,
                      subtitle: 'Vos commandes, simplement organisées',
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: _LoadingDots(controller: _dotsController),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.controller});

  final AnimationController controller;

  double _calculateScale({required double animationValue, required int index}) {
    final double shiftedValue = (animationValue - (index * 0.14)) % 1;

    if (shiftedValue < 0.5) {
      return 0.45 + (Curves.easeOut.transform(shiftedValue * 2) * 0.55);
    }

    return 0.45 + (Curves.easeIn.transform((1 - shiftedValue) * 2) * 0.55);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int index) {
            final double scale = _calculateScale(
              animationValue: controller.value,
              index: index,
            );

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 10, height: 10),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
