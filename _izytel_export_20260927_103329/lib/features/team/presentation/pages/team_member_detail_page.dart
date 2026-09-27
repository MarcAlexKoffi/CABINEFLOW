import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/features/team/data/repositories/supabase_team_supervision_repository.dart';
import 'package:cabine_flow/features/team/domain/models/team_supervision_models.dart';
import 'package:cabine_flow/features/team/presentation/widgets/manager_compensation_history_card.dart';
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
  bool _savingCapacity = false;
  bool _financeBusy = false;
  _MemberDetailTab _selectedTab = _MemberDetailTab.overview;

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

  bool get _isAdmin => widget.viewer.role == UserRole.administrator;

  Future<void> _chooseAndCloseManagerPeriod(TeamMemberDetail detail) async {
    if (!_isAdmin || _financeBusy || detail.actorType != 'manager') return;

    final Map<String, dynamic> preview =
        teamMap(detail.finance['compensationPreview']);
    final Map<String, dynamic> plan = teamMap(preview['plan']);
    if (teamString(plan['status']) != 'active') {
      IzyTelFeedback.show(
        context,
        'Attention : le plan Manager est encore en brouillon. Aucune clôture comptable ne peut être créée.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }

    final Map<String, dynamic> history =
        teamMap(detail.finance['compensationHistory']);
    final Set<String> existingKeys = _mapList(history['periods'])
        .map((Map<String, dynamic> row) => teamString(row['periodKey']))
        .where((String value) => value.isNotEmpty)
        .toSet();
    final DateTime now = DateTime.now();
    final List<DateTime> candidates = List<DateTime>.generate(
      12,
      (int index) => DateTime(now.year, now.month - index - 1, 1),
      growable: false,
    ).where((DateTime month) => !existingKeys.contains(_monthKey(month))).toList();

    if (candidates.isEmpty) {
      IzyTelFeedback.show(
        context,
        'Toutes les périodes des 12 derniers mois sont déjà clôturées.',
      );
      return;
    }

    final DateTime? selected = await showModalBottomSheet<DateTime>(
      context: context,
      useSafeArea: true,
      backgroundColor: IzyTelColors.background,
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Clôturer une période Manager',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'La clôture crée les écritures immuables du forfait et de la commission variable. Elle ne réalise aucun paiement.',
                style: TextStyle(color: IzyTelColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final DateTime month = candidates[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_monthLabel(month)),
                      subtitle: Text('Période ${_monthKey(month)}'),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: () => Navigator.of(sheetContext).pop(month),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() {
      _financeBusy = true;
    });
    try {
      await _repository.closeManagerCompensationPeriod(
        managerId: detail.actorId,
        periodStart: selected,
      );
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Période ${_monthKey(selected)} calculée. Elle doit maintenant être approuvée par l’Admin.',
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _clean(error));
    } finally {
      if (mounted) {
        setState(() {
          _financeBusy = false;
        });
      }
    }
  }

  Future<void> _approveManagerPeriod(Map<String, dynamic> period) async {
    if (!_isAdmin || _financeBusy) return;
    final String periodId = teamString(period['periodId']);
    if (periodId.isEmpty) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Approuver la rémunération'),
        content: Text(
          'Confirmer la période ${teamString(period['periodKey'])} pour un total de ${formatCfa(teamInt(period['totalAmount']))} ?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Approuver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _financeBusy = true;
    });
    try {
      await _repository.approveManagerCompensationPeriod(periodId: periodId);
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Rémunération Manager approuvée.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _clean(error));
    } finally {
      if (mounted) {
        setState(() {
          _financeBusy = false;
        });
      }
    }
  }

  Future<void> _adjustManagerPeriod(Map<String, dynamic> period) async {
    if (!_isAdmin || _financeBusy) return;
    final String periodId = teamString(period['periodId']);
    if (periodId.isEmpty) return;

    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Ajuster ${teamString(period['periodKey'])}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Montant signé',
                hintText: 'Ex. 500 ou -500',
                suffixText: 'FCFA',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motif obligatoire',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final int? amount = int.tryParse(
                amountController.text.replaceAll(' ', '').trim(),
              );
              final String reason = reasonController.text.trim();
              if (amount == null || amount == 0 || reason.length < 3) return;
              Navigator.of(dialogContext).pop(<String, dynamic>{
                'amount': amount,
                'reason': reason,
              });
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    amountController.dispose();
    reasonController.dispose();
    if (result == null || !mounted) return;

    setState(() {
      _financeBusy = true;
    });
    try {
      await _repository.adjustManagerCompensationPeriod(
        periodId: periodId,
        amount: teamInt(result['amount']),
        reason: teamString(result['reason']),
      );
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Ajustement enregistré. La période doit être approuvée de nouveau.',
      );
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _clean(error));
    } finally {
      if (mounted) {
        setState(() {
          _financeBusy = false;
        });
      }
    }
  }

  Future<void> _payManagerPeriod(
    TeamMemberDetail detail,
    Map<String, dynamic> period,
  ) async {
    if (!_isAdmin || _financeBusy) return;
    final String periodId = teamString(period['periodId']);
    final int due = teamInt(period['balanceDue']);
    if (periodId.isEmpty || due <= 0) return;

    final TextEditingController amountController =
        TextEditingController(text: '$due');
    final TextEditingController channelController =
        TextEditingController(text: 'wave');
    final TextEditingController referenceController = TextEditingController();
    final TextEditingController noteController = TextEditingController();

    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Régler ${teamString(period['periodKey'])}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Montant',
                  helperText: 'Solde dû : ${formatCfa(due)}',
                  suffixText: 'FCFA',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: channelController,
                decoration: const InputDecoration(labelText: 'Canal'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence du paiement',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optionnel)'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final int? amount = int.tryParse(
                amountController.text.replaceAll(' ', '').trim(),
              );
              final String channel = channelController.text.trim();
              final String reference = referenceController.text.trim();
              if (amount == null ||
                  amount <= 0 ||
                  amount > due ||
                  channel.isEmpty ||
                  reference.length < 3) {
                return;
              }
              Navigator.of(dialogContext).pop(<String, dynamic>{
                'amount': amount,
                'channel': channel,
                'reference': reference,
                'note': noteController.text.trim(),
              });
            },
            child: const Text('Enregistrer le règlement'),
          ),
        ],
      ),
    );

    amountController.dispose();
    channelController.dispose();
    referenceController.dispose();
    noteController.dispose();
    if (result == null || !mounted) return;

    setState(() {
      _financeBusy = true;
    });
    try {
      await _repository.recordManagerPayout(
        managerId: detail.actorId,
        periodId: periodId,
        amount: teamInt(result['amount']),
        paymentChannel: teamString(result['channel']),
        paymentReference: teamString(result['reference']),
        note: teamString(result['note']),
      );
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Règlement Manager enregistré.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _clean(error));
    } finally {
      if (mounted) {
        setState(() {
          _financeBusy = false;
        });
      }
    }
  }

  Future<void> _editAgentCapacity(TeamMemberDetail detail) async {
    if (!widget.viewer.permissions.canManageAgents ||
        detail.actorType != 'agent' ||
        _savingCapacity) {
      return;
    }

    final Map<String, dynamic> operations = detail.operations;
    final List<String> allowedNetworks = teamStrings(
      operations['authorized_networks'],
    ).where((String value) => value.trim().isNotEmpty).toList(growable: false);
    final List<String> networks = allowedNetworks.isEmpty
        ? const <String>['orange', 'mtn', 'moov']
        : allowedNetworks;
    String selectedNetwork = networks.first.toLowerCase();

    int currentCapacity(String network) => switch (network.toLowerCase()) {
          'orange' => teamInt(operations['orange_capacity']),
          'mtn' => teamInt(operations['mtn_capacity']),
          'moov' => teamInt(operations['moov_capacity']),
          _ => 0,
        };

    final TextEditingController amountController = TextEditingController(
      text: '${currentCapacity(selectedNetwork)}',
    );
    final TextEditingController reasonController = TextEditingController();

    final Map<String, dynamic>? result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Modifier une capacité Agent'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedNetwork,
                    decoration: const InputDecoration(labelText: 'Réseau'),
                    items: networks
                        .map(
                          (String network) => DropdownMenuItem<String>(
                            value: network.toLowerCase(),
                            child: Text(network.toUpperCase()),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedNetwork = value;
                        amountController.text = '${currentCapacity(value)}';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nouvelle capacité',
                      suffixText: 'FCFA',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motif (optionnel)',
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final int? target = int.tryParse(
                      amountController.text.replaceAll(' ', '').trim(),
                    );
                    if (target == null || target < 0) return;
                    Navigator.of(dialogContext).pop(<String, dynamic>{
                      'network': selectedNetwork,
                      'target': target,
                      'reason': reasonController.text.trim(),
                    });
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    reasonController.dispose();
    if (result == null || !mounted) return;

    setState(() => _savingCapacity = true);
    try {
      await _repository.adjustManagerAgentCapacity(
        agentId: detail.actorId,
        network: teamString(result['network']),
        targetCapacity: teamInt(result['target']),
        reason: teamString(result['reason']),
      );
      if (!mounted) return;
      IzyTelFeedback.success(context, 'Capacité Agent mise à jour.');
      await _reload();
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, _clean(error));
    } finally {
      if (mounted) setState(() => _savingCapacity = false);
    }
  }

  String _monthKey(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  String _monthLabel(DateTime value) {
    const List<String> months = <String>[
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  List<Map<String, dynamic>> _mapList(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              children: <Widget>[
                _compactHeader(detail, scope),
                const SizedBox(height: 12),
                _tabSelector(),
                const SizedBox(height: IzyTelSpacing.lg),
                switch (_selectedTab) {
                  _MemberDetailTab.overview => _overview(detail),
                  _MemberDetailTab.profile => _profile(detail, scope),
                  _MemberDetailTab.history => _history(detail),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _compactHeader(TeamMemberDetail detail, TeamScopeSnapshot scope) {
    final String displayName = detail.displayName.isEmpty
        ? widget.fallbackName
        : detail.displayName;
    final String avatarPath = teamString(detail.profile['avatar_path']);
    final List<String> zoneLabels = _zoneLabels(detail, scope);
    final String status = _memberStatus(detail);

    return IzyTelSurface(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Row(
        children: <Widget>[
          StaffProfileAvatar(
            firebaseUid: detail.firebaseUid,
            displayName: displayName,
            knownAvatarPath: avatarPath,
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName.isEmpty ? 'Compte IzyTel' : displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_roleLabel(detail.actorType)} · $status',
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (zoneLabels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Symbols.location_on_rounded,
                        size: 16,
                        color: IzyTelColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          zoneLabels.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: IzyTelColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabSelector() {
    const List<({
      _MemberDetailTab tab,
      String label,
      IconData icon,
    })> items = <({
      _MemberDetailTab tab,
      String label,
      IconData icon,
    })>[
      (
        tab: _MemberDetailTab.overview,
        label: 'Aperçu',
        icon: Symbols.monitoring_rounded,
      ),
      (
        tab: _MemberDetailTab.profile,
        label: 'Profil',
        icon: Symbols.person_rounded,
      ),
      (
        tab: _MemberDetailTab.history,
        label: 'Historique',
        icon: Symbols.history_rounded,
      ),
    ];

    return IzyTelSurface(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: items.map((item) {
          final bool selected = _selectedTab == item.tab;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedTab = item.tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? IzyTelColors.primarySoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      item.icon,
                      size: 18,
                      color: selected
                          ? IzyTelColors.primary
                          : IzyTelColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? IzyTelColors.primary
                              : IzyTelColors.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _overview(TeamMemberDetail detail) => switch (detail.actorType) {
        'agent' => _agentOverview(detail),
        'cabiniste' => _cabinisteOverview(detail),
        'manager' => _managerOverview(detail),
        _ => const SizedBox.shrink(),
      };

  Widget _agentOverview(TeamMemberDetail detail) {
    final Map<String, dynamic> finance = detail.finance;
    final Map<String, dynamic> account = teamMap(finance['commissionAccount']);
    final Map<String, dynamic> activityHistory =
        teamMap(finance['activityHistory']);
    final Map<String, dynamic> month = teamMap(activityHistory['currentMonth']);
    final int earned = teamInt(account['earned_total']);
    final int paid = teamInt(account['paid_total']);
    final int due = (earned - paid).clamp(0, earned).toInt();
    final int monthVolume = month.isEmpty
        ? teamInt(finance['processedAmount'])
        : teamInt(month['processedAmount']);
    final int monthCommission = month.isEmpty
        ? teamInt(finance['commissionThisMonth'])
        : teamInt(month['commissionEarned']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _section(
          title: 'Performance du mois',
          icon: Symbols.monitoring_rounded,
          children: <Widget>[
            _metricRows(<_MetricData>[
              _MetricData('Volume traité', formatCfa(monthVolume)),
              _MetricData(
                'Commandes',
                month.isEmpty ? '—' : '${teamInt(month['completedOrders'])}',
              ),
              _MetricData('Commission du mois', formatCfa(monthCommission)),
              _MetricData('Reste dû', formatCfa(due)),
            ]),
          ],
        ),
        const SizedBox(height: IzyTelSpacing.lg),
        _section(
          title: 'Commissions',
          icon: Symbols.payments_rounded,
          children: <Widget>[
            _line('Gagné au total', formatCfa(earned)),
            _line('Déjà versé', formatCfa(paid)),
            _line('Reste à payer', formatCfa(due)),
          ],
        ),
        const SizedBox(height: IzyTelSpacing.lg),
        _agentCapacityCard(detail),
      ],
    );
  }

  Widget _agentCapacityCard(TeamMemberDetail detail) {
    final Map<String, dynamic> op = detail.operations;
    final bool canAdjust = widget.viewer.permissions.canManageAgents &&
        detail.actorType == 'agent';
    return _section(
      title: 'Capacités',
      icon: Symbols.settings_account_box_rounded,
      children: <Widget>[
        _metricRows(<_MetricData>[
          _MetricData('Orange', formatCfa(teamInt(op['orange_capacity']))),
          _MetricData('MTN', formatCfa(teamInt(op['mtn_capacity']))),
          _MetricData('Moov', formatCfa(teamInt(op['moov_capacity']))),
        ]),
        if (canAdjust) ...<Widget>[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _savingCapacity
                  ? null
                  : () => _editAgentCapacity(detail),
              icon: const Icon(Symbols.tune_rounded),
              label: const Text('Modifier les capacités'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _cabinisteOverview(TeamMemberDetail detail) {
    final Map<String, dynamic> finance = detail.finance;
    final Map<String, dynamic> account = teamMap(finance['compensationAccount']);
    final Map<String, dynamic> activityHistory =
        teamMap(finance['activityHistory']);
    final Map<String, dynamic> month = teamMap(activityHistory['currentMonth']);
    final int earned = teamInt(account['earned_total']);
    final int paid = teamInt(account['paid_total']);
    final int due = (earned - paid).clamp(0, earned).toInt();
    final Map<String, dynamic> capacities =
        teamMap(detail.operations['capacities']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _section(
          title: 'Performance du mois',
          icon: Symbols.monitoring_rounded,
          children: <Widget>[
            _metricRows(<_MetricData>[
              _MetricData(
                'Volume traité',
                formatCfa(
                  month.isEmpty
                      ? teamInt(finance['processedAmount'])
                      : teamInt(month['processedAmount']),
                ),
              ),
              _MetricData(
                'Commandes',
                month.isEmpty ? '—' : '${teamInt(month['completedOrders'])}',
              ),
              _MetricData(
                'Marge Cabiniste',
                formatCfa(
                  month.isEmpty
                      ? teamInt(finance['cabinisteMarginTotal'])
                      : teamInt(month['cabinisteMargin']),
                ),
              ),
              _MetricData(
                'Gain IzyTel',
                formatCfa(
                  month.isEmpty
                      ? teamInt(finance['izytelGrossGainTotal'])
                      : teamInt(month['izytelGrossGain']),
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: IzyTelSpacing.lg),
        _section(
          title: 'Reversements',
          icon: Symbols.payments_rounded,
          children: <Widget>[
            _line(
              'Acquis ce mois',
              month.isEmpty
                  ? '—'
                  : formatCfa(teamInt(month['settlementEarned'])),
            ),
            _line('Acquis au total', formatCfa(earned)),
            _line('Déjà reversé', formatCfa(paid)),
            _line('Reste dû', formatCfa(due)),
          ],
        ),
        const SizedBox(height: IzyTelSpacing.lg),
        _section(
          title: 'Capacités',
          icon: Symbols.storefront_rounded,
          children: <Widget>[
            _metricRows(<_MetricData>[
              _MetricData(
                'Orange',
                formatCfa(teamInt(capacities['orange_capacity'])),
              ),
              _MetricData(
                'MTN',
                formatCfa(teamInt(capacities['mtn_capacity'])),
              ),
              _MetricData(
                'Moov',
                formatCfa(teamInt(capacities['moov_capacity'])),
              ),
            ]),
            const SizedBox(height: 10),
            const Text(
              'Lecture seule : ces capacités correspondent au fonds de roulement propre du Cabiniste.',
              style: TextStyle(
                color: IzyTelColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _managerOverview(TeamMemberDetail detail) {
    final Map<String, dynamic> finance = detail.finance;
    final Map<String, dynamic> preview =
        teamMap(finance['compensationPreview']);
    final Map<String, dynamic> plan = teamMap(preview['plan']);
    final Map<String, dynamic> activity = teamMap(preview['activity']);
    final Map<String, dynamic> thresholds = teamMap(preview['thresholds']);
    final Map<String, dynamic> projection = teamMap(preview['projection']);
    final Map<String, dynamic> eligibility = teamMap(preview['eligibility']);
    final bool activePlan = teamString(plan['status']) == 'active';
    final bool eligible = eligibility.isEmpty
        ? thresholds['allMet'] == true
        : eligibility['eligible'] == true;
    final int theoreticalTotal = projection.containsKey('theoreticalTotalAmount')
        ? teamInt(projection['theoreticalTotalAmount'])
        : teamInt(projection['projectedTotalAmount']);
    final int eligibleTotal = projection.containsKey('eligibleTotalAmount')
        ? teamInt(projection['eligibleTotalAmount'])
        : (eligible ? theoreticalTotal : 0);
    final double grossProgress =
        (teamInt(thresholds['grossProgressBps']) / 100)
            .clamp(0, 100)
            .toDouble();
    final double dailyProgress =
        (teamInt(thresholds['dailyOrderProgressBps']) / 100)
            .clamp(0, 100)
            .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _section(
          title: 'Performance du mois',
          icon: Symbols.monitoring_rounded,
          children: <Widget>[
            _metricRows(<_MetricData>[
              _MetricData(
                'Volume supervisé',
                formatCfa(teamInt(activity['processedAmount'])),
              ),
              _MetricData(
                'Gain IzyTel',
                formatCfa(teamInt(activity['izytelGrossGain'])),
              ),
              _MetricData(
                'Commandes',
                '${teamInt(activity['completedOrders'])}',
              ),
              _MetricData(
                'Moyenne / jour',
                teamDouble(activity['averageDailyOrders']).toStringAsFixed(2),
              ),
            ]),
          ],
        ),
        const SizedBox(height: IzyTelSpacing.lg),
        _section(
          title: 'Rémunération Manager',
          icon: Symbols.payments_rounded,
          children: <Widget>[
            Row(
              children: <Widget>[
                _stateChip(
                  eligible ? 'Seuils atteints' : 'Non éligible',
                  positive: eligible,
                ),
                const Spacer(),
                Text(
                  'Période ${teamString(preview['periodKey'])}',
                  style: const TextStyle(
                    color: IzyTelColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _progressLine(
              label: 'Gain brut',
              current: formatCfa(teamInt(activity['izytelGrossGain'])),
              target: formatCfa(teamInt(plan['activationGrossThreshold'])),
              progressPercent: grossProgress,
            ),
            const SizedBox(height: 12),
            _progressLine(
              label: 'Activité',
              current:
                  teamDouble(activity['averageDailyOrders']).toStringAsFixed(2),
              target:
                  '${teamInt(plan['activationDailyOrderThreshold'])} commandes/jour',
              progressPercent: dailyProgress,
            ),
            const SizedBox(height: 14),
            _metricRows(<_MetricData>[
              _MetricData(
                'Rémunération théorique',
                formatCfa(theoreticalTotal),
              ),
              _MetricData(
                'Rémunération éligible',
                formatCfa(eligibleTotal),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: activePlan
                    ? IzyTelColors.successSoft
                    : IzyTelColors.warningSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                activePlan
                    ? 'Le plan est actif. Une rémunération ne peut être clôturée que pour un mois terminé dont les deux seuils sont atteints.'
                    : 'Simulation uniquement : le plan Manager ${teamString(plan['planCode'])} est encore en brouillon. Les montants théoriques ne constituent pas une dette IzyTel.',
                style: TextStyle(
                  color: activePlan
                      ? IzyTelColors.success
                      : IzyTelColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            if (_isAdmin) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _financeBusy || !activePlan
                      ? null
                      : () => _chooseAndCloseManagerPeriod(detail),
                  icon: const Icon(Symbols.event_available_rounded),
                  label: const Text('Clôturer un mois terminé'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _progressLine({
    required String label,
    required String current,
    required String target,
    required double progressPercent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${progressPercent.toStringAsFixed(2)} %',
              style: const TextStyle(
                color: IzyTelColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$current / $target',
          style: const TextStyle(
            color: IzyTelColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: (progressPercent / 100).clamp(0, 1).toDouble(),
        ),
      ],
    );
  }

  Widget _profile(TeamMemberDetail detail, TeamScopeSnapshot scope) {
    final Map<String, dynamic> profile = detail.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _collapsibleSection(
          title: 'Coordonnées',
          icon: Symbols.person_rounded,
          children: <Widget>[
            _line('Prénom(s)', teamString(profile['first_name'])),
            _line('Nom', teamString(profile['last_name'])),
            _line('E-mail', teamString(profile['email'])),
            _line('Téléphone', teamString(profile['phone_number'])),
            _line(
              'Téléphone secondaire',
              teamString(profile['secondary_phone']),
            ),
            _line('Date de naissance', _date(profile['date_of_birth'])),
            _line('Ville', teamString(profile['city'])),
            _line('Adresse', teamString(profile['address'])),
            _line(
              'Contact d’urgence',
              <String>[
                teamString(profile['emergency_contact_name']),
                teamString(profile['emergency_contact_phone']),
              ].where((String value) => value.isNotEmpty).join(' · '),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _collapsibleSection(
          title: 'Identité et vérification',
          icon: Symbols.verified_rounded,
          children: <Widget>[
            _line(
              'Statut',
              _verificationLabel(
                teamString(profile['verification_status']),
              ),
            ),
            _line(
              'Type de pièce',
              teamString(profile['identity_document_type']),
            ),
            _line(
              'N° de pièce',
              teamString(profile['identity_document_number']),
            ),
            _line(
              'Fichier de pièce',
              teamString(profile['identity_document_file_name']),
            ),
            _line(
              'Note de vérification',
              teamString(profile['verification_note']),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _collapsibleSection(
          title: detail.actorType == 'manager'
              ? 'Zones supervisées'
              : 'Zones assignées',
          icon: Symbols.location_on_rounded,
          children: <Widget>[
            _zoneContent(detail, scope),
          ],
        ),
        const SizedBox(height: 10),
        _collapsibleSection(
          title: 'Informations opérationnelles',
          icon: detail.actorType == 'cabiniste'
              ? Symbols.storefront_rounded
              : Symbols.settings_account_box_rounded,
          children: _profileOperationLines(detail),
        ),
        const SizedBox(height: 10),
        _collapsibleSection(
          title: 'Informations administratives',
          icon: Symbols.info_rounded,
          children: <Widget>[
            _line('Identifiant', detail.actorId),
            _line('Dernière activité', _memberLastActivity(detail)),
            _line('Rôle', _roleLabel(detail.actorType)),
          ],
        ),
      ],
    );
  }

  Widget _zoneContent(TeamMemberDetail detail, TeamScopeSnapshot scope) {
    final List<String> labels = _zoneLabels(detail, scope);
    final bool canEdit = widget.viewer.permissions.canManageAgents &&
        detail.actorType == 'cabiniste';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        if (canEdit) ...<Widget>[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _savingZones
                  ? null
                  : () => _editCabinisteZones(detail, scope),
              icon: const Icon(Symbols.edit_location_alt_rounded, size: 18),
              label: const Text('Modifier les zones'),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _profileOperationLines(TeamMemberDetail detail) {
    if (detail.actorType == 'agent') {
      final Map<String, dynamic> op = detail.operations;
      return <Widget>[
        _line('Code Agent', teamString(op['agent_code'])),
        _line('Disponibilité', _availabilityLabel(teamString(op['availability']))),
        _line(
          'Réseaux autorisés',
          teamStrings(op['authorized_networks']).join(' · ').toUpperCase(),
        ),
        _line(
          'Réseaux actifs',
          teamStrings(op['active_networks']).join(' · ').toUpperCase(),
        ),
        _line(
          'Plafond journalier',
          formatCfa(teamInt(op['daily_transaction_limit'])),
        ),
        _line(
          'Transactions / jour',
          '${teamInt(op['max_transactions_per_day'])}',
        ),
      ];
    }
    if (detail.actorType == 'cabiniste') {
      final Map<String, dynamic> account =
          teamMap(detail.operations['account']);
      return <Widget>[
        _line('Code Cabiniste', teamString(account['partner_code'])),
        _line('Statut', teamString(account['status'])),
        _line('Disponibilité', _availabilityLabel(teamString(account['availability']))),
        _line(
          'Réseaux autorisés',
          teamStrings(account['authorized_networks']).join(' · ').toUpperCase(),
        ),
        _line(
          'Réseaux actifs',
          teamStrings(account['active_networks']).join(' · ').toUpperCase(),
        ),
      ];
    }
    final Map<String, dynamic> manager =
        teamMap(detail.operations['managerProfile']);
    return <Widget>[
      _line('Compte', manager['is_active'] == true ? 'Actif' : 'Suspendu'),
      _line(
        'Disponibilité',
        manager['is_available'] == true ? 'Disponible' : 'Indisponible',
      ),
      _line('Dernière activité', _dateTime(manager['last_activity_at'])),
    ];
  }

  Widget _history(TeamMemberDetail detail) {
    if (detail.actorType == 'manager') {
      final Map<String, dynamic> history =
          teamMap(detail.finance['compensationHistory']);
      return ManagerCompensationHistoryCard(
        history: history,
        adminMode: _isAdmin,
        busy: _financeBusy,
        onApprove: _isAdmin ? _approveManagerPeriod : null,
        onAdjust: _isAdmin ? _adjustManagerPeriod : null,
        onPayout: _isAdmin
            ? (Map<String, dynamic> period) => _payManagerPeriod(detail, period)
            : null,
      );
    }

    final Map<String, dynamic> activityHistory =
        teamMap(detail.finance['activityHistory']);
    final List<Map<String, dynamic>> earnings =
        _mapList(activityHistory['earnings']);
    final List<Map<String, dynamic>> payouts =
        _mapList(activityHistory['payouts']);
    final List<Map<String, dynamic>> movements =
        _mapList(activityHistory['movements']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _historySection(
          title: detail.actorType == 'agent'
              ? 'Commissions récentes'
              : 'Reversements acquis',
          icon: Symbols.payments_rounded,
          rows: earnings,
          rowBuilder: (Map<String, dynamic> row) => _historyTile(
            title: teamString(row['orderReference']).isEmpty
                ? (detail.actorType == 'agent' ? 'Commission' : 'Reversement')
                : 'Commande ${teamString(row['orderReference'])}',
            subtitle: <String>[
              teamString(row['network']).toUpperCase(),
              _dateTime(row['occurredAt']),
            ].where((String value) => value.isNotEmpty).join(' · '),
            trailing: formatCfa(teamInt(row['amount'])),
          ),
        ),
        const SizedBox(height: 10),
        _historySection(
          title: 'Versements',
          icon: Symbols.account_balance_wallet_rounded,
          rows: payouts,
          rowBuilder: (Map<String, dynamic> row) => _historyTile(
            title: teamString(row['reference']).isEmpty
                ? 'Versement'
                : teamString(row['reference']),
            subtitle: <String>[
              teamString(row['channel']).toUpperCase(),
              _dateTime(row['occurredAt']),
            ].where((String value) => value.isNotEmpty).join(' · '),
            trailing: formatCfa(teamInt(row['amount'])),
          ),
        ),
        const SizedBox(height: 10),
        _historySection(
          title: 'Mouvements de capacité',
          icon: Symbols.receipt_long_rounded,
          rows: movements,
          rowBuilder: (Map<String, dynamic> row) => _historyTile(
            title: <String>[
              teamString(row['network']).toUpperCase(),
              teamString(row['movementType']),
            ].where((String value) => value.isNotEmpty).join(' · '),
            subtitle: <String>[
              teamString(row['orderReference']).isEmpty
                  ? ''
                  : 'Commande ${teamString(row['orderReference'])}',
              _dateTime(row['occurredAt']),
            ].where((String value) => value.isNotEmpty).join(' · '),
            trailing: formatCfa(teamInt(row['amount'])),
          ),
        ),
      ],
    );
  }

  Widget _historySection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
    required Widget Function(Map<String, dynamic> row) rowBuilder,
  }) {
    return _section(
      title: title,
      icon: icon,
      children: <Widget>[
        if (rows.isEmpty)
          const Text(
            'Aucun mouvement enregistré.',
            style: TextStyle(color: IzyTelColors.textSecondary),
          )
        else
          ...rows.take(20).map(rowBuilder),
      ],
    );
  }

  Widget _historyTile({
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.isEmpty ? 'Mouvement' : title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: IzyTelColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            trailing,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _collapsibleSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return IzyTelSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: Icon(icon, color: IzyTelColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        children: children,
      ),
    );
  }

  Widget _metricRows(List<_MetricData> metrics) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics.map((_MetricData metric) {
        return Container(
          width: MediaQuery.sizeOf(context).width >= 700
              ? 210
              : (MediaQuery.sizeOf(context).width - 50) / 2,
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
                metric.value,
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
            width: 138,
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

  Widget _stateChip(String label, {required bool positive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: positive ? IzyTelColors.successSoft : IzyTelColors.warningSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: positive ? IzyTelColors.success : IzyTelColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  List<String> _zoneLabels(TeamMemberDetail detail, TeamScopeSnapshot scope) {
    final Map<String, TeamScopeZone> byId = <String, TeamScopeZone>{
      for (final TeamScopeZone zone in scope.zones) zone.id: zone,
    };
    return detail.zoneIds
        .map((String id) => byId[id]?.label ?? id)
        .toList(growable: false);
  }

  String _memberStatus(TeamMemberDetail detail) {
    if (detail.actorType == 'agent') {
      final String availability = teamString(detail.operations['availability']);
      return availability.isEmpty
          ? 'Statut non renseigné'
          : _availabilityLabel(availability);
    }
    if (detail.actorType == 'cabiniste') {
      final Map<String, dynamic> account =
          teamMap(detail.operations['account']);
      final bool active = teamString(account['status']) == 'active';
      final String availability = teamString(account['availability']);
      return <String>[
        active ? 'Actif' : 'Suspendu',
        if (availability.isNotEmpty) _availabilityLabel(availability),
      ].join(' · ');
    }
    final Map<String, dynamic> manager =
        teamMap(detail.operations['managerProfile']);
    return <String>[
      manager['is_active'] == true ? 'Actif' : 'Suspendu',
      manager['is_available'] == true ? 'Disponible' : 'Indisponible',
    ].join(' · ');
  }

  String _memberLastActivity(TeamMemberDetail detail) {
    if (detail.actorType == 'manager') {
      return _dateTime(
        teamMap(detail.operations['managerProfile'])['last_activity_at'],
      );
    }
    return _dateTime(detail.profile['last_activity_at']);
  }

  String _availabilityLabel(String raw) => switch (raw.toLowerCase()) {
        'available' => 'Disponible',
        'unavailable' => 'Indisponible',
        'busy' => 'Occupé',
        'offline' => 'Hors ligne',
        '' => 'Non renseigné',
        _ => raw,
      };

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

  String _clean(Object error) {
    final String raw = error.toString();
    if (raw.contains('MANAGER_COMPENSATION_THRESHOLDS_NOT_MET')) {
      return 'Les seuils de rémunération ne sont pas atteints pour cette période.';
    }
    if (raw.contains('MANAGER_COMPENSATION_PLAN_NOT_ACTIVE')) {
      return 'Le plan de rémunération Manager doit être activé avant toute clôture.';
    }
    if (raw.contains('MANAGER_PERIOD_NOT_CLOSED_YET')) {
      return 'Seul un mois entièrement terminé peut être clôturé.';
    }
    if (raw.contains('STAFF_AGENT_SCOPE_REQUIRED') ||
        raw.contains('CAPACITY_ADJUST_DENIED')) {
      return 'Vous n’êtes pas autorisé à modifier la capacité de cet Agent.';
    }
    return raw
        .replaceFirst('PostgrestException(message: ', '')
        .replaceFirst('Exception: ', '');
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);
  final String label;
  final String value;
}

enum _MemberDetailTab { overview, profile, history }

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
