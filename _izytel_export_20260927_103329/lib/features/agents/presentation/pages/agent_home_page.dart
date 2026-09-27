import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_issues_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentHomePage extends StatelessWidget {
  const AgentHomePage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.agentRepository,
    required this.onOpenOrders,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onOpenActivity,
    required this.onOpenCommissions,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenCommissions;

  String get _firstName {
    final String name = user.name.trim();
    if (name.isEmpty) return 'Agent';
    return name.split(RegExp(r'\s+')).first;
  }

  void _openIssues(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            AgentIssuesPage(agentId: user.id, repository: agentRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<AgentProfile?>(
          stream: agentRepository.watchAgentProfile(user.id),
          builder: (BuildContext context, AsyncSnapshot<AgentProfile?> profileSnapshot) {
            final AgentProfile? profile = profileSnapshot.data;
            return StreamBuilder<List<QueueOrder>>(
              stream: ordersRepository.watchAssignedOrders(agentId: user.id),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<QueueOrder>> orderSnapshot,
                  ) {
                    final List<QueueOrder> orders =
                        orderSnapshot.data ?? const <QueueOrder>[];
                    return StreamBuilder<List<AgentIssue>>(
                      stream: agentRepository.watchAgentIssues(user.id),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<AgentIssue>> issueSnapshot,
                          ) {
                            final List<AgentIssue> issues =
                                issueSnapshot.data ?? const <AgentIssue>[];
                            final int toAccept = orders.where((
                              QueueOrder order,
                            ) {
                              return order.status ==
                                      QueueOrderStatus.paidReady &&
                                  order.assignmentStatus ==
                                      OrderAssignmentStatus.assigned;
                            }).length;
                            final int inProgress = orders.where((
                              QueueOrder order,
                            ) {
                              return order.status ==
                                      QueueOrderStatus.inProgress ||
                                  order.status == QueueOrderStatus.onHold ||
                                  (order.status == QueueOrderStatus.paidReady &&
                                      order.assignmentStatus ==
                                          OrderAssignmentStatus.accepted);
                            }).length;
                            final int completed = orders.where((
                              QueueOrder order,
                            ) {
                              return order.status ==
                                      QueueOrderStatus.completed ||
                                  order.status ==
                                      QueueOrderStatus
                                          .awaitingCustomerConfirmation;
                            }).length;
                            final int openIssues = issues.where((
                              AgentIssue issue,
                            ) {
                              return issue.status == 'open' ||
                                  issue.status == 'in_progress' ||
                                  issue.status == 'acknowledged';
                            }).length;

                            return RefreshIndicator(
                              onRefresh: () async {
                                await Future<void>.delayed(
                                  const Duration(milliseconds: 220),
                                );
                              },
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  IzyTelSpacing.lg,
                                  IzyTelSpacing.md,
                                  IzyTelSpacing.lg,
                                  IzyTelSpacing.xxl,
                                ),
                                children: <Widget>[
                                  _HomeHeader(
                                    agentId: user.id,
                                    firstName: _firstName,
                                    userName: user.name,
                                    availability: profile?.availability,
                                    repository: agentRepository,
                                    onOpenProfile: onOpenProfile,
                                  ),
                                  const SizedBox(height: IzyTelSpacing.xl),
                                  _PriorityActionCard(
                                    toAccept: toAccept,
                                    inProgress: inProgress,
                                    onOpenOrders: onOpenOrders,
                                  ),
                                  const SizedBox(height: IzyTelSpacing.lg),
                                  _OperationalSummary(
                                    toAccept: toAccept,
                                    inProgress: inProgress,
                                    completed: completed,
                                  ),
                                  const SizedBox(height: IzyTelSpacing.xl),
                                  const IzyTelSectionHeader(title: 'Mon suivi'),
                                  const SizedBox(height: IzyTelSpacing.sm),
                                  IzyTelSurface(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        IzyTelMenuRow(
                                          icon: Symbols.insights_rounded,
                                          title: 'Mon activité détaillée',
                                          subtitle:
                                              'Performances, commandes, capacités et mouvements.',
                                          iconColor: IzyTelColors.primary,
                                          onTap: onOpenActivity,
                                        ),
                                        const Divider(height: 1),
                                        IzyTelMenuRow(
                                          icon: Symbols
                                              .account_balance_wallet_rounded,
                                          title: 'Mes commissions',
                                          subtitle:
                                              'Consulter mon solde, mes gains et mes versements.',
                                          iconColor: IzyTelColors.success,
                                          onTap: onOpenCommissions,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (openIssues > 0) ...<Widget>[
                                    const SizedBox(height: IzyTelSpacing.xl),
                                    const IzyTelSectionHeader(
                                      title: 'À surveiller',
                                    ),
                                    const SizedBox(height: IzyTelSpacing.sm),
                                    IzyTelSurface(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      child: IzyTelMenuRow(
                                        icon: Symbols.support_agent_rounded,
                                        title: 'Mes signalements',
                                        subtitle:
                                            'Suivre les incidents actuellement en cours de traitement.',
                                        badge: '$openIssues',
                                        iconColor: IzyTelColors.warning,
                                        onTap: () => _openIssues(context),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: IzyTelSpacing.xl),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: onOpenHistory,
                                          icon: const Icon(
                                            Symbols.history_rounded,
                                          ),
                                          label: const Text('Historique'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: onOpenProfile,
                                          icon: const Icon(
                                            Symbols.person_rounded,
                                          ),
                                          label: const Text('Profil'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                    );
                  },
            );
          },
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.agentId,
    required this.firstName,
    required this.userName,
    required this.availability,
    required this.repository,
    required this.onOpenProfile,
  });

  final String agentId;
  final String firstName;
  final String userName;
  final AgentAvailability? availability;
  final AgentRepository repository;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = availability == AgentAvailability.available;
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Bonjour $firstName 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isAvailable
                          ? IzyTelColors.success
                          : IzyTelColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    availability?.label ?? 'Statut en cours de chargement',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: IzyTelColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _AgentHomeAvatar(
          agentId: agentId,
          userName: userName,
          repository: repository,
          onTap: onOpenProfile,
        ),
      ],
    );
  }
}

class _AgentHomeAvatar extends StatefulWidget {
  const _AgentHomeAvatar({
    required this.agentId,
    required this.userName,
    required this.repository,
    required this.onTap,
  });

  final String agentId;
  final String userName;
  final AgentRepository repository;
  final VoidCallback onTap;

  @override
  State<_AgentHomeAvatar> createState() => _AgentHomeAvatarState();
}

class _AgentHomeAvatarState extends State<_AgentHomeAvatar> {
  StreamSubscription<AgentPersonalProfile?>? _subscription;
  String? _avatarUrl;
  int _resolveGeneration = 0;

  @override
  void initState() {
    super.initState();
    _bindPersonalProfile();
  }

  @override
  void didUpdateWidget(covariant _AgentHomeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agentId != widget.agentId ||
        oldWidget.repository != widget.repository) {
      _bindPersonalProfile();
    }
  }

  void _bindPersonalProfile() {
    unawaited(_subscription?.cancel());
    _avatarUrl = null;
    _subscription = widget.repository
        .watchPersonalProfile(widget.agentId)
        .listen(
          (AgentPersonalProfile? profile) {
            final String? path = profile?.avatarStoragePath?.trim();
            if (path == null || path.isEmpty) {
              _resolveGeneration++;
              if (mounted && _avatarUrl != null) {
                setState(() => _avatarUrl = null);
              }
              return;
            }
            unawaited(_resolveAvatar(path));
          },
          onError: (_) {
            _resolveGeneration++;
            if (mounted && _avatarUrl != null) {
              setState(() => _avatarUrl = null);
            }
          },
        );
  }

  Future<void> _resolveAvatar(String path) async {
    final int generation = ++_resolveGeneration;
    final String? resolved = await widget.repository.resolvePersonalFileUrl(
      path,
    );
    if (!mounted || generation != _resolveGeneration) return;
    setState(() => _avatarUrl = resolved);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelAvatar(
      name: widget.userName,
      imageUrl: _avatarUrl,
      onTap: widget.onTap,
    );
  }
}

class _PriorityActionCard extends StatelessWidget {
  const _PriorityActionCard({
    required this.toAccept,
    required this.inProgress,
    required this.onOpenOrders,
  });

  final int toAccept;
  final int inProgress;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final bool hasPending = toAccept > 0;
    return Container(
      padding: const EdgeInsets.all(IzyTelSpacing.lg),
      decoration: BoxDecoration(
        color: hasPending ? IzyTelColors.primary : IzyTelColors.surface,
        borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
        border: hasPending ? null : Border.all(color: IzyTelColors.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
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
                  color: hasPending
                      ? Colors.white.withAlpha(32)
                      : IzyTelColors.warningSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  hasPending
                      ? Symbols.notifications_active_rounded
                      : Symbols.check_circle_rounded,
                  color: hasPending ? Colors.white : IzyTelColors.success,
                ),
              ),
              const Spacer(),
              if (hasPending)
                Text(
                  '$toAccept en attente',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withAlpha(225),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasPending
                ? '$toAccept commande${toAccept > 1 ? 's' : ''} à accepter'
                : inProgress > 0
                ? '$inProgress commande${inProgress > 1 ? 's' : ''} en cours'
                : 'Aucune commande urgente',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: hasPending ? Colors.white : IzyTelColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasPending
                ? 'Les nouvelles affectations attendent ta réponse.'
                : 'Tu es à jour. Consulte ta file pour voir le détail de tes commandes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: hasPending
                  ? Colors.white.withAlpha(220)
                  : IzyTelColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: hasPending
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: IzyTelColors.primary,
                    ),
                    onPressed: onOpenOrders,
                    icon: const Icon(Symbols.arrow_forward_rounded),
                    label: const Text('Voir les commandes'),
                  )
                : OutlinedButton.icon(
                    onPressed: onOpenOrders,
                    icon: const Icon(Symbols.receipt_long_rounded),
                    label: const Text('Ouvrir mes commandes'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OperationalSummary extends StatelessWidget {
  const _OperationalSummary({
    required this.toAccept,
    required this.inProgress,
    required this.completed,
  });

  final int toAccept;
  final int inProgress;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryItem(
              value: '$toAccept',
              label: 'À accepter',
              valueColor: IzyTelColors.warning,
            ),
          ),
          const SizedBox(height: 42, child: VerticalDivider(width: 1)),
          Expanded(
            child: _SummaryItem(
              value: '$inProgress',
              label: 'En cours',
              valueColor: IzyTelColors.primary,
            ),
          ),
          const SizedBox(height: 42, child: VerticalDivider(width: 1)),
          Expanded(
            child: _SummaryItem(
              value: '$completed',
              label: 'Terminées',
              valueColor: IzyTelColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: IzyTelColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
