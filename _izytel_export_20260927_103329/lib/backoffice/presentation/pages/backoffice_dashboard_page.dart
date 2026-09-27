import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficeDashboardSnapshot {
  const BackofficeDashboardSnapshot({
    this.totalOrders = 0,
    this.activeOrders = 0,
    this.completedOrders = 0,
    this.completedAmount = 0,
    this.pendingPayments = 0,
    this.pendingAssignments = 0,
    this.failedOrders = 0,
    this.openSupportRequests = 0,
    this.pendingRefunds = 0,
    this.openAgentIssues = 0,
    this.lastUpdatedAt,
  });

  final int totalOrders;
  final int activeOrders;
  final int completedOrders;
  final int completedAmount;
  final int pendingPayments;
  final int pendingAssignments;
  final int failedOrders;
  final int openSupportRequests;
  final int pendingRefunds;
  final int openAgentIssues;
  final DateTime? lastUpdatedAt;

  int get priorityTotal =>
      pendingPayments +
      pendingAssignments +
      failedOrders +
      openSupportRequests +
      pendingRefunds +
      openAgentIssues;
}

class BackofficeDashboardPage extends StatelessWidget {
  const BackofficeDashboardPage({
    super.key,
    required this.user,
    this.snapshot = const BackofficeDashboardSnapshot(),
    this.onOpenUsers,
    this.onOpenPayments,
    this.onOpenAssignments,
    this.onOpenFailedOrders,
    this.onOpenSupportRequests,
    this.onOpenRefunds,
    this.onOpenAgentIssues,
  });

  final AppUser user;
  final BackofficeDashboardSnapshot snapshot;
  final VoidCallback? onOpenUsers;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenAssignments;
  final VoidCallback? onOpenFailedOrders;
  final VoidCallback? onOpenSupportRequests;
  final VoidCallback? onOpenRefunds;
  final VoidCallback? onOpenAgentIssues;

