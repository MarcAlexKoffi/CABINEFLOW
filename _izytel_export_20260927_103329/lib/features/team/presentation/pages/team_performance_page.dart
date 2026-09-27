import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/team/data/repositories/supabase_team_supervision_repository.dart';
import 'package:cabine_flow/features/team/domain/models/team_supervision_models.dart';
import 'package:cabine_flow/features/team/presentation/pages/team_member_detail_page.dart';
import 'package:cabine_flow/features/team/presentation/widgets/manager_compensation_history_card.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class TeamPerformancePage extends StatefulWidget {
  const TeamPerformancePage({
    super.key,
    required this.user,
    this.repository,
  });

  final AppUser user;
  final SupabaseTeamSupervisionRepository? repository;

  @override
  State<TeamPerformancePage> createState() => _TeamPerformancePageState();
}

class _TeamPerformancePageState extends State<TeamPerformancePage> {
  late final SupabaseTeamSupervisionRepository _repository;
  late Future<TeamPerformanceSnapshot> _future;
  Future<Map<String, dynamic>>? _managerCompensationPreviewFuture;
  Future<Map<String, dynamic>>? _managerCompensationHistoryFuture;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseTeamSupervisionRepository();
    _future = _repository.fetchPerformance();
    if (widget.user.isManager) {
      _managerCompensationPreviewFuture =
          _repository.fetchManagerCompensationPreview();
      _managerCompensationHistoryFuture =
          _repository.fetchManagerCompensationHistory();
    }
  }

  Future<void> _reload() async {
    final Future<TeamPerformanceSnapshot> next = _repository.fetchPerformance();
    final Future<Map<String, dynamic>>? nextPreview = widget.user.isManager
        ? _repository.fetchManagerCompensationPreview()
        : null;
    final Future<Map<String, dynamic>>? nextHistory = widget.user.isManager
        ? _repository.fetchManagerCompensationHistory()
        : null;
    setState(() {
      _future = next;
      _managerCompensationPreviewFuture = nextPreview;
      _managerCompensationHistoryFuture = nextHistory;
    });
    await next;
    if (nextPreview != null) {
      await nextPreview;
    }
    if (nextHistory != null) {
      await nextHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.user.isManager ? 'Performance de ma zone' : 'Performance de l’équipe'),
      ),
      body: FutureBuilder<TeamPerformanceSnapshot>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<TeamPerformanceSnapshot> snapshot) {
          if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(
              child: FilledButton(
                onPressed: _reload,
                child: const Text('Réessayer'),
              ),
            );
          }
          final TeamPerformanceSnapshot data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: <Widget>[
                IzyTelPageHeader(
                  title: widget.user.isManager ? 'Ma zone' : 'Toutes les zones',
                  subtitle: widget.user.isManager
                      ? 'Volume, gain IzyTel, commissions Agents et situation Cabinistes de tes zones uniquement.'
                      : 'Vue globale des performances Agents, Cabinistes et Managers.',
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                _summary(data.summary),
                const SizedBox(height: IzyTelSpacing.xl),
                const IzyTelSectionHeader(title: 'Agents'),
                const SizedBox(height: 8),
                ...data.agents.map((Map<String, dynamic> row) => _memberTile(
                      actorType: 'agent',
                      actorId: teamString(row['agentId']),
                      name: teamString(row['displayName']),
                      subtitle:
                          'Traité ce mois ${formatCfa(teamInt(row['processedAmount']))} · Commission du mois ${formatCfa(teamInt(row['periodCommissionEarned']))}',
                      trailing: 'Dû ${formatCfa(teamInt(row['commissionDue']))}',
                    )),
                const SizedBox(height: IzyTelSpacing.lg),
                const IzyTelSectionHeader(title: 'Cabinistes'),
                const SizedBox(height: 8),
                if (data.cabinistes.isEmpty)
                  const IzyTelSurface(
                    padding: EdgeInsets.all(IzyTelSpacing.md),
                    child: Text('Aucun Cabiniste affecté aux zones visibles.'),
                  )
                else
                  ...data.cabinistes.map((Map<String, dynamic> row) => _memberTile(
                        actorType: 'cabiniste',
                        actorId: teamString(row['partnerId']),
                        name: teamString(row['displayName']),
                        subtitle:
                            'Traité ce mois ${formatCfa(teamInt(row['processedAmount']))} · Reversement du mois ${formatCfa(teamInt(row['periodSettlementEarned']))}',
                        trailing: 'Dû ${formatCfa(teamInt(row['settlementDue']))}',
                      )),
                if (!widget.user.isManager) ...<Widget>[
                  const SizedBox(height: IzyTelSpacing.lg),
                  const IzyTelSectionHeader(title: 'Managers'),
                  const SizedBox(height: 8),
                  ...data.managers.map((Map<String, dynamic> row) => _memberTile(
                        actorType: 'manager',
                        actorId: teamString(row['managerId']),
                        name: teamString(row['displayName']),
                        subtitle:
                            'Zone ce mois ${formatCfa(teamInt(row['zoneProcessedAmount']))} · Acquis ${formatCfa(teamInt(row['compensationEarned']))}',
                        trailing: '+ ${formatCfa(teamInt(row['zoneIzytelGrossGain']))} IzyTel',
                      )),
                ],
                const SizedBox(height: IzyTelSpacing.lg),
                _managerPlanInfo(data.managerCompensationPlan),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summary(Map<String, dynamic> row) {
    final List<({String label, int value, IconData icon})> metrics = <({String label, int value, IconData icon})>[
      (label: 'Volume du mois', value: teamInt(row['processedAmount']), icon: Symbols.receipt_long_rounded),
      (label: 'Gain IzyTel du mois', value: teamInt(row['izytelGrossGain']), icon: Symbols.trending_up_rounded),
      (label: 'Commissions Agents à payer', value: teamInt(row['agentCommissionDue']), icon: Symbols.payments_rounded),
      (label: 'Reversements Cabinistes à payer', value: teamInt(row['cabinisteSettlementDue']), icon: Symbols.storefront_rounded),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((metric) {
        return SizedBox(
          width: MediaQuery.sizeOf(context).width >= 750 ? 220 : (MediaQuery.sizeOf(context).width - 50) / 2,
          child: IzyTelSurface(
            padding: const EdgeInsets.all(IzyTelSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(metric.icon, color: IzyTelColors.primary),
                const SizedBox(height: 10),
                Text(metric.label, style: const TextStyle(color: IzyTelColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  formatCfa(metric.value),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _memberTile({
    required String actorType,
    required String actorId,
    required String name,
    required String subtitle,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IzyTelSurface(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TeamMemberDetailPage(
              viewer: widget.user,
              actorType: actorType,
              actorId: actorId,
              fallbackName: name,
              repository: _repository,
            ),
          ),
        ),
        padding: const EdgeInsets.all(IzyTelSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: IzyTelColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(trailing, style: const TextStyle(color: IzyTelColors.success, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Symbols.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _managerPlanInfo(Map<String, dynamic> plan) {
    final bool draft = teamString(plan['status']) != 'active';
    if (plan.isEmpty) return const SizedBox.shrink();

    final Widget planNotice = IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            draft ? Symbols.info_rounded : Symbols.verified_rounded,
            color: draft ? IzyTelColors.warning : IzyTelColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              draft
                  ? 'Le plan de rémunération Manager est encore en brouillon. Les montants ci-dessous restent une simulation et ne créent aucune dette IzyTel.'
                  : 'Plan de rémunération Manager actif.',
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );

    if (!widget.user.isManager ||
        _managerCompensationPreviewFuture == null) {
      return planNotice;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        planNotice,
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _managerCompensationPreviewFuture,
          builder: (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>> snapshot,
          ) {
            if (snapshot.hasError) {
              return const IzyTelSurface(
                padding: EdgeInsets.all(IzyTelSpacing.md),
                child: Text(
                  'La simulation de rémunération n’est pas disponible pour le moment.',
                  style: TextStyle(color: IzyTelColors.textSecondary),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const IzyTelSurface(
                padding: EdgeInsets.all(IzyTelSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _managerCompensationPreview(snapshot.data!);
          },
        ),
        if (_managerCompensationHistoryFuture != null) ...<Widget>[
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _managerCompensationHistoryFuture,
            builder: (
              BuildContext context,
              AsyncSnapshot<Map<String, dynamic>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const IzyTelSurface(
                  padding: EdgeInsets.all(IzyTelSpacing.md),
                  child: Text(
                    'L’historique de rémunération n’est pas disponible pour le moment.',
                    style: TextStyle(color: IzyTelColors.textSecondary),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const IzyTelSurface(
                  padding: EdgeInsets.all(IzyTelSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ManagerCompensationHistoryCard(
                history: snapshot.data!,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _managerCompensationPreview(Map<String, dynamic> preview) {
    final Map<String, dynamic> activity = teamMap(preview['activity']);
    final Map<String, dynamic> thresholds = teamMap(preview['thresholds']);
    final Map<String, dynamic> projection = teamMap(preview['projection']);
    final Map<String, dynamic> eligibility = teamMap(preview['eligibility']);
    final Map<String, dynamic> plan = teamMap(preview['plan']);
    final bool eligible = eligibility.isEmpty
        ? thresholds['allMet'] == true
        : eligibility['eligible'] == true;
    final int theoreticalBase = projection.containsKey('theoreticalBaseAmount')
        ? teamInt(projection['theoreticalBaseAmount'])
        : teamInt(projection['baseAmount']);
    final int theoreticalVariable =
        projection.containsKey('theoreticalVariableAmount')
            ? teamInt(projection['theoreticalVariableAmount'])
            : teamInt(projection['variableAmount']);
    final int theoreticalTotal = projection.containsKey('theoreticalTotalAmount')
        ? teamInt(projection['theoreticalTotalAmount'])
        : teamInt(projection['projectedTotalAmount']);
    final int eligibleTotal = projection.containsKey('eligibleTotalAmount')
        ? teamInt(projection['eligibleTotalAmount'])
        : (eligible ? theoreticalTotal : 0);
    final double grossProgress =
        (teamInt(thresholds['grossProgressBps']) / 10000)
            .clamp(0, 1)
            .toDouble();
    final double dailyProgress =
        (teamInt(thresholds['dailyOrderProgressBps']) / 10000)
            .clamp(0, 1)
            .toDouble();

    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Rémunération du mois',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Période ${teamString(preview['periodKey'])} · ${teamInt(activity['completedOrders'])} commande(s) finalisée(s)',
                      style: const TextStyle(
                        color: IzyTelColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _eligibilityChip(eligible),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _previewMetric(
                'Gain IzyTel',
                formatCfa(teamInt(activity['izytelGrossGain'])),
              ),
              _previewMetric(
                'Forfait théorique',
                formatCfa(theoreticalBase),
              ),
              _previewMetric(
                'Variable théorique',
                formatCfa(theoreticalVariable),
              ),
              _previewMetric(
                'Total théorique',
                formatCfa(theoreticalTotal),
              ),
              _previewMetric(
                'Total éligible',
                formatCfa(eligibleTotal),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Gain brut : ${formatCfa(teamInt(activity['izytelGrossGain']))} / ${formatCfa(teamInt(plan['activationGrossThreshold']))}',
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: grossProgress),
          const SizedBox(height: 12),
          Text(
            'Activité : ${teamDouble(activity['averageDailyOrders']).toStringAsFixed(2)} / ${teamInt(plan['activationDailyOrderThreshold'])} commandes/jour',
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: dailyProgress),
          const SizedBox(height: 12),
          Text(
            teamString(plan['status']) == 'active'
                ? eligible
                    ? 'Les deux seuils sont atteints. La période ne devient comptable qu’après la fin du mois et sa clôture par l’Admin.'
                    : 'Les montants restent théoriques tant que les deux seuils d’activation ne sont pas atteints.'
                : 'Le plan Manager est encore en brouillon : même si les seuils étaient atteints, cette simulation ne créerait aucune dette IzyTel.',
            style: const TextStyle(
              color: IzyTelColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eligibilityChip(bool eligible) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: eligible ? IzyTelColors.successSoft : IzyTelColors.warningSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        eligible ? 'Seuils atteints' : 'Non éligible',
        style: TextStyle(
          color: eligible ? IzyTelColors.success : IzyTelColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _previewMetric(String label, String value) {
    return Container(
      width: MediaQuery.sizeOf(context).width >= 700
          ? 180
          : (MediaQuery.sizeOf(context).width - 72) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: IzyTelColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

}
