import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_detail_page.dart';
import 'package:cabine_flow/features/agents/presentation/widgets/agent_directory_avatar.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_management_view_model.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
  Timer? _clockTimer;
  late final AgentManagementViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    _viewModel = AgentManagementViewModel(repository: widget.repository);
    _viewModel.start();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
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
      backgroundColor: IzyTelColors.surface,
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
                    color: IzyTelColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choisis un compte IzyTel qui attend encore son activation.',
                  style: TextStyle(color: IzyTelColors.textSecondary),
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
                        tileColor: IzyTelColors.surfaceMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: IzyTelColors.outline),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: IzyTelColors.primary.withAlpha(35),
                          child: Text(
                            _initial(account.name),
                            style: const TextStyle(
                              color: IzyTelColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          account.name,
                          style: const TextStyle(
                            color: IzyTelColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          account.email,
                          style: const TextStyle(
                            color: IzyTelColors.textSecondary,
                          ),
                        ),
                        trailing: const Icon(
                          Symbols.chevron_right_rounded,
                          color: IzyTelColors.primary,
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
    IzyTelFeedback.show(context, message);
  }

  Future<void> _showFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: IzyTelColors.surface,
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
                        color: IzyTelColors.textPrimary,
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
                        dropdownColor: IzyTelColors.surfaceMuted,
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
        color: IzyTelColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: IzyTelColors.primary.withAlpha(55),
      backgroundColor: IzyTelColors.surfaceMuted,
      side: BorderSide(
        color: selected ? IzyTelColors.primary : IzyTelColors.outline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: IzyTelColors.background,
        title: const SizedBox.shrink(),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (_, _) {
            final List<AgentDirectoryEntry> agents = _viewModel.filteredAgents;
            final int activeFilters = <Object?>[
              _viewModel.availabilityFilter,
              _viewModel.networkFilter,
              _viewModel.zoneFilter,
              _viewModel.activeFilter,
            ].where((Object? value) => value != null).length;

            return RefreshIndicator(
              onRefresh: _viewModel.start,
              color: IzyTelColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  IzyTelPageHeader(
                    title: 'Agents & zones',
                    subtitle:
                        'Pilote la disponibilité, les réseaux et les capacités de l’équipe.',
                    actions: [IzyTelAvatar(name: widget.user.name, size: 42)],
                  ),
                  const SizedBox(height: IzyTelSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          value: '${_viewModel.agents.length}',
                          label: 'Agents',
                          color: IzyTelColors.primary,
                          softColor: IzyTelColors.primarySoft,
                          icon: Symbols.groups_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          value: '${_viewModel.availableCount}',
                          label: 'Disponibles',
                          color: IzyTelColors.success,
                          softColor: IzyTelColors.successSoft,
                          icon: Symbols.check_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _MetricCard(
                          value: '${_viewModel.suspendedCount}',
                          label: 'Suspendus',
                          color: IzyTelColors.error,
                          softColor: IzyTelColors.errorSoft,
                          icon: Symbols.block_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: IzyTelSpacing.md),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _addAgent,
                      icon: const Icon(Symbols.person_add_rounded, size: 20),
                      label: const Text('Ajouter un agent'),
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.md),
                  IzyTelSearchField(
                    controller: _searchController,
                    hintText: 'Nom, code agent, téléphone…',
                    onChanged: _viewModel.updateSearch,
                  ),
                  const SizedBox(height: IzyTelSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        IzyTelFilterPill(
                          label: 'Tous',
                          selected: _viewModel.availabilityFilter == null,
                          onTap: () => _viewModel.setAvailability(null),
                        ),
                        const SizedBox(width: 8),
                        IzyTelFilterPill(
                          label: 'Disponibles',
                          selected:
                              _viewModel.availabilityFilter ==
                              AgentAvailability.available,
                          selectedColor: IzyTelColors.success,
                          softColor: IzyTelColors.successSoft,
                          onTap: () => _viewModel.setAvailability(
                            _viewModel.availabilityFilter ==
                                    AgentAvailability.available
                                ? null
                                : AgentAvailability.available,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IzyTelFilterPill(
                          label: 'Indisponibles',
                          selected:
                              _viewModel.availabilityFilter ==
                              AgentAvailability.unavailable,
                          selectedColor: IzyTelColors.warning,
                          softColor: IzyTelColors.warningSoft,
                          onTap: () => _viewModel.setAvailability(
                            _viewModel.availabilityFilter ==
                                    AgentAvailability.unavailable
                                ? null
                                : AgentAvailability.unavailable,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IzyTelFilterPill(
                          label: activeFilters > 0
                              ? 'Filtres ($activeFilters)'
                              : 'Filtres',
                          icon: Symbols.tune_rounded,
                          selected: activeFilters > 0,
                          onTap: _showFilters,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IzyTelSpacing.lg),
                  IzyTelSectionHeader(
                    title: 'Équipe',
                    actionLabel: activeFilters > 0 ? 'Réinitialiser' : null,
                    onAction: activeFilters > 0
                        ? _viewModel.clearFilters
                        : null,
                  ),
                  const SizedBox(height: 8),
                  if (_viewModel.isLoading && _viewModel.agents.isEmpty)
                    const SizedBox(
                      height: 280,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.errorMessage != null &&
                      _viewModel.agents.isEmpty)
                    _MessageCard(
                      icon: Symbols.cloud_off_rounded,
                      title: 'Agents indisponibles',
                      message: _viewModel.errorMessage!,
                    )
                  else if (agents.isEmpty)
                    const _MessageCard(
                      icon: Symbols.groups_rounded,
                      title: 'Aucun agent',
                      message: 'Aucun agent ne correspond aux filtres actuels.',
                    )
                  else
                    ...agents.map(
                      (AgentDirectoryEntry agent) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AgentCard(
                          agent: agent,
                          zones: _viewModel.zones,
                          onTap: () => _openAgent(agent),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _agentZoneLabel(AgentProfile? profile, List<AgentZone> zones) {
  if (profile == null || profile.zoneIds.isEmpty) {
    return 'Aucune zone';
  }

  final Map<String, AgentZone> zonesById = <String, AgentZone>{
    for (final AgentZone zone in zones) zone.id: zone,
  };
  final List<String> labels = profile.zoneIds
      .map((String id) => zonesById[id]?.displayLabel ?? id)
      .where((String label) => label.trim().isNotEmpty)
      .toList(growable: false);

  return labels.isEmpty ? 'Aucune zone' : labels.join(' · ');
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
    final String zoneLabel = _agentZoneLabel(profile, zones);
    final bool available =
        agent.isActive && agent.availability == AgentAvailability.available;
    final int totalCapacity = profile == null
        ? 0
        : profile.orangeCapacity + profile.mtnCapacity + profile.moovCapacity;

    return IzyTelSurface(
      onTap: onTap,
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AgentDirectoryAvatar(
                key: ValueKey<String>(agent.userId),
                agentId: agent.userId,
                name: agent.name,
                size: 44,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.agentCode,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IzyTelColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusBadge(
                label: !agent.isActive
                    ? 'Suspendu'
                    : available
                    ? 'Disponible'
                    : 'Indisponible',
                color: !agent.isActive
                    ? IzyTelColors.error
                    : available
                    ? IzyTelColors.success
                    : IzyTelColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Symbols.location_on_rounded,
                size: 18,
                color: IzyTelColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  zoneLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.textSecondary,
                  ),
                ),
              ),
              if (totalCapacity > 0) ...[
                const SizedBox(width: 8),
                Text(
                  _formatCapacity(totalCapacity),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: IzyTelColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          if (profile != null && profile.authorizedNetworks.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: profile.authorizedNetworks
                  .map(
                    (AgentNetwork network) => _NetworkBadge(network: network),
                  )
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Symbols.schedule_rounded,
                size: 17,
                color: IzyTelColors.textMuted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  profile?.lastSeenAt == null
                      ? 'Aucune activité récente'
                      : 'Dernière activité · ${_relative(profile!.lastSeenAt!)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IzyTelColors.textMuted,
                  ),
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textMuted,
                size: 21,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge({required this.network});

  final AgentNetwork network;

  @override
  Widget build(BuildContext context) {
    final Color color = _networkColor(network);
    final Color background = switch (network) {
      AgentNetwork.orange => IzyTelColors.orangeSoft,
      AgentNetwork.mtn => IzyTelColors.mtnSoft,
      AgentNetwork.moov => IzyTelColors.moovSoft,
    };
    final String asset = switch (network) {
      AgentNetwork.orange => 'assets/brands/operators/orange_ci.png',
      AgentNetwork.mtn => 'assets/brands/operators/mtn_ci.png',
      AgentNetwork.moov => 'assets/brands/operators/moov_africa_ci.png',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 16,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
          const SizedBox(width: 5),
          Text(
            network.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCapacity(int amount) {
  final String value = amount.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) out.write(' ');
    out.write(value[i]);
  }
  return '${out.toString()} F';
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
    required this.softColor,
    required this.icon,
  });

  final String value;
  final String label;
  final Color color;
  final Color softColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: softColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: IzyTelColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return IzyTelSurface(
      child: IzyTelEmptyState(icon: icon, title: title, message: message),
    );
  }
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
      return IzyTelColors.orange;
    case AgentNetwork.mtn:
      return IzyTelColors.mtnText;
    case AgentNetwork.moov:
      return IzyTelColors.moov;
  }
}