  @override
  Widget build(BuildContext context) {
    final List<_DashboardMetricData> metrics = <_DashboardMetricData>[
      _DashboardMetricData(
        icon: Symbols.receipt_long_rounded,
        eyebrow: 'COMMANDES',
        value: '${snapshot.totalOrders}',
        title: 'Commandes suivies',
        description:
            '${snapshot.activeOrders} actives • ${snapshot.completedOrders} terminées',
        color: BackofficePalette.primary,
        softColor: const Color(0xFFEAF1FF),
      ),
      _DashboardMetricData(
        icon: Symbols.payments_rounded,
        eyebrow: 'PAIEMENTS',
        value: '${snapshot.pendingPayments}',
        title: 'À vérifier',
        description: snapshot.pendingPayments == 0
            ? 'Aucune validation urgente'
            : 'Validation de paiement requise',
        color: BackofficePalette.warning,
        softColor: const Color(0xFFFFF4DD),
        onTap: onOpenPayments,
      ),
      _DashboardMetricData(
        icon: Symbols.assignment_ind_rounded,
        eyebrow: 'AFFECTATIONS',
        value: '${snapshot.pendingAssignments}',
        title: 'À affecter',
        description: snapshot.pendingAssignments == 0
            ? 'File d’affectation à jour'
            : 'Commandes payées en attente',
        color: BackofficePalette.primary,
        softColor: const Color(0xFFEAF1FF),
        onTap: onOpenAssignments,
      ),
      _DashboardMetricData(
        icon: Symbols.error_rounded,
        eyebrow: 'ÉCHECS',
        value: '${snapshot.failedOrders}',
        title: 'À traiter',
        description: snapshot.failedOrders == 0
            ? 'Aucun échec ouvert'
            : 'Intervention requise',
        color: BackofficePalette.danger,
        softColor: const Color(0xFFFFECEC),
        onTap: onOpenFailedOrders,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _DashboardHero(
          user: user,
          snapshot: snapshot,
          onOpenUsers: onOpenUsers,
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Vue opérationnelle',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            _RealtimeBadge(lastUpdatedAt: snapshot.lastUpdatedAt),
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
            final Widget priorities = _PriorityPanel(
              snapshot: snapshot,
              onOpenPayments: onOpenPayments,
              onOpenAssignments: onOpenAssignments,
              onOpenFailedOrders: onOpenFailedOrders,
              onOpenSupportRequests: onOpenSupportRequests,
              onOpenRefunds: onOpenRefunds,
              onOpenAgentIssues: onOpenAgentIssues,
            );
            final Widget activity = _ActivityPanel(snapshot: snapshot);
            if (constraints.maxWidth < 900) {
              return Column(
                children: <Widget>[
                  priorities,
                  const SizedBox(height: 14),
                  activity,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 6, child: priorities),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: activity),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.user,
    required this.snapshot,
    this.onOpenUsers,
  });

  final AppUser user;
  final BackofficeDashboardSnapshot snapshot;
  final VoidCallback? onOpenUsers;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .94),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'CENTRE DE PILOTAGE IZYTEL',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BackofficePalette.primaryStrong,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .85,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Bienvenue, ${user.name}',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(
                        'Le tableau de bord suit maintenant l’activité opérationnelle réelle : commandes, paiements, affectations, demandes clients, remboursements et incidents.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: .88),
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (onOpenUsers != null) ...<Widget>[
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: BackofficePalette.primaryStrong,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            onPressed: onOpenUsers,
                            icon: const Icon(Symbols.manage_accounts_rounded),
                            label: const Text('Ouvrir'),
                          ),
                          Text(
                            'Gestion des utilisateurs',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );

                final Widget signal = Container(
                  width: compact ? double.infinity : 280,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .20),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _SignalRow(
                        icon: Symbols.sync_rounded,
                        label: 'Synchronisation',
                        value: 'Temps réel',
                      ),
                      const SizedBox(height: 12),
                      _SignalRow(
                        icon: Symbols.priority_high_rounded,
                        label: 'À traiter',
                        value: '${snapshot.priorityTotal}',
                      ),
                      const SizedBox(height: 12),
                      _SignalRow(
                        icon: Symbols.payments_rounded,
                        label: 'Volume terminé',
                        value: formatCfa(snapshot.completedAmount),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'RÉSEAUX',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: .70),
                          fontWeight: FontWeight.w800,
                          letterSpacing: .75,
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(height: 9),
                      const Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: <Widget>[
                          IzyTelOperatorLogo(
                            network: MobileNetwork.orange,
                            size: 28,
                          ),
                          IzyTelOperatorLogo(
                            network: MobileNetwork.mtn,
                            size: 28,
                          ),
                          IzyTelOperatorLogo(
                            network: MobileNetwork.moov,
                            size: 28,
                          ),
                        ],
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

class _RealtimeBadge extends StatelessWidget {
  const _RealtimeBadge({this.lastUpdatedAt});

  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final DateTime? value = lastUpdatedAt;
    final String suffix = value == null
        ? 'Synchronisation…'
        : 'Actualisé à ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return Container(
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
            Symbols.sync_rounded,
            size: 16,
            color: BackofficePalette.success,
          ),
          const SizedBox(width: 6),
          Text(
            suffix,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
          child: Icon(icon, size: 17, color: Colors.white, fill: 1),
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
    required this.value,
    required this.title,
    required this.description,
    required this.color,
    required this.softColor,
    this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String value;
  final String title;
  final String description;
  final Color color;
  final Color softColor;
  final VoidCallback? onTap;
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.data});

  final _DashboardMetricData data;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
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
              Text(
                data.value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: BackofficePalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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

    if (data.onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: data.onTap,
      child: content,
    );
  }
}

class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({
    required this.snapshot,
    this.onOpenPayments,
    this.onOpenAssignments,
    this.onOpenFailedOrders,
    this.onOpenSupportRequests,
    this.onOpenRefunds,
    this.onOpenAgentIssues,
  });

