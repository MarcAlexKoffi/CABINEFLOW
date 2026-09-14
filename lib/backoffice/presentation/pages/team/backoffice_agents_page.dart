import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _AgentScope { all, active, available, unavailable, incomplete }

class BackofficeAgentsPage extends StatefulWidget {
  const BackofficeAgentsPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgentRepository repository;

  @override
  State<BackofficeAgentsPage> createState() => _BackofficeAgentsPageState();
}

class _BackofficeAgentsPageState extends State<BackofficeAgentsPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<AgentDirectoryEntry>> _agentsStream;
  late final Stream<List<AgentZone>> _zonesStream;
  _AgentScope _scope = _AgentScope.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _agentsStream = widget.repository.watchAgents();
    _zonesStream = widget.repository.watchZones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AgentDirectoryEntry>>(
      stream: _agentsStream,
      builder: (BuildContext context, AsyncSnapshot<List<AgentDirectoryEntry>> agentsSnapshot) {
        if (agentsSnapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.cloud_off_rounded,
            title: 'Annuaire Agents indisponible',
            message: 'Les profils Agents ne peuvent pas être chargés pour le moment.',
          );
        }
        if (!agentsSnapshot.hasData) return const Center(child: CircularProgressIndicator());

        return StreamBuilder<List<AgentZone>>(
          stream: _zonesStream,
          builder: (BuildContext context, AsyncSnapshot<List<AgentZone>> zonesSnapshot) {
            final List<AgentZone> zones = zonesSnapshot.data ?? const <AgentZone>[];
            final Map<String, AgentZone> zoneById = <String, AgentZone>{for (final AgentZone zone in zones) zone.id: zone};
            final List<AgentDirectoryEntry> all = agentsSnapshot.data!;
            final List<AgentDirectoryEntry> visible = _filtered(all, zoneById);
            final int active = all.where((AgentDirectoryEntry item) => item.isActive).length;
            final int available = all.where((AgentDirectoryEntry item) => item.isActive && item.availability == AgentAvailability.available).length;
            final int incomplete = all.where((AgentDirectoryEntry item) => item.profile == null).length;
            final int totalCapacity = all.fold<int>(0, (int total, AgentDirectoryEntry item) {
              final AgentProfile? p = item.profile;
              if (p == null) return total;
              return total + p.orangeCapacity + p.mtnCapacity + p.moovCapacity;
            });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                BackofficePageIntro(
                  eyebrow: 'Équipe / Agents',
                  title: 'Annuaire et supervision des Agents',
                  description: widget.user.permissions.canManageAgents
                      ? 'Supervise la disponibilité, les réseaux, les capacités et les zones des Agents depuis un espace de gestion unique.'
                      : 'Consulte l’état opérationnel des Agents, leurs réseaux et leurs capacités sans modifier les paramètres administratifs.',
                  icon: Symbols.badge_rounded,
                ),
                const SizedBox(height: 18),
                _metrics(total: all.length, active: active, available: available, incomplete: incomplete, totalCapacity: totalCapacity),
                const SizedBox(height: 14),
                _filters(),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const BackofficeEmptyState(
                    icon: Symbols.group_off_rounded,
                    title: 'Aucun Agent dans cette vue',
                    message: 'Modifie la recherche ou les filtres pour afficher d’autres Agents.',
                  )
                else
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      if (constraints.maxWidth >= 980) return _desktopTable(visible, zoneById, zones);
                      return Column(
                        children: visible.map((AgentDirectoryEntry agent) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _mobileCard(agent, zoneById, zones),
                        )).toList(growable: false),
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _metrics({required int total, required int active, required int available, required int incomplete, required int totalCapacity}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        final double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'Agents', value: '$total', caption: '$active comptes actifs', icon: Symbols.groups_rounded),
          BackofficeMetricCard(label: 'Disponibles', value: '$available', caption: 'prêts à recevoir', icon: Symbols.task_alt_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Capacité', value: formatCfa(totalCapacity), caption: 'solde télécom cumulé', icon: Symbols.account_balance_wallet_rounded, emphasis: BackofficePalette.cyan),
          BackofficeMetricCard(label: 'À compléter', value: '$incomplete', caption: 'profils opérationnels', icon: Symbols.warning_rounded, emphasis: incomplete > 0 ? BackofficePalette.warning : BackofficePalette.success),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList());
      },
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(hintText: 'Nom, code Agent, téléphone, e-mail ou zone', prefixIcon: Icon(Symbols.search_rounded)),
          );
          final Widget scope = DropdownButtonFormField<_AgentScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: const <DropdownMenuItem<_AgentScope>>[
              DropdownMenuItem(value: _AgentScope.all, child: Text('Tous')),
              DropdownMenuItem(value: _AgentScope.active, child: Text('Comptes actifs')),
              DropdownMenuItem(value: _AgentScope.available, child: Text('Disponibles')),
              DropdownMenuItem(value: _AgentScope.unavailable, child: Text('Indisponibles')),
              DropdownMenuItem(value: _AgentScope.incomplete, child: Text('Profil incomplet')),
            ],
            onChanged: (_AgentScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          if (constraints.maxWidth < 760) return Column(children: <Widget>[search, const SizedBox(height: 10), scope]);
          return Row(children: <Widget>[Expanded(flex: 3, child: search), const SizedBox(width: 10), SizedBox(width: 250, child: scope)]);
        },
      ),
    );
  }

  List<AgentDirectoryEntry> _filtered(List<AgentDirectoryEntry> all, Map<String, AgentZone> zones) {
    final String query = _query.trim().toLowerCase();
    final List<AgentDirectoryEntry> result = all.where((AgentDirectoryEntry agent) {
      final bool inScope = switch (_scope) {
        _AgentScope.all => true,
        _AgentScope.active => agent.isActive,
        _AgentScope.available => agent.isActive && agent.availability == AgentAvailability.available,
        _AgentScope.unavailable => agent.availability == AgentAvailability.unavailable,
        _AgentScope.incomplete => agent.profile == null,
      };
      if (!inScope) return false;
      if (query.isEmpty) return true;
      final String zoneNames = (agent.profile?.zoneIds ?? const <String>[]).map((String id) => zones[id]?.displayLabel ?? id).join(' ');
      return <String>[agent.name, agent.email, agent.phoneNumber, agent.agentCode, zoneNames].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
    result.sort((AgentDirectoryEntry a, AgentDirectoryEntry b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  Widget _desktopTable(List<AgentDirectoryEntry> agents, Map<String, AgentZone> zoneById, List<AgentZone> zones) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'AGENT', flex: 4),
        BackofficeTableColumnSpec(label: 'ÉTAT', flex: 2),
        BackofficeTableColumnSpec(label: 'RÉSEAUX', flex: 3),
        BackofficeTableColumnSpec(label: 'CAPACITÉS', flex: 4),
        BackofficeTableColumnSpec(label: 'ZONE', flex: 3),
        BackofficeTableColumnSpec(label: 'ACTION', flex: 2, alignment: Alignment.centerRight),
      ],
      rows: agents.map((AgentDirectoryEntry agent) {
        final AgentProfile? profile = agent.profile;
        return BackofficeDesktopTableRow(
          accentColor: !agent.isActive ? BackofficePalette.danger : agent.availability == AgentAvailability.available ? BackofficePalette.success : null,
          onTap: () => _openDetails(agent, zoneById, zones),
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(flex: 4, child: _twoLines(agent.name, '${agent.agentCode} • ${agent.phoneNumber.isEmpty ? agent.email : agent.phoneNumber}')),
            BackofficeTableCellSpec(flex: 2, child: BackofficeStatusBadge(label: !agent.isActive ? 'Suspendu' : agent.availability.label, color: !agent.isActive ? BackofficePalette.danger : agent.availability == AgentAvailability.available ? BackofficePalette.success : BackofficePalette.warning)),
            BackofficeTableCellSpec(flex: 3, child: _networkChips(profile)),
            BackofficeTableCellSpec(flex: 4, child: _capacitySummary(profile)),
            BackofficeTableCellSpec(flex: 3, child: Text(_zonesLabel(profile, zoneById), maxLines: 2, overflow: TextOverflow.ellipsis)),
            BackofficeTableCellSpec(flex: 2, alignment: Alignment.centerRight, child: OutlinedButton(onPressed: () => _openDetails(agent, zoneById, zones), child: Text(widget.user.permissions.canManageAgents ? 'Gérer' : 'Voir'))),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(AgentDirectoryEntry agent, Map<String, AgentZone> zoneById, List<AgentZone> zones) {
    final AgentProfile? profile = agent.profile;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(agent, zoneById, zones),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              CircleAvatar(backgroundColor: BackofficePalette.primarySoft, foregroundColor: BackofficePalette.primaryStrong, child: Text(_initials(agent.name), style: const TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: _twoLines(agent.name, agent.agentCode)),
              BackofficeStatusBadge(label: !agent.isActive ? 'Suspendu' : agent.availability.label, color: !agent.isActive ? BackofficePalette.danger : agent.availability == AgentAvailability.available ? BackofficePalette.success : BackofficePalette.warning),
            ]),
            const SizedBox(height: 12),
            _networkChips(profile),
            const SizedBox(height: 10),
            Text(_zonesLabel(profile, zoneById), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            _capacitySummary(profile),
          ]),
        ),
      ),
    );
  }

  Widget _networkChips(AgentProfile? profile) {
    final List<AgentNetwork> networks = profile?.authorizedNetworks ?? const <AgentNetwork>[];
    if (networks.isEmpty) return Text('Aucun réseau', style: Theme.of(context).textTheme.bodySmall);
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: networks.map((AgentNetwork network) {
        final bool active = profile?.activeNetworks.contains(network) ?? false;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(color: active ? BackofficePalette.primarySoft : BackofficePalette.surfaceAlt, borderRadius: BorderRadius.circular(8)),
          child: Text(network.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: active ? BackofficePalette.primaryStrong : BackofficePalette.muted, fontWeight: FontWeight.w800)),
        );
      }).toList(growable: false),
    );
  }

  Widget _capacitySummary(AgentProfile? profile) {
    if (profile == null) return Text('Profil à compléter', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.warning, fontWeight: FontWeight.w700));
    return Text('Orange ${formatCfa(profile.orangeCapacity)}  •  MTN ${formatCfa(profile.mtnCapacity)}  •  Moov ${formatCfa(profile.moovCapacity)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: BackofficePalette.ink, fontWeight: FontWeight.w600));
  }

  String _zonesLabel(AgentProfile? profile, Map<String, AgentZone> zoneById) {
    final List<String> ids = profile?.zoneIds ?? const <String>[];
    if (ids.isEmpty) return 'Aucune zone';
    return ids.map((String id) => zoneById[id]?.displayLabel ?? id).join(', ');
  }

  Widget _twoLines(String title, String subtitle) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Future<void> _openDetails(AgentDirectoryEntry agent, Map<String, AgentZone> zoneById, List<AgentZone> zones) async {
    if (widget.user.permissions.canManageAgents && agent.profile != null) {
      await _openManageDialog(agent, zones);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(agent.name),
        content: SizedBox(
          width: 620,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            _detail('Code Agent', agent.agentCode),
            _detail('Téléphone', agent.phoneNumber.isEmpty ? 'Non renseigné' : agent.phoneNumber),
            _detail('E-mail', agent.email.isEmpty ? 'Non renseigné' : agent.email),
            _detail('Disponibilité', agent.availability.label),
            _detail('Zones', _zonesLabel(agent.profile, zoneById)),
            _detail('Capacités', agent.profile == null ? 'Profil opérationnel à compléter' : 'Orange ${formatCfa(agent.profile!.orangeCapacity)} • MTN ${formatCfa(agent.profile!.mtnCapacity)} • Moov ${formatCfa(agent.profile!.moovCapacity)}'),
          ]),
        ),
        actions: <Widget>[TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }

  Future<void> _openManageDialog(AgentDirectoryEntry agent, List<AgentZone> zones) async {
    final AgentProfile profile = agent.profile!;
    final TextEditingController nameController = TextEditingController(text: agent.name);
    final TextEditingController phoneController = TextEditingController(text: agent.phoneNumber);
    final TextEditingController orangeController = TextEditingController(text: '${profile.orangeCapacity}');
    final TextEditingController mtnController = TextEditingController(text: '${profile.mtnCapacity}');
    final TextEditingController moovController = TextEditingController(text: '${profile.moovCapacity}');
    final TextEditingController dailyController = TextEditingController(text: '${profile.dailyTransactionLimit}');
    final TextEditingController maxController = TextEditingController(text: '${profile.maxTransactionsPerDay}');
    bool isActive = agent.isActive;
    final Set<String> selectedZones = profile.zoneIds.toSet();
    final Set<AgentNetwork> selectedNetworks = profile.authorizedNetworks.toSet();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          int amount(TextEditingController controller) => int.tryParse(controller.text.trim()) ?? 0;
          return AlertDialog(
            title: Text('Gérer ${agent.name}'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(child: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Téléphone'))),
                  ]),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('Compte actif'), subtitle: Text(isActive ? 'L’Agent peut être utilisé dans les flux opérationnels.' : 'Le compte est suspendu.'), value: isActive, onChanged: (bool value) => setDialogState(() => isActive = value)),
                  const SizedBox(height: 6),
                  Text('RÉSEAUX AUTORISÉS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: AgentNetwork.values.map((AgentNetwork network) => FilterChip(label: Text(network.label), selected: selectedNetworks.contains(network), onSelected: (bool selected) => setDialogState(() {
                      if (selected) {
                        selectedNetworks.add(network);
                      } else {
                        selectedNetworks.remove(network);
                      }
                    }))).toList()),
                  const SizedBox(height: 14),
                  Row(children: <Widget>[
                    Expanded(child: TextField(controller: orangeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacité Orange'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: mtnController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacité MTN'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: moovController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Capacité Moov'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: <Widget>[
                    Expanded(child: TextField(controller: dailyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limite quotidienne'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: maxController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Transactions max / jour'))),
                  ]),
                  const SizedBox(height: 14),
                  Text('ZONES', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: zones.map((AgentZone zone) => FilterChip(label: Text(zone.displayLabel), selected: selectedZones.contains(zone.id), onSelected: (bool selected) => setDialogState(() {
                      if (selected) {
                        selectedZones.add(zone.id);
                      } else {
                        selectedZones.remove(zone.id);
                      }
                    }))).toList()),
                  if (zones.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Aucune zone disponible.', style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
            ),
            actions: <Widget>[
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Annuler')),
              FilledButton(
                onPressed: saving ? null : () async {
                  setDialogState(() => saving = true);
                  try {
                    await widget.repository.saveAgentAdmin(
                      agent: agent,
                      update: AgentAdminUpdate(
                        name: nameController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        isActive: isActive,
                        zoneIds: selectedZones.toList(growable: false),
                        authorizedNetworks: selectedNetworks.toList(growable: false),
                        orangeCapacity: amount(orangeController),
                        mtnCapacity: amount(mtnController),
                        moovCapacity: amount(moovController),
                        dailyTransactionLimit: amount(dailyController),
                        maxTransactionsPerDay: amount(maxController),
                      ),
                    );
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Profil Agent mis à jour.')));
                  } catch (error) {
                    if (!dialogContext.mounted) return;
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text(error.toString())));
                    setDialogState(() => saving = false);
                  }
                },
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    orangeController.dispose();
    mtnController.dispose();
    moovController.dispose();
    dailyController.dispose();
    maxController.dispose();
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ]),
    );
  }

  String _initials(String name) {
    final List<String> parts = name.trim().split(RegExp(r'\s+')).where((String item) => item.isNotEmpty).toList();
    if (parts.isEmpty) return 'AG';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
