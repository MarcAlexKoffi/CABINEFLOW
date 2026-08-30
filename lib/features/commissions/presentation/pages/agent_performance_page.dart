import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/commissions/domain/services/commission_performance_calculator.dart';
import 'package:cabine_flow/features/commissions/presentation/widgets/commission_payout_sheet.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

class AgentPerformancePage extends StatefulWidget {
  const AgentPerformancePage({
    super.key,
    required this.user,
    required this.repository,
    this.agent,
  });

  final AppUser user;
  final CommissionRepository repository;
  final AgentDirectoryEntry? agent;

  bool get isAdminView => agent != null;
  String get agentId => agent?.userId ?? user.id;
  String get agentName => agent?.name ?? user.name;

  @override
  State<AgentPerformancePage> createState() => _AgentPerformancePageState();
}

class _AgentPerformancePageState extends State<AgentPerformancePage> {
  CommissionPeriod _period = CommissionPeriod.thisMonth;

  Future<void> _openPayout(AgentPerformanceSnapshot performance) async {
    if (!widget.isAdminView || performance.commissionBalance <= 0) return;
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return CommissionPayoutSheet(
          user: widget.user,
          repository: widget.repository,
          agentId: widget.agentId,
          agentName: widget.agentName,
          availableBalance: performance.commissionBalance,
        );
      },
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Paiement de commission enregistré.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final String agentId = widget.agentId;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isAdminView ? 'Performance Agent' : 'Mes performances',
        ),
      ),
      body: StreamBuilder<List<CommissionEntry>>(
        stream: widget.repository.watchCommissions(agentId: agentId),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<CommissionEntry>> commissionSnapshot,
            ) {
              return StreamBuilder<List<CommissionPayout>>(
                stream: widget.repository.watchPayouts(agentId: agentId),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<CommissionPayout>> payoutSnapshot,
                    ) {
                      return StreamBuilder<List<AgentAssignmentMetric>>(
                        stream: widget.repository.watchAssignmentMetrics(
                          agentId: agentId,
                        ),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<List<AgentAssignmentMetric>>
                              assignmentSnapshot,
                            ) {
                              return StreamBuilder<List<AgentProcessingMetric>>(
                                stream: widget.repository
                                    .watchProcessingMetrics(agentId: agentId),
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<List<AgentProcessingMetric>>
                                      processingSnapshot,
                                    ) {
                                      return StreamBuilder<
                                        List<AgentOrderMetric>
                                      >(
                                        stream: widget.repository
                                            .watchOrderMetrics(
                                              agentId: agentId,
                                            ),
                                        builder:
                                            (
                                              BuildContext context,
                                              AsyncSnapshot<
                                                List<AgentOrderMetric>
                                              >
                                              orderSnapshot,
                                            ) {
                                              final bool waiting =
                                                  commissionSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting ||
                                                  payoutSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting ||
                                                  assignmentSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting ||
                                                  processingSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting ||
                                                  orderSnapshot
                                                          .connectionState ==
                                                      ConnectionState.waiting;
                                              final bool hasError =
                                                  commissionSnapshot.hasError ||
                                                  payoutSnapshot.hasError ||
                                                  assignmentSnapshot.hasError ||
                                                  processingSnapshot.hasError ||
                                                  orderSnapshot.hasError;
                                              if (waiting &&
                                                  !commissionSnapshot.hasData &&
                                                  !assignmentSnapshot.hasData) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator(),
                                                );
                                              }
                                              if (hasError) {
                                                return const _StateMessage(
                                                  icon: Icons
                                                      .error_outline_rounded,
                                                  title:
                                                      'Données indisponibles',
                                                  message:
                                                      'Impossible de charger les performances pour le moment.',
                                                );
                                              }

                                              final List<CommissionEntry>
                                              commissions =
                                                  commissionSnapshot.data ??
                                                  const <CommissionEntry>[];
                                              final List<CommissionPayout>
                                              payouts =
                                                  payoutSnapshot.data ??
                                                  const <CommissionPayout>[];
                                              final List<AgentAssignmentMetric>
                                              assignments =
                                                  assignmentSnapshot.data ??
                                                  const <
                                                    AgentAssignmentMetric
                                                  >[];
                                              final List<AgentProcessingMetric>
                                              processing =
                                                  processingSnapshot.data ??
                                                  const <
                                                    AgentProcessingMetric
                                                  >[];
                                              final List<AgentOrderMetric>
                                              orderMetrics =
                                                  orderSnapshot.data ??
                                                  const <AgentOrderMetric>[];
                                              final AgentPerformanceSnapshot
                                              performance =
                                                  CommissionPerformanceCalculator.build(
                                                    agentId: agentId,
                                                    period: _period,
                                                    commissions: commissions,
                                                    payouts: payouts,
                                                    assignments: assignments,
                                                    processingEvents:
                                                        processing,
                                                    orderMetrics: orderMetrics,
                                                  );

                                              return _buildContent(
                                                performance: performance,
                                                commissions: commissions,
                                                payouts: payouts,
                                              );
                                            },
                                      );
                                    },
                              );
                            },
                      );
                    },
              );
            },
      ),
    );
  }

  Widget _buildContent({
    required AgentPerformanceSnapshot performance,
    required List<CommissionEntry> commissions,
    required List<CommissionPayout> payouts,
  }) {
    final AgentDirectoryEntry? agent = widget.agent;
    final List<CommissionEntry> recentCommissions = commissions
        .take(8)
        .toList(growable: false);
    final List<CommissionPayout> recentPayouts = payouts
        .take(5)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        if (widget.isAdminView && agent != null)
          _AgentIdentityCard(agent: agent),
        if (widget.isAdminView) const SizedBox(height: 18),
        _PeriodSelector(
          selected: _period,
          onChanged: (CommissionPeriod period) =>
              setState(() => _period = period),
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.query_stats_rounded,
          title: widget.isAdminView ? 'Performances' : 'Mes performances',
        ),
        const SizedBox(height: 10),
        _PrimaryMetricCard(
          label: 'MONTANT TOTAL TRAITÉ',
          value: formatCfa(performance.amountProcessed),
          helper:
              '${performance.transactionsSuccessful} transaction(s) réussie(s)',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'TAUX DE RÉUSSITE',
                value:
                    '${(performance.successRate * 100).toStringAsFixed(1)} %',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'TEMPS MOYEN',
                value: _formatDuration(performance.averageProcessingDuration),
                icon: Icons.timer_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _TransactionsCard(performance: performance),
        const SizedBox(height: 22),
        const _SectionTitle(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Commissions',
        ),
        const SizedBox(height: 10),
        _CommissionSummaryCard(
          performance: performance,
          isAdminView: widget.isAdminView,
          onPay: performance.commissionBalance > 0 && widget.isAdminView
              ? () => _openPayout(performance)
              : null,
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          icon: Icons.history_rounded,
          title: 'Dernières commissions',
        ),
        const SizedBox(height: 10),
        if (recentCommissions.isEmpty)
          const _EmptyCard(message: 'Aucune commission acquise pour le moment.')
        else
          _RecentCommissionList(values: recentCommissions),
        if (recentPayouts.isNotEmpty) ...[
          const SizedBox(height: 22),
          const _SectionTitle(
            icon: Icons.payments_outlined,
            title: 'Historique des paiements',
          ),
          const SizedBox(height: 10),
          _RecentPayoutList(values: recentPayouts),
        ],
      ],
    );
  }
}