  final BackofficeDashboardSnapshot snapshot;
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenAssignments;
  final VoidCallback? onOpenFailedOrders;
  final VoidCallback? onOpenSupportRequests;
  final VoidCallback? onOpenRefunds;
  final VoidCallback? onOpenAgentIssues;

  @override
  Widget build(BuildContext context) {
    final List<_PriorityData> items = <_PriorityData>[
      _PriorityData(
        icon: Symbols.fact_check_rounded,
        label: 'Paiements à vérifier',
        count: snapshot.pendingPayments,
        onTap: onOpenPayments,
      ),
      _PriorityData(
        icon: Symbols.assignment_ind_rounded,
        label: 'Commandes à affecter',
        count: snapshot.pendingAssignments,
        onTap: onOpenAssignments,
      ),
      _PriorityData(
        icon: Symbols.error_rounded,
        label: 'Commandes échouées',
        count: snapshot.failedOrders,
        onTap: onOpenFailedOrders,
      ),
      _PriorityData(
        icon: Symbols.support_agent_rounded,
        label: 'Demandes clients ouvertes',
        count: snapshot.openSupportRequests,
        onTap: onOpenSupportRequests,
      ),
      _PriorityData(
        icon: Symbols.currency_exchange_rounded,
        label: 'Remboursements à suivre',
        count: snapshot.pendingRefunds,
        onTap: onOpenRefunds,
      ),
      _PriorityData(
        icon: Symbols.report_problem_rounded,
        label: 'Signalements agents ouverts',
        count: snapshot.openAgentIssues,
        onTap: onOpenAgentIssues,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: backofficePanelDecoration(elevated: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Actions prioritaires', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 5),
          Text(
            snapshot.priorityTotal == 0
                ? 'Aucune action urgente détectée.'
                : '${snapshot.priorityTotal} élément${snapshot.priorityTotal > 1 ? 's' : ''} nécessite${snapshot.priorityTotal > 1 ? 'nt' : ''} votre attention.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PriorityTile(data: item),
              )),
        ],
      ),
    );
  }
}

class _PriorityData {
  const _PriorityData({
    required this.icon,
    required this.label,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onTap;
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile({required this.data});

  final _PriorityData data;

  @override
  Widget build(BuildContext context) {
    final bool active = data.count > 0;
    return Material(
      color: active
          ? BackofficePalette.primary.withValues(alpha: .045)
          : BackofficePalette.canvas,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                data.icon,
                size: 20,
                color: active
                    ? BackofficePalette.primary
                    : BackofficePalette.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 34),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? BackofficePalette.primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: active
                      ? null
                      : Border.all(color: BackofficePalette.line),
                ),
                child: Text(
                  '${data.count}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: active ? Colors.white : BackofficePalette.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (data.onTap != null) ...<Widget>[
                const SizedBox(width: 8),
                const Icon(
                  Symbols.chevron_right_rounded,
                  size: 18,
                  color: BackofficePalette.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.snapshot});

  final BackofficeDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final double completionRate = snapshot.totalOrders == 0
        ? 0
        : snapshot.completedOrders / snapshot.totalOrders;
    return Container(
      padding: const EdgeInsets.all(22),
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
            ),
            child: const Icon(Symbols.monitoring_rounded, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text('Activité commandes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          _ActivityLine(label: 'Total suivi', value: '${snapshot.totalOrders}'),
          const SizedBox(height: 10),
          _ActivityLine(label: 'En cours', value: '${snapshot.activeOrders}'),
          const SizedBox(height: 10),
          _ActivityLine(label: 'Terminées', value: '${snapshot.completedOrders}'),
          const SizedBox(height: 10),
          _ActivityLine(
            label: 'Volume terminé',
            value: formatCfa(snapshot.completedAmount),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: completionRate,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.totalOrders == 0
                ? 'Aucune commande à synthétiser pour le moment.'
                : '${(completionRate * 100).round()} % des commandes suivies sont terminées.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
