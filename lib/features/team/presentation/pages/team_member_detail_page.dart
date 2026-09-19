import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/features/team/data/repositories/supabase_team_supervision_repository.dart';
import 'package:cabine_flow/features/team/domain/models/team_supervision_models.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class TeamMemberDetailPage extends StatefulWidget {
  const TeamMemberDetailPage({
    super.key,
    required this.viewer,
    required this.actorType,
    required this.actorId,
    this.fallbackName = '',
    this.repository,
  });

  final AppUser viewer;
  final String actorType;
  final String actorId;
  final String fallbackName;
  final SupabaseTeamSupervisionRepository? repository;

  @override
  State<TeamMemberDetailPage> createState() => _TeamMemberDetailPageState();
}

class _TeamMemberDetailPageState extends State<TeamMemberDetailPage> {
  late final SupabaseTeamSupervisionRepository _repository;
  late Future<({TeamMemberDetail detail, TeamScopeSnapshot scope})> _future;
  bool _savingZones = false;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseTeamSupervisionRepository();
    _future = _load();
  }

  Future<({TeamMemberDetail detail, TeamScopeSnapshot scope})> _load() async {
    final List<Object> values = await Future.wait<Object>(<Future<Object>>[
      _repository.fetchMemberDetail(
        actorType: widget.actorType,
        actorId: widget.actorId,
      ),
      _repository.fetchScope(),
    ]);
    return (
      detail: values[0] as TeamMemberDetail,
      scope: values[1] as TeamScopeSnapshot,
    );
  }

  Future<void> _reload() async {
    final Future<({TeamMemberDetail detail, TeamScopeSnapshot scope})> next =
        _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  Future<void> _editCabinisteZones(
    TeamMemberDetail detail,
    TeamScopeSnapshot scope,
  ) async {
    if (!widget.viewer.permissions.canManageAgents ||
        widget.actorType != 'cabiniste' ||
        _savingZones) {
      return;
    }
    final Set<String> selected = detail.zoneIds.toSet();
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: IzyTelColors.background,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Zones du Cabiniste',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Les zones déterminent quel Manager peut superviser ce Cabiniste. Les capacités réseau restent non modifiables.',
                    style: TextStyle(color: IzyTelColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (scope.zones.isEmpty)
                    const Text('Aucune zone active.')
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: scope.zones.map((TeamScopeZone zone) {
                        final bool active = selected.contains(zone.id);
                        return FilterChip(
                          label: Text(zone.label),
                          selected: active,
                          onSelected: (bool value) {
                            setSheetState(() {
                              if (value) {
                                selected.add(zone.id);
                              } else {
                                selected.remove(zone.id);
                              }
                            });
                          },
                        );
                      }).toList(growable: false),
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Enregistrer les zones'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _savingZones = true);
    try {
      await _repository.updateCabinisteZones(
        partnerId: widget.actorId,
        zoneIds: selected.toList(growable: false),
      );
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Zones du Cabiniste enregistrées.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _clean(error));
    } finally {
      if (mounted) setState(() => _savingZones = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(_pageTitle(widget.actorType)),
      ),
      body: FutureBuilder<({TeamMemberDetail detail, TeamScopeSnapshot scope})>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<({TeamMemberDetail detail, TeamScopeSnapshot scope})>
              snapshot,
        ) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return _LoadError(error: snapshot.error, onRetry: _reload);
          }
          final TeamMemberDetail detail = snapshot.data!.detail;
          final TeamScopeSnapshot scope = snapshot.data!.scope;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: <Widget>[
                _header(detail),
                const SizedBox(height: IzyTelSpacing.lg),
                _identity(detail),
                const SizedBox(height: IzyTelSpacing.lg),
                _zones(detail, scope),
                const SizedBox(height: IzyTelSpacing.lg),
                _operations(detail),
                const SizedBox(height: IzyTelSpacing.lg),
                _finance(detail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(TeamMemberDetail detail) {
    final String displayName = detail.displayName.isEmpty
        ? widget.fallbackName
        : detail.displayName;
    final String uid = detail.firebaseUid;
    final String avatarPath = teamString(detail.profile['avatar_path']);
    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.lg),
      child: Column(
        children: <Widget>[
          StaffProfileAvatar(
            firebaseUid: uid,
            displayName: displayName,
            knownAvatarPath: avatarPath,
            size: 92,
          ),
          const SizedBox(height: 12),
          Text(
            displayName.isEmpty ? 'Compte IzyTel' : displayName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _roleLabel(detail.actorType),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: IzyTelColors.textSecondary,
                ),
          ),
          const SizedBox(height: 10),
          _verificationChip(teamString(detail.profile['verification_status'])),
        ],
      ),
    );
  }

  Widget _identity(TeamMemberDetail detail) {
    final Map<String, dynamic> p = detail.profile;
    return _section(
      title: 'Identité et coordonnées',
      icon: Symbols.person_rounded,
      children: <Widget>[
        _line('Prénom(s)', teamString(p['first_name'])),
        _line('Nom', teamString(p['last_name'])),
        _line('E-mail', teamString(p['email'])),
        _line('Téléphone', teamString(p['phone_number'])),
        _line('Téléphone secondaire', teamString(p['secondary_phone'])),
        _line('Date de naissance', _date(p['date_of_birth'])),
        _line('Ville', teamString(p['city'])),
        _line('Adresse', teamString(p['address'])),
        _line(
          'Contact d’urgence',
          <String>[
            teamString(p['emergency_contact_name']),
            teamString(p['emergency_contact_phone']),
          ].where((String value) => value.isNotEmpty).join(' · '),
        ),
        _line('Type de pièce', teamString(p['identity_document_type'])),
        _line('N° de pièce', teamString(p['identity_document_number'])),
        _line('Fichier de pièce', teamString(p['identity_document_file_name'])),
        _line('Statut de vérification', _verificationLabel(teamString(p['verification_status']))),
        _line('Note de vérification', teamString(p['verification_note'])),
        _line('Dernière activité', _dateTime(p['last_activity_at'])),
      ],
    );
  }

  Widget _zones(TeamMemberDetail detail, TeamScopeSnapshot scope) {
    final Map<String, TeamScopeZone> byId = <String, TeamScopeZone>{
      for (final TeamScopeZone zone in scope.zones) zone.id: zone,
    };
    final List<String> labels = detail.zoneIds
        .map((String id) => byId[id]?.label ?? id)
        .toList(growable: false);
    final bool canEdit = widget.viewer.permissions.canManageAgents &&
        detail.actorType == 'cabiniste';
    return _section(
      title: detail.actorType == 'manager' ? 'Zones supervisées' : 'Zones assignées',
      icon: Symbols.location_on_rounded,
      trailing: canEdit
          ? TextButton.icon(
              onPressed: _savingZones ? null : () => _editCabinisteZones(detail, scope),
              icon: const Icon(Symbols.edit_location_alt_rounded, size: 18),
              label: const Text('Modifier'),
            )
          : null,
      children: <Widget>[
        if (labels.isEmpty)
          const Text(
            'Aucune zone assignée.',
            style: TextStyle(color: IzyTelColors.textSecondary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: labels
                .map((String label) => Chip(label: Text(label)))
                .toList(growable: false),
          ),
        if (detail.actorType == 'cabiniste') ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'La capacité réseau du Cabiniste est son propre fonds de roulement : elle est affichée en lecture seule pour l’Admin et le Manager.',
            style: TextStyle(
              color: IzyTelColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _operations(TeamMemberDetail detail) {
    if (detail.actorType == 'agent') {
      final Map<String, dynamic> op = detail.operations;
      return _section(
        title: 'Activité opérationnelle',
        icon: Symbols.settings_account_box_rounded,
        children: <Widget>[
          _line('Code Agent', teamString(op['agent_code'])),
          _line('Disponibilité', teamString(op['availability'])),
          _line('Réseaux autorisés', teamStrings(op['authorized_networks']).join(' · ').toUpperCase()),
          _line('Réseaux actifs', teamStrings(op['active_networks']).join(' · ').toUpperCase()),
          _line('Capacité Orange', formatCfa(teamInt(op['orange_capacity']))),
          _line('Capacité MTN', formatCfa(teamInt(op['mtn_capacity']))),
          _line('Capacité Moov', formatCfa(teamInt(op['moov_capacity']))),
          _line('Plafond journalier', formatCfa(teamInt(op['daily_transaction_limit']))),
          _line('Transactions / jour', '${teamInt(op['max_transactions_per_day'])}'),
        ],
      );
    }
    if (detail.actorType == 'cabiniste') {
      final Map<String, dynamic> account = teamMap(detail.operations['account']);
      final Map<String, dynamic> capacities = teamMap(detail.operations['capacities']);
      return _section(
        title: 'Activité opérationnelle',
        icon: Symbols.storefront_rounded,
        children: <Widget>[
          _line('Code Cabiniste', teamString(account['partner_code'])),
          _line('Statut', teamString(account['status'])),
          _line('Disponibilité', teamString(account['availability'])),
          _line('Réseaux autorisés', teamStrings(account['authorized_networks']).join(' · ').toUpperCase()),
          _line('Réseaux actifs', teamStrings(account['active_networks']).join(' · ').toUpperCase()),
          _line('Capacité Orange', formatCfa(teamInt(capacities['orange_capacity']))),
          _line('Capacité MTN', formatCfa(teamInt(capacities['mtn_capacity']))),
          _line('Capacité Moov', formatCfa(teamInt(capacities['moov_capacity']))),
        ],
      );
    }
    final Map<String, dynamic> manager = teamMap(detail.operations['managerProfile']);
    return _section(
      title: 'Activité Manager',
      icon: Symbols.supervisor_account_rounded,
      children: <Widget>[
        _line('Compte', manager['is_active'] == true ? 'Actif' : 'Suspendu'),
        _line('Disponibilité', manager['is_available'] == true ? 'Disponible' : 'Indisponible'),
        _line('Dernière activité', _dateTime(manager['last_activity_at'])),
      ],
    );
  }

  Widget _finance(TeamMemberDetail detail) {
    final Map<String, dynamic> f = detail.finance;
    if (detail.actorType == 'agent') {
      final Map<String, dynamic> account = teamMap(f['commissionAccount']);
      final int earned = teamInt(account['earned_total']);
      final int paid = teamInt(account['paid_total']);
      return _section(
        title: 'Gains et performance',
        icon: Symbols.monitoring_rounded,
        children: <Widget>[
          _metricRows(<_MetricData>[
            _MetricData('Volume traité', teamInt(f['processedAmount'])),
            _MetricData('Commissions acquises', earned),
            _MetricData('Déjà versé', paid),
            _MetricData('Commission due', earned - paid),
            _MetricData('Ce mois', teamInt(f['commissionThisMonth'])),
            _MetricData('Gain IzyTel observé', teamInt(f['izytelGrossGainObserved'])),
          ]),
        ],
      );
    }
    if (detail.actorType == 'cabiniste') {
      final Map<String, dynamic> account = teamMap(f['compensationAccount']);
      final int earned = teamInt(account['earned_total']);
      final int paid = teamInt(account['paid_total']);
      return _section(
        title: 'Gains et performance',
        icon: Symbols.monitoring_rounded,
        children: <Widget>[
          _metricRows(<_MetricData>[
            _MetricData('Volume traité', teamInt(f['processedAmount'])),
            _MetricData('Marge Cabiniste', teamInt(f['cabinisteMarginTotal'])),
            _MetricData('Gain IzyTel', teamInt(f['izytelGrossGainTotal'])),
            _MetricData('À reverser', earned - paid),
            _MetricData('Déjà reversé', paid),
          ]),
        ],
      );
    }

    final Map<String, dynamic> account = teamMap(f['managerCompensationAccount']);
    final Map<String, dynamic> plan = teamMap(f['managerPlan']);
    final bool activePlan = teamString(plan['status']) == 'active';
    return _section(
      title: 'Performance de la zone',
      icon: Symbols.monitoring_rounded,
      children: <Widget>[
        _metricRows(<_MetricData>[
          _MetricData('Volume observé', teamInt(f['zoneProcessedAmount'])),
          _MetricData('Gain IzyTel observé', teamInt(f['zoneIzytelGrossGain'])),
          _MetricData('Commissions Agents acquises', teamInt(f['teamAgentCommissionsEarned'])),
          _MetricData('Commissions Agents dues', teamInt(f['teamAgentCommissionsDue'])),
          _MetricData('Règlements Cabinistes dus', teamInt(f['teamCabinisteSettlementDue'])),
          _MetricData('Rémunération Manager acquise', teamInt(account['earned_total'])),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: activePlan ? IzyTelColors.successSoft : IzyTelColors.warningSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            activePlan
                ? 'Plan de rémunération Manager actif.'
                : 'Le plan Manager ${teamString(plan['planCode'])} est encore en brouillon : les performances de zone sont visibles, mais aucune rémunération variable n’est comptabilisée comme acquise.',
            style: TextStyle(
              color: activePlan ? IzyTelColors.success : IzyTelColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _metricRows(List<_MetricData> metrics) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((_MetricData metric) {
        return Container(
          width: MediaQuery.sizeOf(context).width >= 700 ? 210 : 145,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: IzyTelColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                metric.label,
                style: const TextStyle(
                  color: IzyTelColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCfa(metric.amount),
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: IzyTelColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    final String shown = value.trim().isEmpty ? 'Non renseigné' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: IzyTelColors.textMuted),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shown,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verificationChip(String raw) {
    final bool verified = raw == 'verified';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: verified ? IzyTelColors.successSoft : IzyTelColors.warningSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _verificationLabel(raw),
        style: TextStyle(
          color: verified ? IzyTelColors.success : IzyTelColors.warning,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _verificationLabel(String raw) => switch (raw) {
        'verified' => 'Vérifié',
        'pending_review' => 'À vérifier',
        'needs_correction' => 'À corriger',
        _ => 'Profil incomplet',
      };

  String _date(Object? raw) {
    final DateTime? value = DateTime.tryParse(teamString(raw));
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  String _dateTime(Object? raw) {
    final DateTime? value = DateTime.tryParse(teamString(raw))?.toLocal();
    if (value == null) return '';
    return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} · ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _clean(Object error) => error
      .toString()
      .replaceFirst('PostgrestException(message: ', '')
      .replaceFirst('Exception: ', '');
}

class _MetricData {
  const _MetricData(this.label, this.amount);
  final String label;
  final int amount;
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});
  final Object? error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Symbols.error_rounded, color: IzyTelColors.error),
            const SizedBox(height: 10),
            Text(
              'Impossible de charger les informations détaillées.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: IzyTelColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

String _pageTitle(String actorType) => switch (actorType) {
      'agent' => 'Détail Agent',
      'cabiniste' => 'Détail Cabiniste',
      'manager' => 'Détail Manager',
      _ => 'Détail du compte',
    };

String _roleLabel(String actorType) => switch (actorType) {
      'agent' => 'Agent',
      'cabiniste' => 'Cabiniste',
      'manager' => 'Manager',
      _ => actorType,
    };
