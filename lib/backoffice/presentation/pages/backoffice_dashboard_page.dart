import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeDashboardPage extends StatelessWidget {
  const BackofficeDashboardPage({
    super.key,
    required this.user,
    this.onOpenUsers,
  });

  final AppUser user;
  final VoidCallback? onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DashboardHero(user: user, onOpenUsers: onOpenUsers),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Vue d’ensemble',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: BackofficePalette.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Symbols.insights_rounded,
                    size: 16,
                    color: BackofficePalette.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Workspace IzyTel',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 1050
                ? 4
                : constraints.maxWidth >= 650
                ? 2
                : 1;
            const double spacing = 14;
            final double cardWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            final List<_DashboardMetricData> metrics = <_DashboardMetricData>[
              _DashboardMetricData(
                icon: Symbols.verified_user_rounded,
                eyebrow: 'ACCÈS',
                title: user.roleLabel,
                description: 'Session staff sécurisée et permissions appliquées.',
                color: BackofficePalette.primary,
                softColor: const Color(0xFFEAF1FF),
              ),
              const _DashboardMetricData(
                icon: Symbols.devices_rounded,
                eyebrow: 'CONTINUITÉ',
                title: 'Mobile conservé',
                description: 'Le back-office complète l’Admin mobile sans le remplacer.',
                color: Color(0xFF38BDF8),
                softColor: Color(0xFFEAF8FF),
              ),
              const _DashboardMetricData(
                icon: Symbols.hub_rounded,
                eyebrow: 'DONNÉES',
                title: 'Backends partagés',
                description: 'Firebase et Supabase restent les sources communes.',
                color: Color(0xFF1D4ED8),
                softColor: Color(0xFFE8F0FF),
              ),
              const _DashboardMetricData(
                icon: Symbols.apps_rounded,
                eyebrow: 'WEB',
                title: 'Modules unifiés',
                description: 'La fondation visuelle est prête pour les modules métier.',
                color: Color(0xFF60A5FA),
                softColor: Color(0xFFEFF6FF),
              ),
            ];

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: metrics
                  .map(
                    (_DashboardMetricData data) => SizedBox(
                      width: cardWidth,
                      child: _DashboardMetric(data: data),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool stacked = constraints.maxWidth < 900;
            final Widget left = const _FoundationPanel();
            final Widget right = const _ExperiencePanel();
            if (stacked) {
              return const Column(
                children: <Widget>[
                  _FoundationPanel(),
                  SizedBox(height: 14),
                  _ExperiencePanel(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 6, child: left),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: right),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({required this.user, this.onOpenUsers});

  final AppUser user;
  final VoidCallback? onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        gradient: BackofficeGradients.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: BackofficeShadows.elevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -110,
            right: -65,
            child: Container(
              width: 330,
              height: 330,
              decoration: BoxDecoration(
                color: BackofficePalette.cyan.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            right: 160,
            child: Container(
              width: 290,
              height: 290,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 780;
                final Widget copy = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .98),
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(0xFF0D47C7).withValues(alpha: .12),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Symbols.space_dashboard_rounded,
                            size: 16,
                            color: BackofficePalette.primaryStrong,
                            fill: 1,
                            weight: 650,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'CENTRE DE PILOTAGE IZYTEL',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: BackofficePalette.primaryStrong,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .85,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Bienvenue, ${user.name}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 690),
                      child: Text(
                        'Ton espace IzyTel rassemble progressivement les opérations, les comptes, l’équipe et les finances dans une interface pensée pour le grand écran.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: .86),
                          height: 1.55,
                        ),
                      ),
                    ),
                    if (onOpenUsers != null) ...<Widget>[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _HeroAction(onPressed: onOpenUsers!),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .15),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .20),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Gestion des utilisateurs',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: .96),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );

                final Widget signal = Container(
                  width: compact ? double.infinity : 265,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    border: Border.all(color: Colors.white.withValues(alpha: .20)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Workspace actif',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _SignalRow(
                        icon: Symbols.verified_user_rounded,
                        label: 'Accès',
                        value: 'Sécurisé',
                      ),
                      const SizedBox(height: 12),
                      const _SignalRow(
                        icon: Symbols.devices_rounded,
                        label: 'Expérience',
                        value: 'Web + mobile',
                      ),
                      const SizedBox(height: 12),
                      const _SignalRow(
                        icon: Symbols.hub_rounded,
                        label: 'Données',
                        value: 'Partagées',
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      copy,
                      const SizedBox(height: 26),
                      signal,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: copy),
                    const SizedBox(width: 30),
                    signal,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: BackofficePalette.primaryStrong,
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onPressed,
      icon: const Icon(Symbols.manage_accounts_rounded, size: 20),
      label: const Text('Ouvrir'),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 17,
            color: Colors.white,
            fill: 1,
            weight: 600,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: .76),
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DashboardMetricData {
  const _DashboardMetricData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.color,
    required this.softColor,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Color color;
  final Color softColor;
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.data});

  final _DashboardMetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(19),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.softColor,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(data.icon, color: data.color, size: 22),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: data.color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            data.eyebrow,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: data.color,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 5),
          Text(data.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(data.description, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FoundationPanel extends StatelessWidget {
  const _FoundationPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Fondation du back-office', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Les écrans à venir réutiliseront cette même identité visuelle et les contrats métier existants.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          const _FoundationLine(
            icon: Symbols.apps_rounded,
            title: 'Design system premium',
            subtitle: 'Navigation claire, palette IzyTel, Manrope et composants cohérents.',
          ),
          const SizedBox(height: 14),
          const _FoundationLine(
            icon: Symbols.lock_rounded,
            title: 'Permissions existantes',
            subtitle: 'Admin et Manager voient uniquement les modules autorisés.',
          ),
          const SizedBox(height: 14),
          const _FoundationLine(
            icon: Symbols.autorenew_rounded,
            title: 'Même logique métier',
            subtitle: 'Le Web complète le mobile au lieu de créer une seconde logique.',
          ),
        ],
      ),
    );
  }
}

class _FoundationLine extends StatelessWidget {
  const _FoundationLine({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: BackofficePalette.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExperiencePanel extends StatelessWidget {
  const _ExperiencePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: BackofficeGradients.soft,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(22),
        boxShadow: BackofficeShadows.panel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: BackofficeGradients.brand,
              borderRadius: BorderRadius.circular(15),
              boxShadow: BackofficeShadows.glow,
            ),
            child: const Icon(Symbols.insights_rounded, color: Colors.white),
          ),
          const SizedBox(height: 22),
          Text('Une seule signature visuelle', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Les prochains écrans Commandes, Paiements, Agents et Finance partiront de cette base : dense sur desktop, claire sur tablette et confortable sur mobile.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _TinyChip('Desktop'),
              _TinyChip('Tablette'),
              _TinyChip('Mobile'),
              _TinyChip('Responsive'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