class _AgentIdentityCard extends StatelessWidget {
  const _AgentIdentityCard({required this.agent});

  final AgentDirectoryEntry agent;

  @override
  Widget build(BuildContext context) {
    final AgentProfile? profile = agent.profile;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withAlpha(45),
                child: Text(
                  _initials(agent.name),
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          agent.name,
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        _StatusPill(active: agent.isActive),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile == null
                          ? 'Profil opérationnel à compléter'
                          : '${profile.zoneIds.length} zone(s) assignée(s)',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile != null && profile.authorizedNetworks.isNotEmpty) ...[
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 7,
              children: profile.authorizedNetworks
                  .map(
                    (AgentNetwork network) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _agentNetworkColor(network),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          network.label,
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});

  final CommissionPeriod selected;
  final ValueChanged<CommissionPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: CommissionPeriod.values
            .map((CommissionPeriod period) {
              final bool active = period == selected;
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onChanged(period),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary.withAlpha(55)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active
                            ? AppColors.primaryContainer
                            : AppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PrimaryMetricCard extends StatelessWidget {
  const _PrimaryMetricCard({
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricLabel(label),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryContainer,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricLabel(label),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                icon,
                color: iconColor ?? AppColors.primaryContainer,
                size: 22,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionsCard extends StatelessWidget {
  const _TransactionsCard({required this.performance});

  final AgentPerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final int total = performance.transactionsReceived;
    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _MetricLabel('TRANSACTIONS REÇUES')),
              Text(
                '$total',
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Row(
              children: [
                _ProgressSegment(
                  value: performance.transactionsSuccessful,
                  total: total,
                  color: AppColors.success,
                ),
                _ProgressSegment(
                  value: performance.transactionsOther,
                  total: total,
                  color: AppColors.primary,
                ),
                _ProgressSegment(
                  value: performance.transactionsRefused,
                  total: total,
                  color: AppColors.warningContainer,
                ),
                _ProgressSegment(
                  value: performance.transactionsFailed,
                  total: total,
                  color: AppColors.error,
                ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 14,
            runSpacing: 9,
            children: [
              _Legend(
                color: AppColors.success,
                label: 'Réussies',
                value: performance.transactionsSuccessful,
              ),
              _Legend(
                color: AppColors.primary,
                label: 'En attente',
                value: performance.transactionsOther,
              ),
              _Legend(
                color: AppColors.warningContainer,
                label: 'Refusées',
                value: performance.transactionsRefused,
              ),
              _Legend(
                color: AppColors.error,
                label: 'Échouées',
                value: performance.transactionsFailed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({
    required this.value,
    required this.total,
    required this.color,
  });

  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final int flex = total <= 0
        ? 0
        : (value * 1000 ~/ total).clamp(0, 1000).toInt();
    if (flex <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: flex,
      child: Container(height: 8, color: color),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label : $value',
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CommissionSummaryCard extends StatelessWidget {
  const _CommissionSummaryCard({
    required this.performance,
    required this.isAdminView,
    this.onPay,
  });

  final AgentPerformanceSnapshot performance;
  final bool isAdminView;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primaryContainer,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Règle actuelle : ${CommissionPolicy.current.label}',
                    style: const TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Les performances historiques restent visibles, mais seules les transactions réussies depuis l’activation des commissions génèrent une rémunération.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _ValueRow(
            label: 'Générée sur la période',
            value: formatCfa(performance.commissionGeneratedInPeriod),
          ),
          const Divider(height: 22),
          _ValueRow(
            label: 'Payée sur la période',
            value: formatCfa(performance.commissionPaidInPeriod),
          ),
          const Divider(height: 22),
          _ValueRow(
            label: 'Commission totale acquise',
            value: formatCfa(performance.totalCommissionEarned),
          ),
          const Divider(height: 22),
          _ValueRow(
            label: 'Commission totale payée',
            value: formatCfa(performance.totalCommissionPaid),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(90)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isAdminView ? 'Solde à payer' : 'À recevoir',
                    style: const TextStyle(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  formatCfa(performance.commissionBalance),
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onPay != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Enregistrer un paiement'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentCommissionList extends StatelessWidget {
  const _RecentCommissionList({required this.values});

  final List<CommissionEntry> values;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: values
            .asMap()
            .entries
            .map((MapEntry<int, CommissionEntry> entry) {
              final CommissionEntry value = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        _NetworkDot(network: value.network),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value.orderReference,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.onBackground,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_networkLabel(value.network)} • ${_formatShortDate(value.earnedAt)}',
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCfa(value.orderAmount),
                              style: const TextStyle(
                                color: AppColors.onBackground,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '+${formatCfa(value.commissionAmount)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (entry.key != values.length - 1)
                    const Divider(height: 1, indent: 14, endIndent: 14),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _RecentPayoutList extends StatelessWidget {
  const _RecentPayoutList({required this.values});

  final List<CommissionPayout> values;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: values
            .asMap()
            .entries
            .map((entry) {
              final CommissionPayout value = entry.value;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.wave,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                value.paymentReference,
                                style: const TextStyle(
                                  color: AppColors.onBackground,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${_formatShortDate(value.paidAt)} • ${value.createdByName}',
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatCfa(value.amount),
                          style: const TextStyle(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.key != values.length - 1)
                    const Divider(height: 1, indent: 14, endIndent: 14),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  const _BaseCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
  }
}

class _MetricLabel extends StatelessWidget {
  const _MetricLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: .35,
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.onBackground,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NetworkDot extends StatelessWidget {
  const _NetworkDot({required this.network});
  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: _networkColor(network),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? AppColors.success : AppColors.error).withAlpha(30),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        active ? 'Agent actif' : 'Agent suspendu',
        style: TextStyle(
          color: active ? AppColors.success : AppColors.error,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.onSurfaceVariant, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

Color _networkColor(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return AppColors.orange;
    case MobileNetwork.mtn:
      return AppColors.mtn;
    case MobileNetwork.moov:
      return AppColors.moov;
  }
}

Color _agentNetworkColor(AgentNetwork network) {
  switch (network) {
    case AgentNetwork.orange:
      return AppColors.orange;
    case AgentNetwork.mtn:
      return AppColors.mtn;
    case AgentNetwork.moov:
      return AppColors.moov;
  }
}

String _networkLabel(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'Orange';
    case MobileNetwork.mtn:
      return 'MTN';
    case MobileNetwork.moov:
      return 'Moov';
  }
}

String _formatDuration(Duration? value) {
  if (value == null) return '—';
  final int minutes = value.inMinutes;
  final int seconds = value.inSeconds.remainder(60);
  if (minutes <= 0) return '${seconds}s';
  return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
}

String _formatShortDate(DateTime value) {
  final DateTime now = DateTime.now();
  final bool today =
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  if (today) {
    return 'Aujourd’hui ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

String _initials(String name) {
  final List<String> words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
      .toUpperCase();
}
