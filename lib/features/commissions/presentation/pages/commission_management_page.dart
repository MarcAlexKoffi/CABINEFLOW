import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/commissions/domain/services/commission_performance_calculator.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_performance_page.dart';
import 'package:flutter/material.dart';

enum _CommissionAgentFilter { all, toPay, paid }

class CommissionManagementPage extends StatefulWidget {
  const CommissionManagementPage({
    super.key,
    required this.user,
    required this.repository,
    required this.agentRepository,
  });

  final AppUser user;
  final CommissionRepository repository;
  final AgentRepository agentRepository;

  @override
  State<CommissionManagementPage> createState() =>
      _CommissionManagementPageState();
}

class _CommissionManagementPageState extends State<CommissionManagementPage> {
  CommissionPeriod _period = CommissionPeriod.thisMonth;
  _CommissionAgentFilter _filter = _CommissionAgentFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Commissions')),
      body: StreamBuilder<List<AgentDirectoryEntry>>(
        stream: widget.agentRepository.watchAgents(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<AgentDirectoryEntry>> agentSnapshot,
            ) {
              return StreamBuilder<List<CommissionEntry>>(
                stream: widget.repository.watchCommissions(),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<CommissionEntry>> commissionSnapshot,
                    ) {
                      return StreamBuilder<List<CommissionPayout>>(
                        stream: widget.repository.watchPayouts(),
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<List<CommissionPayout>>
                              payoutSnapshot,
                            ) {
                              return StreamBuilder<List<CommissionAccount>>(
                                stream: widget.repository.watchAccounts(),
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<List<CommissionAccount>>
                                      accountSnapshot,
                                    ) {
                                      return StreamBuilder<
                                        List<AgentAssignmentMetric>
                                      >(
                                        stream: widget.repository
                                            .watchAssignmentMetrics(),
                                        builder:
                                            (
                                              BuildContext context,
                                              AsyncSnapshot<
                                                List<AgentAssignmentMetric>
                                              >
                                              assignmentSnapshot,
                                            ) {
                                              return StreamBuilder<
                                                List<AgentProcessingMetric>
                                              >(
                                                stream: widget.repository
                                                    .watchProcessingMetrics(),
                                                builder:
                                                    (
                                                      BuildContext context,
                                                      AsyncSnapshot<
                                                        List<
                                                          AgentProcessingMetric
                                                        >
                                                      >
                                                      processingSnapshot,
                                                    ) {
                                                      return StreamBuilder<
                                                        List<AgentOrderMetric>
                                                      >(
                                                        stream: widget
                                                            .repository
                                                            .watchOrderMetrics(),
                                                        builder:
                                                            (
                                                              BuildContext
                                                              context,
                                                              AsyncSnapshot<
                                                                List<
                                                                  AgentOrderMetric
                                                                >
                                                              >
                                                              orderSnapshot,
                                                            ) {
                                                              final bool
                                                              hasAnyError =
                                                                  agentSnapshot
                                                                      .hasError ||
                                                                  commissionSnapshot
                                                                      .hasError ||
                                                                  payoutSnapshot
                                                                      .hasError ||
                                                                  accountSnapshot
                                                                      .hasError ||
                                                                  assignmentSnapshot
                                                                      .hasError ||
                                                                  processingSnapshot
                                                                      .hasError ||
                                                                  orderSnapshot
                                                                      .hasError;
                                                              final bool
                                                              waiting =
                                                                  agentSnapshot
                                                                          .connectionState ==
                                                                      ConnectionState
                                                                          .waiting ||
                                                                  commissionSnapshot
                                                                          .connectionState ==
                                                                      ConnectionState
                                                                          .waiting;
                                                              if (waiting &&
                                                                  !agentSnapshot
                                                                      .hasData &&
                                                                  !commissionSnapshot
                                                                      .hasData) {
                                                                return const Center(
                                                                  child:
                                                                      CircularProgressIndicator(),
                                                                );
                                                              }
                                                              if (hasAnyError) {
                                                                return const _PageState(
                                                                  icon: Icons
                                                                      .error_outline_rounded,
                                                                  title:
                                                                      'Commissions indisponibles',
                                                                  message:
                                                                      'Impossible de charger les données de commission pour le moment.',
                                                                );
                                                              }

                                                              final List<
                                                                AgentDirectoryEntry
                                                              >
                                                              agents =
                                                                  agentSnapshot
                                                                      .data ??
                                                                  const <
                                                                    AgentDirectoryEntry
                                                                  >[];
                                                              final List<
                                                                CommissionEntry
                                                              >
                                                              commissions =
                                                                  commissionSnapshot
                                                                      .data ??
                                                                  const <
                                                                    CommissionEntry
                                                                  >[];
                                                              final List<
                                                                CommissionPayout
                                                              >
                                                              payouts =
                                                                  payoutSnapshot
                                                                      .data ??
                                                                  const <
                                                                    CommissionPayout
                                                                  >[];
                                                              final List<
                                                                CommissionAccount
                                                              >
                                                              accounts =
                                                                  accountSnapshot
                                                                      .data ??
                                                                  const <
                                                                    CommissionAccount
                                                                  >[];
                                                              final List<
                                                                AgentAssignmentMetric
                                                              >
                                                              assignments =
                                                                  assignmentSnapshot
                                                                      .data ??
                                                                  const <
                                                                    AgentAssignmentMetric
                                                                  >[];
                                                              final List<
                                                                AgentProcessingMetric
                                                              >
                                                              processing =
                                                                  processingSnapshot
                                                                      .data ??
                                                                  const <
                                                                    AgentProcessingMetric
                                                                  >[];
                                                              final List<
                                                                AgentOrderMetric
                                                              >
                                                              orderMetrics =
                                                                  orderSnapshot
                                                                      .data ??
                                                                  const <
                                                                    AgentOrderMetric
                                                                  >[];

                                                              return _buildContent(
                                                                agents: agents,
                                                                commissions:
                                                                    commissions,
                                                                payouts:
                                                                    payouts,
                                                                accounts:
                                                                    accounts,
                                                                assignments:
                                                                    assignments,
                                                                processing:
                                                                    processing,
                                                                orderMetrics:
                                                                    orderMetrics,
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
                      );
                    },
              );
            },
      ),
    );
  }

  Widget _buildContent({
    required List<AgentDirectoryEntry> agents,
    required List<CommissionEntry> commissions,
    required List<CommissionPayout> payouts,
    required List<CommissionAccount> accounts,
    required List<AgentAssignmentMetric> assignments,
    required List<AgentProcessingMetric> processing,
    required List<AgentOrderMetric> orderMetrics,
  }) {
    final DateTime now = DateTime.now();
    final List<CommissionEntry> periodCommissions = commissions
        .where(
          (CommissionEntry value) => _period.contains(value.earnedAt, now: now),
        )
        .toList(growable: false);
    final List<CommissionPayout> periodPayouts = payouts
        .where(
          (CommissionPayout value) => _period.contains(value.paidAt, now: now),
        )
        .toList(growable: false);
    final int generated = periodCommissions.fold<int>(
      0,
      (int total, CommissionEntry value) => total + value.commissionAmount,
    );
    final int paidInPeriod = periodPayouts.fold<int>(
      0,
      (int total, CommissionPayout value) => total + value.amount,
    );
    final int outstanding = accounts.fold<int>(
      0,
      (int total, CommissionAccount value) =>
          total + value.balance.clamp(0, value.earnedTotal).toInt(),
    );

    final Map<String, CommissionAccount> accountByAgent =
        <String, CommissionAccount>{
          for (final CommissionAccount value in accounts) value.agentId: value,
        };

    final List<_AgentRowData> rows =
        agents
            .map((AgentDirectoryEntry agent) {
              final AgentPerformanceSnapshot performance =
                  CommissionPerformanceCalculator.build(
                    agentId: agent.userId,
                    period: _period,
                    commissions: commissions,
                    payouts: payouts,
                    assignments: assignments,
                    processingEvents: processing,
                    orderMetrics: orderMetrics,
                    now: now,
                  );
              final CommissionAccount? account = accountByAgent[agent.userId];
              return _AgentRowData(
                agent: agent,
                performance: performance,
                allTimeEarned:
                    account?.earnedTotal ?? performance.totalCommissionEarned,
                allTimePaid:
                    account?.paidTotal ?? performance.totalCommissionPaid,
                balance:
                    account?.balance.clamp(0, account.earnedTotal).toInt() ??
                    performance.commissionBalance,
              );
            })
            .where(_matchesFilter)
            .toList(growable: false)
          ..sort((a, b) {
            if (a.balance != b.balance) return b.balance.compareTo(a.balance);
            return a.agent.name.toLowerCase().compareTo(
              b.agent.name.toLowerCase(),
            );
          });

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        const Text(
          'Suivi des commissions des agents',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 15),
        _PeriodDropdown(
          value: _period,
          onChanged: (CommissionPeriod value) =>
              setState(() => _period = value),
        ),
        const SizedBox(height: 18),
        _BigStatCard(
          label: 'COMMISSIONS GÉNÉRÉES',
          value: formatCfa(generated),
          accent: AppColors.primaryContainer,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BigStatCard(
                label: 'SOLDE À PAYER',
                value: formatCfa(outstanding),
                accent: AppColors.error,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BigStatCard(
                label: 'PAYÉ SUR LA PÉRIODE',
                value: formatCfa(paidInPeriod),
                accent: AppColors.onBackground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BigStatCard(
          label: 'TRANSACTIONS RÉMUNÉRÉES',
          value: '${periodCommissions.length}',
          accent: AppColors.onBackground,
        ),
        const SizedBox(height: 18),
        _FilterBar(
          value: _filter,
          onChanged: (value) => setState(() => _filter = value),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const _PageState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Aucun agent dans ce filtre',
            message:
                'Les commissions apparaîtront automatiquement après les transactions réussies.',
            compact: true,
          )
        else
          ...rows.map(
            (_AgentRowData row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AgentCommissionCard(
                data: row,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => AgentPerformancePage(
                        user: widget.user,
                        repository: widget.repository,
                        agent: row.agent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  bool _matchesFilter(_AgentRowData row) {
    switch (_filter) {
      case _CommissionAgentFilter.all:
        return true;
      case _CommissionAgentFilter.toPay:
        return row.balance > 0;
      case _CommissionAgentFilter.paid:
        return row.allTimeEarned > 0 && row.balance == 0;
    }
  }
}

class _AgentRowData {
  const _AgentRowData({
    required this.agent,
    required this.performance,
    required this.allTimeEarned,
    required this.allTimePaid,
    required this.balance,
  });

  final AgentDirectoryEntry agent;
  final AgentPerformanceSnapshot performance;
  final int allTimeEarned;
  final int allTimePaid;
  final int balance;
}

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({required this.value, required this.onChanged});

  final CommissionPeriod value;
  final ValueChanged<CommissionPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CommissionPeriod>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceContainerHighest,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: CommissionPeriod.values
              .map(
                (CommissionPeriod period) => DropdownMenuItem<CommissionPeriod>(
                  value: period,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_outlined,
                        size: 17,
                        color: AppColors.primaryContainer,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        period.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (CommissionPeriod? period) {
            if (period != null) onChanged(period);
          },
        ),
      ),
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 105),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .35,
            ),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.value, required this.onChanged});
  final _CommissionAgentFilter value;
  final ValueChanged<_CommissionAgentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <_CommissionAgentFilter, String>{
      _CommissionAgentFilter.all: 'Tous',
      _CommissionAgentFilter.toPay: 'À payer',
      _CommissionAgentFilter.paid: 'Payés',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _CommissionAgentFilter.values
          .map((filter) {
            final bool active = filter == value;
            return ChoiceChip(
              selected: active,
              onSelected: (_) => onChanged(filter),
              label: Text(labels[filter]!),
            );
          })
          .toList(growable: false),
    );
  }
}

class _AgentCommissionCard extends StatelessWidget {
  const _AgentCommissionCard({required this.data, required this.onTap});

  final _AgentRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceContainerHighest,
                child: Text(
                  _initials(data.agent.name),
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.agent.isActive ? 'Agent actif' : 'Agent suspendu',
                      style: TextStyle(
                        color: data.agent.isActive
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'TRANSACTIONS',
                  value: '${data.performance.transactionsSuccessful} réussies',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'GÉNÉRÉE',
                  value: formatCfa(
                    data.performance.commissionGeneratedInPeriod,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'DÉJÀ PAYÉ',
                  value: formatCfa(data.allTimePaid),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'À PAYER',
                  value: formatCfa(data.balance),
                  emphasized: data.balance > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              child: const Text('Voir le détail'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasized
              ? AppColors.error.withAlpha(90)
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: emphasized ? AppColors.warning : AppColors.onBackground,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageState extends StatelessWidget {
  const _PageState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: AppColors.onSurfaceVariant,
              size: compact ? 30 : 42,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
