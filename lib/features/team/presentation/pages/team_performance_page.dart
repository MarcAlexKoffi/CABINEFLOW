import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/team/data/repositories/supabase_team_supervision_repository.dart';
import 'package:cabine_flow/features/team/domain/models/team_supervision_models.dart';
import 'package:cabine_flow/features/team/presentation/pages/team_member_detail_page.dart';
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

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseTeamSupervisionRepository();
    _future = _repository.fetchPerformance();
  }

  Future<void> _reload() async {
    final Future<TeamPerformanceSnapshot> next = _repository.fetchPerformance();
    setState(() {
      _future = next;
    });
    await next;
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
                          'Traité ${formatCfa(teamInt(row['processedAmount']))} · Commission due ${formatCfa(teamInt(row['commissionDue']))}',
                      trailing: formatCfa(teamInt(row['commissionEarned'])),
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
                            'Traité ${formatCfa(teamInt(row['processedAmount']))} · À reverser ${formatCfa(teamInt(row['settlementDue']))}',
                        trailing: '+ ${formatCfa(teamInt(row['izytelGrossGain']))} IzyTel',
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
                            'Zone : ${formatCfa(teamInt(row['zoneProcessedAmount']))} traité · Rémunération acquise ${formatCfa(teamInt(row['compensationEarned']))}',
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
      (label: 'Volume observé', value: teamInt(row['processedAmount']), icon: Symbols.receipt_long_rounded),
      (label: 'Gain IzyTel', value: teamInt(row['izytelGrossGain']), icon: Symbols.trending_up_rounded),
      (label: 'Commissions Agents dues', value: teamInt(row['agentCommissionDue']), icon: Symbols.payments_rounded),
      (label: 'Règlements Cabinistes dus', value: teamInt(row['cabinisteSettlementDue']), icon: Symbols.storefront_rounded),
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
    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(draft ? Symbols.info_rounded : Symbols.verified_rounded, color: draft ? IzyTelColors.warning : IzyTelColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              draft
                  ? 'Le plan de rémunération Manager est encore en brouillon. Les montants de performance sont réels, mais aucune rémunération Manager n’est comptabilisée tant que ce plan n’est pas activé.'
                  : 'Plan de rémunération Manager actif.',
              style: const TextStyle(color: IzyTelColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
