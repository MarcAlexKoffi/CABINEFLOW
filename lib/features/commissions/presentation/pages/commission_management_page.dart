import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/commissions/domain/services/commission_performance_calculator.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/agent_performance_page.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Commissions',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<AgentDirectoryEntry>>(
        stream: widget.agentRepository.watchAgents(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<AgentDirectoryEntry>> agentSnapshot,
        ) {
          return StreamBuilder<List<CommissionEntry>>(
            stream: widget.repository.watchCommissions(),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<CommissionEntry>> commissionSnapshot,
            ) {
              return StreamBuilder<List<CommissionPayout>>(
                stream: widget.repository.watchPayouts(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<CommissionPayout>> payoutSnapshot,
                ) {
                  return StreamBuilder<List<CommissionAccount>>(
                    stream: widget.repository.watchAccounts(),
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<List<CommissionAccount>> accountSnapshot,
                    ) {
                      return StreamBuilder<List<AgentAssignmentMetric>>(
                        stream: widget.repository.watchAssignmentMetrics(),
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<List<AgentAssignmentMetric>> assignmentSnapshot,
                        ) {
                          return StreamBuilder<List<AgentProcessingMetric>>(
                            stream: widget.repository.watchProcessingMetrics(),
                            builder: (
                              BuildContext context,
                              AsyncSnapshot<List<AgentProcessingMetric>> processingSnapshot,
                            ) {
                              return StreamBuilder<List<AgentOrderMetric>>(
                                stream: widget.repository.watchOrderMetrics(),
                                builder: (
                                  BuildContext context,
                                  AsyncSnapshot<List<AgentOrderMetric>> orderSnapshot,
                                ) {
                                  final bool waiting =
                                      agentSnapshot.connectionState == ConnectionState.waiting &&
                                      commissionSnapshot.connectionState == ConnectionState.waiting &&
                                      !agentSnapshot.hasData &&
                                      !commissionSnapshot.hasData;
                                  if (waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (agentSnapshot.hasError ||
                                      commissionSnapshot.hasError ||
                                      payoutSnapshot.hasError ||
                                      accountSnapshot.hasError ||
                                      assignmentSnapshot.hasError ||
                                      processingSnapshot.hasError ||
                                      orderSnapshot.hasError) {
                                    return const SingleChildScrollView(
                                      child: FinanceEmptyState(
                                        icon: Symbols.cloud_off_rounded,
                                        title: 'Commissions indisponibles',
                                        message: 'Impossible de charger les données de commission pour le moment.',
                                      ),
                                    );
                                  }

                                  return _buildContent(
                                    agents: agentSnapshot.data ?? const <AgentDirectoryEntry>[],
                                    commissions: commissionSnapshot.data ?? const <CommissionEntry>[],
                                    payouts: payoutSnapshot.data ?? const <CommissionPayout>[],
                                    accounts: accountSnapshot.data ?? const <CommissionAccount>[],
                                    assignments: assignmentSnapshot.data ?? const <AgentAssignmentMetric>[],
                                    processing: processingSnapshot.data ?? const <AgentProcessingMetric>[],
                                    orderMetrics: orderSnapshot.data ?? const <AgentOrderMetric>[],
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
        .where((CommissionEntry value) => _period.contains(value.earnedAt, now: now))
        .toList(growable: false);
    final List<CommissionPayout> periodPayouts = payouts
        .where((CommissionPayout value) => _period.contains(value.paidAt, now: now))
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

    final Map<String, CommissionAccount> accountByAgent = <String, CommissionAccount>{
      for (final CommissionAccount value in accounts) value.agentId: value,
    };

    final List<_AgentRowData> rows = agents
        .map((AgentDirectoryEntry agent) {
          final AgentPerformanceSnapshot performance = CommissionPerformanceCalculator.build(
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
            allTimeEarned: account?.earnedTotal ?? performance.totalCommissionEarned,
            allTimePaid: account?.paidTotal ?? performance.totalCommissionPaid,
            balance: account?.balance.clamp(0, account.earnedTotal).toInt() ?? performance.commissionBalance,
          );
        })
        .where(_matchesFilter)
        .toList(growable: false)
      ..sort((_AgentRowData a, _AgentRowData b) {
        if (a.balance != b.balance) return b.balance.compareTo(a.balance);
        return a.agent.name.toLowerCase().compareTo(b.agent.name.toLowerCase());
      });

    final int toPayCount = accounts.where((CommissionAccount value) => value.balance > 0).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      children: [
        Text(
          'Suivi des commissions des agents',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: IzyTelColors.textSecondary,
            fontSize: IzyTelTypeScale.label,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        _PeriodSelector(
          value: _period,
          onChanged: (CommissionPeriod value) => setState(() => _period = value),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: IzyTelColors.primary,
            borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
            boxShadow: [
              BoxShadow(
                color: IzyTelColors.primary.withAlpha(36),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commissions générées',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IzyTelColors.surface.withAlpha(220),
                  fontSize: IzyTelTypeScale.label,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCfaFull(generated),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: IzyTelColors.surface,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${periodCommissions.length} transaction${periodCommissions.length > 1 ? 's' : ''} rémunérée${periodCommissions.length > 1 ? 's' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: IzyTelColors.surface.withAlpha(205),
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: FinancialMetricCard(
                label: 'Solde à payer',
                value: formatCfa(outstanding),
                caption: '$toPayCount agent${toPayCount > 1 ? 's' : ''}',
                icon: Symbols.account_balance_wallet_rounded,
                accent: outstanding > 0 ? IzyTelColors.warning : IzyTelColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FinancialMetricCard(
                label: 'Payé sur la période',
                value: formatCfa(paidInPeriod),
                caption: '${periodPayouts.length} versement${periodPayouts.length > 1 ? 's' : ''}',
                icon: Symbols.payments_rounded,
                accent: IzyTelColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const IzyTelSectionHeader(title: 'Agents'),
        const SizedBox(height: 9),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              FinanceFilterPill(
                label: 'Tous',
                selected: _filter == _CommissionAgentFilter.all,
                onTap: () => setState(() => _filter = _CommissionAgentFilter.all),
              ),
              const SizedBox(width: 7),
              FinanceFilterPill(
                label: 'À payer',
                count: accounts.where((CommissionAccount account) => account.balance > 0).length,
                accent: IzyTelColors.warning,
                selected: _filter == _CommissionAgentFilter.toPay,
                onTap: () => setState(() => _filter = _CommissionAgentFilter.toPay),
              ),
              const SizedBox(width: 7),
              FinanceFilterPill(
                label: 'Payés',
                accent: IzyTelColors.success,
                selected: _filter == _CommissionAgentFilter.paid,
                onTap: () => setState(() => _filter = _CommissionAgentFilter.paid),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const FinanceEmptyState(
            icon: Symbols.account_balance_wallet_rounded,
            title: 'Aucun agent dans ce filtre',
            message: 'Les commissions apparaîtront automatiquement après les transactions réussies.',
          )
        else
          ...rows.map(
            (_AgentRowData row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgentCommissionCard(
                data: row,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => AgentPerformancePage(
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

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final CommissionPeriod value;
  final ValueChanged<CommissionPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CommissionPeriod>(
          value: value,
          isExpanded: true,
          dropdownColor: IzyTelColors.surface,
          icon: const Icon(
            Symbols.keyboard_arrow_down_rounded,
            color: IzyTelColors.textSecondary,
          ),
          items: CommissionPeriod.values
              .map(
                (CommissionPeriod period) => DropdownMenuItem<CommissionPeriod>(
                  value: period,
                  child: Row(
                    children: [
                      const Icon(
                        Symbols.calendar_month_rounded,
                        size: IzyTelIconSize.info,
                        color: IzyTelColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        period.label,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w600,
                        ),
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

class _AgentCommissionCard extends StatelessWidget {
  const _AgentCommissionCard({required this.data, required this.onTap});

  final _AgentRowData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasBalance = data.balance > 0;
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IzyTelAvatar(name: data.agent.name, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontSize: IzyTelTypeScale.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: data.agent.isActive ? IzyTelColors.success : IzyTelColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          data.agent.isActive ? 'Agent actif' : 'Agent suspendu',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: IzyTelColors.textSecondary,
                            fontSize: IzyTelTypeScale.micro,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textMuted,
                size: IzyTelIconSize.action,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  label: 'Réussies',
                  value: '${data.performance.transactionsSuccessful}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetric(
                  label: 'Générées',
                  value: formatCfa(data.performance.commissionGeneratedInPeriod),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactMetric(
                  label: 'À payer',
                  value: formatCfa(data.balance),
                  accent: hasBalance ? IzyTelColors.warning : IzyTelColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: IzyTelColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: IzyTelColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent ?? IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
