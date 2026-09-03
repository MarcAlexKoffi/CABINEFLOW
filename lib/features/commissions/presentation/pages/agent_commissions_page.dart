import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/agent_commission_summary_repository.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentCommissionsPage extends StatelessWidget {
  const AgentCommissionsPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final CommissionRepository repository;

  @override
  Widget build(BuildContext context) {
    final AgentCommissionSummaryRepository? summaryRepository =
        repository is AgentCommissionSummaryRepository
        ? repository as AgentCommissionSummaryRepository
        : null;
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Mes commissions',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<List<CommissionEntry>>(
        stream: repository.watchCommissions(agentId: user.id),
        builder: (context, commissionSnapshot) {
          return StreamBuilder<List<CommissionPayout>>(
            stream: repository.watchPayouts(agentId: user.id),
            builder: (context, payoutSnapshot) {
              return StreamBuilder<AgentCommissionSummary?>(
                stream: summaryRepository?.watchAgentCommissionSummary() ??
                    Stream<AgentCommissionSummary?>.value(null),
                builder: (context, summarySnapshot) {
                  if ((commissionSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !commissionSnapshot.hasData) ||
                      (payoutSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !payoutSnapshot.hasData)) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (commissionSnapshot.hasError || payoutSnapshot.hasError) {
                    return const _AgentCommissionState(
                      icon: Symbols.cloud_off_rounded,
                      title: 'Commissions indisponibles',
                      message:
                          'Impossible de charger tes commissions pour le moment.',
                    );
                  }

                  final List<CommissionEntry> commissions =
                      commissionSnapshot.data ?? const <CommissionEntry>[];
                  final List<CommissionPayout> payouts =
                      payoutSnapshot.data ?? const <CommissionPayout>[];
                  final AgentCommissionSummary? summary = summarySnapshot.data;
                  final DateTime now = DateTime.now();
                  final int fallbackEarned = commissions.fold<int>(
                    0,
                    (total, value) => total + value.commissionAmount,
                  );
                  final int fallbackPaid = payouts.fold<int>(
                    0,
                    (total, value) => total + value.amount,
                  );
                  final int fallbackMonth = commissions
                      .where(
                        (value) =>
                            value.earnedAt.year == now.year &&
                            value.earnedAt.month == now.month,
                      )
                      .fold<int>(
                        0,
                        (total, value) => total + value.commissionAmount,
                      );
                  final int earnedTotal = summary?.earnedTotal ?? fallbackEarned;
                  final int paidTotal = summary?.paidTotal ?? fallbackPaid;
                  final int balance =
                      summary?.balance ?? (earnedTotal - paidTotal);
                  final int earnedThisMonth =
                      summary?.earnedThisMonth ?? fallbackMonth;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      IzyTelSpacing.lg,
                      IzyTelSpacing.sm,
                      IzyTelSpacing.lg,
                      IzyTelSpacing.xxl,
                    ),
                    children: <Widget>[
                      _CommissionHero(
                        balance: balance,
                        earnedThisMonth: earnedThisMonth,
                      ),
                      const SizedBox(height: IzyTelSpacing.md),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: _CommissionMetric(
                              label: 'Total acquis',
                              value: formatCfa(earnedTotal),
                              icon: Symbols.savings_rounded,
                              color: IzyTelColors.primary,
                            ),
                          ),
                          const SizedBox(width: IzyTelSpacing.sm),
                          Flexible(
                            child: _CommissionMetric(
                              label: 'Déjà versé',
                              value: formatCfa(paidTotal),
                              icon: Symbols.check_circle_rounded,
                              color: IzyTelColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: IzyTelSpacing.md),
                      IzyTelSurface(
                        padding: const EdgeInsets.all(IzyTelSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: IzyTelColors.primarySoft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Symbols.info_rounded,
                                color: IzyTelColors.primary,
                                size: IzyTelIconSize.action,
                              ),
                            ),
                            const SizedBox(width: IzyTelSpacing.sm),
                            Flexible(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Règle actuelle',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: IzyTelColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    CommissionPolicy.current.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: IzyTelColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Une commission est acquise uniquement lorsqu’une commande est terminée avec succès.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: IzyTelColors.textMuted,
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: IzyTelSpacing.xl),
                      const IzyTelSectionHeader(title: 'Dernières commissions'),
                      const SizedBox(height: IzyTelSpacing.sm),
                      if (commissions.isEmpty)
                        const _AgentCommissionState(
                          icon: Symbols.payments_rounded,
                          title: 'Aucune commission',
                          message:
                              'Tes commissions apparaîtront ici après tes premières transactions réussies.',
                          compact: true,
                        )
                      else
                        IzyTelSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (
                                int index = 0;
                                index < commissions.take(8).length;
                                index++
                              ) ...<Widget>[
                                _CommissionEntryRow(entry: commissions[index]),
                                if (index < commissions.take(8).length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: IzyTelSpacing.xl),
                      const IzyTelSectionHeader(title: 'Versements reçus'),
                      const SizedBox(height: IzyTelSpacing.sm),
                      if (payouts.isEmpty)
                        const _AgentCommissionState(
                          icon: Symbols.account_balance_wallet_rounded,
                          title: 'Aucun versement',
                          message:
                              'Les versements de commissions enregistrés par l’administration apparaîtront ici.',
                          compact: true,
                        )
                      else
                        IzyTelSurface(
                          padding: EdgeInsets.zero,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (
                                int index = 0;
                                index < payouts.take(6).length;
                                index++
                              ) ...<Widget>[
                                _PayoutRow(payout: payouts[index]),
                                if (index < payouts.take(6).length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _CommissionHero extends StatelessWidget {
  const _CommissionHero({required this.balance, required this.earnedThisMonth});

  final int balance;
  final int earnedThisMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(IzyTelSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[IzyTelColors.primary, IzyTelColors.primaryStrong],
        ),
        borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x282E63EB),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'SOLDE DE COMMISSIONS',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white.withAlpha(215),
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatCfaFull(balance),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontSize: IzyTelTypeScale.title1,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatCfa(earnedThisMonth)} générés ce mois',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withAlpha(225),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionMetric extends StatelessWidget {
  const _CommissionMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: IzyTelIconSize.action, color: color),
          const SizedBox(height: IzyTelSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IzyTelColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionEntryRow extends StatelessWidget {
  const _CommissionEntryRow({required this.entry});

  final CommissionEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _NetworkMark(network: entry.network),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.orderReference,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_networkLabel(entry.network)} • ${_formatDate(entry.earnedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Text(
            '+${formatCfa(entry.commissionAmount)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.payout});

  final CommissionPayout payout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFE9FBFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/wave_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Symbols.account_balance_wallet_rounded,
                color: IzyTelColors.wave,
              ),
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Versement Wave',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatDate(payout.paidAt)} • ${payout.paymentReference}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Text(
            formatCfa(payout.amount),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: IzyTelColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkMark extends StatelessWidget {
  const _NetworkMark({required this.network});

  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    final String asset = switch (network) {
      MobileNetwork.orange => 'assets/brands/operators/orange_ci.png',
      MobileNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
      MobileNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
    };
    final Color background = switch (network) {
      MobileNetwork.orange => IzyTelColors.orangeSoft,
      MobileNetwork.mtn => IzyTelColors.mtnSoft,
      MobileNetwork.moov => IzyTelColors.moovSoft,
    };

    return Container(
      width: 38,
      height: 38,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}

class _AgentCommissionState extends StatelessWidget {
  const _AgentCommissionState({
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
    return IzyTelSurface(
      padding: EdgeInsets.all(compact ? IzyTelSpacing.md : IzyTelSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: IzyTelColors.textMuted, size: 30),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IzyTelColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _networkLabel(MobileNetwork network) => switch (network) {
  MobileNetwork.orange => 'Orange',
  MobileNetwork.mtn => 'MTN',
  MobileNetwork.moov => 'Moov',
};

String _formatDate(DateTime value) {
  final DateTime now = DateTime.now();
  final String time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return 'Aujourd’hui à $time';
  }
  return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} à $time';
}
