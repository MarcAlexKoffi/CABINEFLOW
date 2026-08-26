import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_detail_page.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_management_view_model.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';

class AgentManagementPage extends StatefulWidget {
  const AgentManagementPage({
    super.key,
    required this.user,
    required this.repository,
  });

  final AppUser user;
  final AgentRepository repository;

  @override
  State<AgentManagementPage> createState() => _AgentManagementPageState();
}

class _AgentManagementPageState extends State<AgentManagementPage> {
  late final AgentManagementViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = AgentManagementViewModel(repository: widget.repository);
    _viewModel.start();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openAgent(AgentDirectoryEntry agent) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AgentDetailPage(
          agent: agent,
          zones: _viewModel.zones,
          repository: widget.repository,
        ),
      ),
    );
  }

  Future<void> _addAgent() async {
    final List<StaffAccountSummary> pending;
    try {
      pending = await _viewModel.loadPendingAccounts();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossible de charger les comptes en attente.');
      return;
    }
    if (!mounted) return;
    if (pending.isEmpty) {
      _showMessage(
        'Aucun compte en attente. Le futur agent doit d’abord se connecter une fois afin de créer son profil en attente.',
      );
      return;
    }

    final StaffAccountSummary?
    selected = await showModalBottomSheet<StaffAccountSummary>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activer un nouvel agent',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choisis un compte CabineFlow qui attend encore son activation.',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pending.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final StaffAccountSummary account = pending[index];
                      return ListTile(
                        tileColor: AppColors.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(
                            color: AppColors.outlineVariant,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withAlpha(35),
                          child: Text(
                            _initial(account.name),
                            style: const TextStyle(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          account.name,
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          account.email,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryContainer,
                        ),
                        onTap: () => Navigator.of(context).pop(account),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Activer cet agent ?'),
            content: Text(
              '${selected.name} pourra ensuite se connecter à son espace Agent. Tu pourras configurer ses zones et réseaux juste après.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Activer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    try {
      await _viewModel.activatePendingAccount(selected);
      if (!mounted) return;
      _showMessage(
        'Agent activé. Ouvre sa fiche pour terminer la configuration.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Impossible d’activer ce compte comme agent.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return ListenableBuilder(
          listenable: _viewModel,
          builder: (_, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtres agents',
                      style: TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _filterTitle('Disponibilité'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _choiceChip(
                          'Toutes',
                          _viewModel.availabilityFilter == null,
                          () => _viewModel.setAvailability(null),
                        ),
                        ...AgentAvailability.values.map(
                          (value) => _choiceChip(
                            value.label,
                            _viewModel.availabilityFilter == value,
                            () => _viewModel.setAvailability(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _filterTitle('Réseau'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _choiceChip(
                          'Tous',
                          _viewModel.networkFilter == null,
                          () => _viewModel.setNetwork(null),
                        ),
                        ...AgentNetwork.values.map(
                          (value) => _choiceChip(
                            value.label,
                            _viewModel.networkFilter == value,
                            () => _viewModel.setNetwork(value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _filterTitle('Statut'),
                    Wrap(
                      spacing: 8,
                      children: [
                        _choiceChip(
                          'Tous',
                          _viewModel.activeFilter == null,
                          () => _viewModel.setActive(null),
                        ),
                        _choiceChip(
                          'Actifs',
                          _viewModel.activeFilter == true,
                          () => _viewModel.setActive(true),
                        ),
                        _choiceChip(
                          'Suspendus',
                          _viewModel.activeFilter == false,
                          () => _viewModel.setActive(false),
                        ),
                      ],
                    ),
                    if (_viewModel.zones.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _filterTitle('Zone'),
                      DropdownButtonFormField<String?>(
                        key: ValueKey<String?>(_viewModel.zoneFilter),
                        initialValue: _viewModel.zoneFilter,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceContainerHigh,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Toutes les zones'),
                          ),
                          ..._viewModel.zones.map(
                            (zone) => DropdownMenuItem<String?>(
                              value: zone.id,
                              child: Text(
                                zone.displayLabel,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: _viewModel.setZone,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _viewModel.clearFilters,
                            child: const Text('Réinitialiser'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Appliquer'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _filterTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withAlpha(55),
      backgroundColor: AppColors.surfaceContainerHigh,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.outlineVariant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gestion des agents'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary.withAlpha(35),
              child: Text(
                _initial(widget.user.name),
                style: const TextStyle(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAgent,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (_, _) {
            final List<AgentDirectoryEntry> agents = _viewModel.filteredAgents;
            return RefreshIndicator(
              onRefresh: _viewModel.start,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                children: [
                  const Text(
                    'Gestion des Agents',
                    style: TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Surveille la disponibilité, les zones et les réseaux autorisés.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          value: '${_viewModel.agents.length}',
                          label: 'Agents',
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _MetricCard(
                          value: '${_viewModel.availableCount}',
                          label: 'Disponibles',
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_viewModel.recentIssues.isNotEmpty) ...[
                    _AgentIssuesPanel(
                      issues: _viewModel.recentIssues,
                      openCount: _viewModel.openIssueCount,
                      agentNameFor: _viewModel.agentNameFor,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextField(
                    controller: _searchController,
                    onChanged: _viewModel.updateSearch,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un agent…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Filtres'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_viewModel.isLoading && _viewModel.agents.isEmpty)
                    const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.errorMessage != null &&
                      _viewModel.agents.isEmpty)
                    _MessageCard(
                      icon: Icons.cloud_off_rounded,
                      title: 'Agents indisponibles',
                      message: _viewModel.errorMessage!,
                    )
                  else if (agents.isEmpty)
                    const _MessageCard(
                      icon: Icons.groups_2_outlined,
                      title: 'Aucun agent',
                      message: 'Aucun agent ne correspond aux filtres actuels.',
                    )
                  else ...[
                    Text(
                      '${agents.length} agent${agents.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...agents.map(
                      (agent) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AgentCard(
                          agent: agent,
                          zones: _viewModel.zones,
                          onTap: () => _openAgent(agent),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AgentIssuesPanel extends StatelessWidget {
  const _AgentIssuesPanel({
    required this.issues,
    required this.openCount,
    required this.agentNameFor,
  });

  final List<AgentIssue> issues;
  final int openCount;
  final String Function(String agentId) agentNameFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withAlpha(105)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_outlined,
                color: AppColors.warning,
                size: 21,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Signalements agents',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.warning.withAlpha(95)),
                ),
                child: Text(
                  '$openCount ouvert${openCount > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Les derniers incidents transmis par les agents apparaissent ici en temps réel.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...issues.map((issue) {
            final String agentName = agentNameFor(issue.agentId);
            final String network = issue.network?.label ?? 'Tous réseaux';
            final Color statusColor = _issueStatusColor(issue.status);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$agentName • ${_issueTypeLabel(issue.type)}',
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _StatusBadge(
                        label: _issueStatusLabel(issue.status),
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    issue.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '$network • ${_relative(issue.createdAt)}',
                    style: const TextStyle(
                      color: AppColors.primaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({
    required this.agent,
    required this.zones,
    required this.onTap,
  });

  final AgentDirectoryEntry agent;
  final List<AgentZone> zones;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AgentProfile? profile = agent.profile;
    final String zoneLabel = _zoneLabel(profile, zones);
    final bool available =
        agent.isActive && agent.availability == AgentAvailability.available;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withAlpha(35),
                    child: Text(
                      _initial(agent.name),
                      style: const TextStyle(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          agent.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          agent.agentCode,
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    label: !agent.isActive
                        ? 'Suspendu'
                        : available
                        ? 'Disponible'
                        : 'Indisponible',
                    color: !agent.isActive
                        ? AppColors.error
                        : available
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _line(Icons.location_on_outlined, zoneLabel),
              const SizedBox(height: 7),
              _line(
                Icons.schedule_rounded,
                profile?.lastSeenAt == null
                    ? 'Aucune activité récente'
                    : 'Dernière activité : ${_relative(profile!.lastSeenAt!)}',
              ),
              if (profile != null && profile.authorizedNetworks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: profile.authorizedNetworks
                      .map((network) => _NetworkBadge(network: network))
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.primaryContainer),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    ],
  );
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge({required this.network});
  final AgentNetwork network;

  @override
  Widget build(BuildContext context) {
    final Color color = _networkColor(network);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        network.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(28),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withAlpha(95)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.onSurfaceVariant, size: 34),
        const SizedBox(height: 10),
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
  );
}

String _issueTypeLabel(String value) {
  switch (value) {
    case 'network':
      return 'Réseau';
    case 'balance':
      return 'Solde / capacité';
    case 'technical':
      return 'Technique';
    case 'other':
      return 'Autre';
    default:
      return 'Incident';
  }
}

String _issueStatusLabel(String value) {
  switch (value) {
    case 'open':
      return 'Ouvert';
    case 'acknowledged':
      return 'Pris en compte';
    case 'resolved':
      return 'Résolu';
    case 'cancelled':
      return 'Annulé';
    default:
      return value;
  }
}

Color _issueStatusColor(String value) {
  switch (value) {
    case 'resolved':
      return AppColors.success;
    case 'cancelled':
      return AppColors.onSurfaceVariant;
    case 'acknowledged':
      return AppColors.primaryContainer;
    case 'open':
    default:
      return AppColors.warning;
  }
}

String _zoneLabel(AgentProfile? profile, List<AgentZone> zones) {
  if (profile == null || profile.zoneIds.isEmpty) return 'Aucune zone assignée';
  final List<String> names = zones
      .where((zone) => profile.zoneIds.contains(zone.id))
      .map((zone) => zone.displayLabel)
      .toList(growable: false);
  return names.isEmpty
      ? '${profile.zoneIds.length} zone(s)'
      : names.join(' • ');
}

String _relative(DateTime value) {
  final Duration difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'à l’instant';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min';
  if (difference.inHours < 24) return '${difference.inHours} h';
  return '${difference.inDays} j';
}

String _initial(String value) {
  final String cleaned = value.trim();
  return cleaned.isEmpty ? '?' : cleaned.substring(0, 1).toUpperCase();
}

Color _networkColor(AgentNetwork network) {
  switch (network) {
    case AgentNetwork.orange:
      return AppColors.orange;
    case AgentNetwork.mtn:
      return AppColors.mtn;
    case AgentNetwork.moov:
      return AppColors.primaryContainer;
  }
}
