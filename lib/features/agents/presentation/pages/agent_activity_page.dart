import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_activity_view_model.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:flutter/material.dart';

class AgentActivityPage extends StatefulWidget {
  const AgentActivityPage({
    super.key,
    required this.user,
    required this.repository,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AppUser user;
  final AgentRepository repository;
  final bool isLoggingOut;
  final Future<void> Function() onLogout;

  @override
  State<AgentActivityPage> createState() => _AgentActivityPageState();
}

class _AgentActivityPageState extends State<AgentActivityPage> {
  late final AgentActivityViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentActivityViewModel(
      agentId: widget.user.id,
      repository: widget.repository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _editCapacity(AgentNetwork network) async {
    final AgentProfile? profile = _viewModel.profile;
    if (profile == null) return;

    final int? value = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CapacityEditorSheet(
        network: network,
        initialAmount: profile.capacityFor(network),
      ),
    );

    if (value == null || !mounted) return;
    if (!mounted) return;

    final bool success = await _viewModel.updateCapacity(network, value);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Capacité ${network.label} mise à jour.'
          : _viewModel.errorMessage ?? 'Modification impossible.',
    );
  }

  Future<void> _reportIssue() async {
    final AgentIssueDraft? result = await showModalBottomSheet<AgentIssueDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AgentIssueSheet(),
    );

    if (result == null || !mounted) return;
    if (!mounted) return;

    final bool success = await _viewModel.reportIssue(result);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Signalement transmis à l’administration.'
          : _viewModel.errorMessage ?? 'Envoi impossible.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (_, _) {
            if (_viewModel.isLoading && _viewModel.profile == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final AgentProfile? profile = _viewModel.profile;
            if (profile == null) {
              return _MissingProfile(
                user: widget.user,
                message: _viewModel.errorMessage,
                isLoggingOut: widget.isLoggingOut,
                onLogout: widget.onLogout,
              );
            }

            return RefreshIndicator(
              onRefresh: _viewModel.start,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _AgentHeader(user: widget.user, profile: profile),
                  const SizedBox(height: 22),
                  const Text(
                    'Mon Activité',
                    style: TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Aperçu en temps réel de ta disponibilité et de tes capacités réseau.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  _StatusCard(
                    profile: profile,
                    isSaving: _viewModel.isSaving,
                    onChanged: (enabled) async {
                      final bool success = await _viewModel.setAvailability(
                        enabled
                            ? AgentAvailability.available
                            : AgentAvailability.unavailable,
                      );
                      if (!mounted || success) return;
                      _showMessage(
                        _viewModel.errorMessage ?? 'Modification impossible.',
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'CAPACITÉ DISPONIBLE',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ...AgentNetwork.values.map(
                    (AgentNetwork network) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CapacityCard(
                        network: network,
                        amount: profile.capacityFor(network),
                        authorized: profile.authorizedNetworks.contains(
                          network,
                        ),
                        active: profile.activeNetworks.contains(network),
                        onEdit: profile.authorizedNetworks.contains(network)
                            ? () => _editCapacity(network)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _IssueBanner(onTap: _reportIssue),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Réseaux traitables',
                    icon: Icons.hub_outlined,
                    child: profile.authorizedNetworks.isEmpty
                        ? const Text(
                            'Aucun réseau ne t’a encore été autorisé par l’administration.',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          )
                        : Column(
                            children: profile.authorizedNetworks
                                .map((network) {
                                  final bool enabled = profile.activeNetworks
                                      .contains(network);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 5,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: _networkColor(network),
                                            borderRadius: BorderRadius.circular(
                                              99,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                network.label,
                                                style: const TextStyle(
                                                  color: AppColors.onBackground,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                enabled
                                                    ? 'Prêt à recevoir des commandes'
                                                    : 'Désactivé temporairement',
                                                style: const TextStyle(
                                                  color: AppColors
                                                      .onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: enabled,
                                          onChanged: _viewModel.isSaving
                                              ? null
                                              : (value) async {
                                                  final bool success =
                                                      await _viewModel
                                                          .toggleNetwork(
                                                            network,
                                                            value,
                                                          );
                                                  if (!mounted || success) {
                                                    return;
                                                  }
                                                  _showMessage(
                                                    _viewModel.errorMessage ??
                                                        'Modification impossible.',
                                                  );
                                                },
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Zones assignées',
                    icon: Icons.location_on_outlined,
                    child: _viewModel.assignedZones.isEmpty
                        ? const Text(
                            'Aucune zone assignée.',
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _viewModel.assignedZones
                                .map(
                                  (zone) =>
                                      Chip(label: Text(zone.displayLabel)),
                                )
                                .toList(growable: false),
                          ),
                  ),
                  if (_viewModel.issues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Mes signalements',
                      icon: Icons.report_problem_outlined,
                      child: Column(
                        children: _viewModel.issues
                            .take(3)
                            .map((issue) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      issue.status == 'resolved'
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.warning_amber_rounded,
                                      color: issue.status == 'resolved'
                                          ? AppColors.success
                                          : AppColors.warning,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            issue.description,
                                            style: const TextStyle(
                                              color: AppColors.onBackground,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            _issueStatus(issue.status),
                                            style: const TextStyle(
                                              color: AppColors.onSurfaceVariant,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _LogoutCard(
                    isLoggingOut: widget.isLoggingOut,
                    onLogout: widget.onLogout,
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

class _CapacityEditorSheet extends StatefulWidget {
  const _CapacityEditorSheet({
    required this.network,
    required this.initialAmount,
  });

  final AgentNetwork network;
  final int initialAmount;

  @override
  State<_CapacityEditorSheet> createState() => _CapacityEditorSheetState();
}

class _CapacityEditorSheetState extends State<_CapacityEditorSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.initialAmount}');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 0) {
      setState(() => _errorText = 'Saisis un montant valide.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return _BottomSheetContainer(
      bottomInset: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Capacité ${widget.network.label}',
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Indique le montant actuellement disponible sur ce réseau.',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            cursorColor: AppColors.primary,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w600,
            ),
            decoration: _agentSheetInputDecoration(
              labelText: 'Montant disponible (FCFA)',
              hintText: 'Ex. 35000',
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentIssueSheet extends StatefulWidget {
  const _AgentIssueSheet();

  @override
  State<_AgentIssueSheet> createState() => _AgentIssueSheetState();
}

class _AgentIssueSheetState extends State<_AgentIssueSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  String _type = 'network';
  AgentNetwork? _network;
  String? _errorText;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final String description = _descriptionController.text.trim();
    if (description.length < 3) {
      setState(() => _errorText = 'Décris le problème en quelques mots.');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(
      AgentIssueDraft(type: _type, network: _network, description: description),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return _BottomSheetContainer(
      bottomInset: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Signaler un problème',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Choisis le type de problème puis décris brièvement la situation.',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const _SheetFieldLabel('Type de problème'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SheetChoiceChip(
                label: 'Problème réseau',
                selected: _type == 'network',
                onTap: () => setState(() => _type = 'network'),
              ),
              _SheetChoiceChip(
                label: 'Solde insuffisant',
                selected: _type == 'balance',
                onTap: () => setState(() => _type = 'balance'),
              ),
              _SheetChoiceChip(
                label: 'Problème technique',
                selected: _type == 'technical',
                onTap: () => setState(() => _type = 'technical'),
              ),
              _SheetChoiceChip(
                label: 'Autre',
                selected: _type == 'other',
                onTap: () => setState(() => _type = 'other'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SheetFieldLabel('Réseau concerné'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SheetChoiceChip(
                label: 'Tous / non concerné',
                selected: _network == null,
                onTap: () => setState(() => _network = null),
              ),
              ...AgentNetwork.values.map(
                (AgentNetwork item) => _SheetChoiceChip(
                  label: item.label,
                  selected: _network == item,
                  accentColor: _networkColor(item),
                  onTap: () => setState(() => _network = item),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SheetFieldLabel('Description'),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _submit(),
            cursorColor: AppColors.primary,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontWeight: FontWeight.w500,
            ),
            decoration: _agentSheetInputDecoration(
              hintText: 'Explique brièvement le problème rencontré…',
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Envoyer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomSheetContainer extends StatelessWidget {
  const _BottomSheetContainer({required this.child, required this.bottomInset});

  final Widget child;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SheetFieldLabel extends StatelessWidget {
  const _SheetFieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SheetChoiceChip extends StatelessWidget {
  const _SheetChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final Color color = accentColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(32) : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.onBackground
                : AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader({required this.user, required this.profile});

  final AppUser user;
  final AgentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withAlpha(35),
          child: Text(
            _initial(user.name),
            style: const TextStyle(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${profile.agentCode} • Espace Agent',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Icon(
          profile.availability == AgentAvailability.available
              ? Icons.radio_button_checked_rounded
              : Icons.pause_circle_outline_rounded,
          color: profile.availability == AgentAvailability.available
              ? AppColors.success
              : AppColors.warning,
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.profile,
    required this.isSaving,
    required this.onChanged,
  });

  final AgentProfile profile;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool available = profile.availability == AgentAvailability.available;
    return _SectionCard(
      title: 'Statut Agent',
      icon: Icons.cell_tower_rounded,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    available ? 'Disponible' : 'Indisponible',
                    style: TextStyle(
                      color: available ? AppColors.success : AppColors.warning,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    available
                        ? 'Tu peux recevoir de nouvelles commandes.'
                        : 'Aucune nouvelle commande ne doit t’être attribuée.',
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: available, onChanged: isSaving ? null : onChanged),
          ],
        ),
      ),
    );
  }
}

class _CapacityCard extends StatelessWidget {
  const _CapacityCard({
    required this.network,
    required this.amount,
    required this.authorized,
    required this.active,
    required this.onEdit,
  });

  final AgentNetwork network;
  final int amount;
  final bool authorized;
  final bool active;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final Color color = _networkColor(network);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  network.label,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  authorized ? _money(amount) : 'Non autorisé',
                  style: TextStyle(
                    color: authorized ? color : AppColors.onSurfaceVariant,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  !authorized
                      ? 'Accès désactivé par l’administration'
                      : active
                      ? 'Réseau actif'
                      : 'Réseau temporairement désactivé',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Mettre à jour la capacité',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.primaryContainer,
            ),
        ],
      ),
    );
  }
}

class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Un problème technique ?',
                  style: TextStyle(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Signale une anomalie réseau ou de solde à l’administration.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.warning_amber_rounded, size: 18),
            label: const Text('Signaler'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryContainer, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.isLoggingOut, required this.onLogout});

  final bool isLoggingOut;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.error.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
              SizedBox(width: 8),
              Text(
                'Session',
                style: TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ferme ta session sur cet appareil lorsque tu as terminé.',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 13),
          OutlinedButton.icon(
            onPressed: isLoggingOut ? null : () => onLogout(),
            icon: isLoggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(isLoggingOut ? 'Déconnexion...' : 'Se déconnecter'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingProfile extends StatelessWidget {
  const _MissingProfile({
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
    this.message,
  });

  final AppUser user;
  final bool isLoggingOut;
  final Future<void> Function() onLogout;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.manage_accounts_outlined,
                size: 44,
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              Text(
                'Bonjour ${user.name}',
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message ??
                    'Ton compte possède le rôle Agent, mais ton profil opérationnel n’est pas encore configuré. Contacte l’administrateur.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isLoggingOut ? null : () => onLogout(),
                  icon: isLoggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(
                    isLoggingOut ? 'Déconnexion...' : 'Se déconnecter',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(int value) {
  final String digits = value.toString();
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }
  return '${buffer.toString()} F';
}

String _issueStatus(String status) {
  switch (status) {
    case 'acknowledged':
      return 'Pris en compte';
    case 'resolved':
      return 'Résolu';
    case 'cancelled':
      return 'Annulé';
    default:
      return 'Ouvert';
  }
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

InputDecoration _agentSheetInputDecoration({
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  const BorderRadius radius = BorderRadius.all(Radius.circular(12));

  return InputDecoration(
    filled: true,
    fillColor: AppColors.surfaceContainerHigh,
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
    floatingLabelStyle: const TextStyle(color: AppColors.primaryContainer),
    hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.outlineVariant),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.outlineVariant),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: AppColors.error, width: 1.5),
    ),
  );
}
