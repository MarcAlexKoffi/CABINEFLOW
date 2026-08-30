import 'dart:async';
import 'dart:math' as math;

import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.authRepository,
  });

  final AuthRepository authRepository;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _timer = Timer(const Duration(milliseconds: 2100), _goToLogin);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double pulse = 1 + (_controller.value * .018);
          final double offset = (_controller.value - .5) * 10;

          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact =
                  constraints.maxWidth < 370 || constraints.maxHeight < 760;
              final double availableWidth = math.max(
                0.0,
                constraints.maxWidth - 52,
              );
              final double illustrationSize = math.min(
                availableWidth,
                compact ? 218.0 : 292.0,
              );
              final double logoSize = compact ? 58.0 : 68.0;

              return Stack(
                children: [
                  Positioned(
                    top: -110,
                    right: -40,
                    child: _GlowOrb(
                      size: 260,
                      color: IzyTelColors.primary.withAlpha(26),
                    ),
                  ),
                  Positioned(
                    left: -90,
                    bottom: 90,
                    child: _GlowOrb(
                      size: 220,
                      color: IzyTelColors.success.withAlpha(18),
                    ),
                  ),
                  SafeArea(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0.0,
                            constraints.maxHeight -
                                MediaQuery.paddingOf(context).vertical,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            26,
                            compact ? 16 : 24,
                            26,
                            compact ? 18 : 26,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TopBadge(compact: compact),
                              SizedBox(height: compact ? 20 : 34),
                              Transform.translate(
                                offset: Offset(0, offset),
                                child: Transform.scale(
                                  scale: pulse,
                                  child: _IllustrationCard(
                                    size: illustrationSize,
                                    showBadges: !compact,
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 18 : 28),
                              _BrandBlock(
                                logoSize: logoSize,
                                compact: compact,
                              ),
                              SizedBox(height: compact ? 22 : 34),
                              const _LoadingBlock(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(218),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: IzyTelColors.primary.withAlpha(26)),
            boxShadow: const [
              BoxShadow(
                color: IzyTelColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: IzyTelColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Symbols.bolt_rounded,
                  color: IzyTelColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  compact ? 'Espace opérateur IzyTel' : 'Plateforme opérateur IzyTel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({required this.size, required this.showBadges});

  final double size;
  final bool showBadges;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Container(
        padding: EdgeInsets.all(size < 240 ? 12 : 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF5F8FF)],
          ),
          borderRadius: BorderRadius.circular(size < 240 ? 28 : 34),
          boxShadow: [
            BoxShadow(
              color: IzyTelColors.primary.withAlpha(22),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    IzyTelColors.primarySoft.withAlpha(130),
                    Colors.white,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(size < 240 ? 10 : 18),
              child: Image.asset(
                'assets/images/splash_illustration.png',
                fit: BoxFit.contain,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return Icon(
                    Symbols.phone_android_rounded,
                    size: size * .42,
                    color: IzyTelColors.primary,
                  );
                },
              ),
            ),
            if (showBadges) ...[
              const Positioned(
                top: 16,
                left: 16,
                child: _MiniBadge(
                  icon: Symbols.sim_card_rounded,
                  label: 'Orange · MTN · Moov',
                ),
              ),
              const Positioned(
                bottom: 16,
                right: 16,
                child: _MiniBadge(
                  icon: Symbols.payments_rounded,
                  label: 'Paiements sécurisés',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.logoSize, required this.compact});

  final double logoSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          padding: EdgeInsets.all(compact ? 12 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4373F4), Color(0xFF3056DE)],
            ),
            borderRadius: BorderRadius.circular(compact ? 20 : 22),
            boxShadow: [
              BoxShadow(
                color: IzyTelColors.primary.withAlpha(30),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return const Icon(
                Symbols.wifi_tethering_rounded,
                color: Colors.white,
                size: 30,
              );
            },
          ),
        ),
        SizedBox(height: compact ? 12 : 16),
        Text(
          'IzyTel',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: IzyTelColors.textPrimary,
            fontSize: compact ? 32 : 38,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Text(
            compact
                ? 'Encaisser, distribuer et superviser simplement.'
                : 'Le cockpit intelligent pour encaisser, distribuer et superviser les commandes opérateurs.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.textSecondary,
              fontSize: compact ? 13 : 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: IzyTelColors.outline,
              color: IzyTelColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Chargement de l’espace opérateur…',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: IzyTelColors.textMuted,
            fontWeight: FontWeight.w600,
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
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 165),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: IzyTelColors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
