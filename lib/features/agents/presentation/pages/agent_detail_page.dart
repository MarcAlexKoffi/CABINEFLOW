import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/view_models/agent_detail_view_model.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AgentDetailPage extends StatefulWidget {
  const AgentDetailPage({
    super.key,
    required this.agent,
    required this.zones,
    required this.repository,
  });

  final AgentDirectoryEntry agent;
  final List<AgentZone> zones;
  final AgentRepository repository;

  @override
  State<AgentDetailPage> createState() => _AgentDetailPageState();
}

class _AgentDetailPageState extends State<AgentDetailPage> {
  late final AgentDetailViewModel _viewModel;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dailyLimitController;
  late final TextEditingController _maxTransactionsController;
  late final Map<AgentNetwork, TextEditingController> _capacityControllers;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentDetailViewModel(
      agent: widget.agent,
      repository: widget.repository,
      zones: widget.zones,
    );
    _nameController = TextEditingController(text: _viewModel.name);
    _phoneController = TextEditingController(text: _viewModel.phoneNumber);
    _dailyLimitController = TextEditingController(
      text: '${_viewModel.dailyTransactionLimit}',
    );
    _maxTransactionsController = TextEditingController(
      text: '${_viewModel.maxTransactionsPerDay}',
    );
    _capacityControllers = <AgentNetwork, TextEditingController>{
      AgentNetwork.orange: TextEditingController(
        text: '${_viewModel.orangeCapacity}',
      ),
      AgentNetwork.mtn: TextEditingController(
        text: '${_viewModel.mtnCapacity}',
      ),
      AgentNetwork.moov: TextEditingController(
        text: '${_viewModel.moovCapacity}',
      ),
    };
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _dailyLimitController.dispose();
    _maxTransactionsController.dispose();
    for (final controller in _capacityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    _viewModel.setName(_nameController.text);
    _viewModel.setPhone(_phoneController.text);
    _viewModel.setLimits(
      amount: int.tryParse(_dailyLimitController.text.trim()) ?? -1,
      count: int.tryParse(_maxTransactionsController.text.trim()) ?? -1,
    );
    for (final network in AgentNetwork.values) {
      _viewModel.setCapacity(
        network,
        int.tryParse(_capacityControllers[network]!.text.trim()) ?? 0,
      );
    }
    final bool success = await _viewModel.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Profil agent enregistré.'
                : _viewModel.errorMessage ?? 'Enregistrement impossible.',
          ),
        ),
      );
    if (success) Navigator.of(context).pop();
  }

  Future<void> _createZone() async {
    final TextEditingController name = TextEditingController();
    final TextEditingController city = TextEditingController(text: 'Abidjan');
    final TextEditingController region = TextEditingController(text: 'Abidjan');
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: IzyTelColors.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Créer une zone',
          style: TextStyle(color: IzyTelColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: IzyTelColors.primary,
                decoration: _darkInputDecoration('Nom de la zone'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: city,
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: IzyTelColors.primary,
                decoration: _darkInputDecoration('Ville'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: region,
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: IzyTelColors.primary,
                decoration: _darkInputDecoration('Région'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (name.text.trim().length < 2 ||
        city.text.trim().length < 2 ||
        region.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complète correctement les informations de la zone.'),
        ),
      );
      return;
    }
    final String? id = await _viewModel.createZone(
      name: name.text,
      city: city.text,
      region: region.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id == null
              ? _viewModel.errorMessage ?? 'Création impossible.'
              : 'Zone créée. Rouvre la fiche pour l’assigner après synchronisation.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AgentProfile? profile = widget.agent.profile;
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(title: const Text('Profil Agent')),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (_, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _ProfileHeader(
                  agent: widget.agent,
                  isActive: _viewModel.isActive,
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Identité',
                  icon: Symbols.person_rounded,
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: IzyTelColors.primary,
                        decoration: _darkInputDecoration('Nom complet'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: IzyTelColors.primary,
                        decoration: _darkInputDecoration('Téléphone'),
                      ),
                      const SizedBox(height: 10),
                      _ReadOnlyLine(
                        label: 'E-mail',
                        value: widget.agent.email.isEmpty
                            ? 'Non renseigné'
                            : widget.agent.email,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Zones assignées',
                  icon: Symbols.location_on_rounded,
                  trailing: TextButton.icon(
                    onPressed: _createZone,
                    icon: const Icon(Symbols.add_rounded, size: 18),
                    label: const Text('Créer'),
                  ),
                  child: widget.zones.isEmpty
                      ? const Text(
                          'Aucune zone n’existe encore. Crée la première zone puis assigne-la à l’agent.',
                          style: TextStyle(color: IzyTelColors.textSecondary),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.zones
                              .where((zone) => zone.isActive)
                              .map((zone) {
                                final bool selected = _viewModel.zoneIds
                                    .contains(zone.id);
                                return FilterChip(
                                  label: Text(zone.displayLabel),
                                  selected: selected,
                                  onSelected: (_) =>
                                      _viewModel.toggleZone(zone.id),
                                  selectedColor: IzyTelColors.primary.withAlpha(
                                    55,
                                  ),
                                  side: BorderSide(
                                    color: selected
                                        ? IzyTelColors.primary
                                        : IzyTelColors.outline,
                                  ),
                                );
                              })
                              .toList(growable: false),
                        ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Capacités & limites',
                  icon: Symbols.tune_rounded,
                  child: Column(
                    children: [
                      TextField(
                        controller: _dailyLimitController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: IzyTelColors.primary,
                        decoration: _darkInputDecoration(
                          'Limite transactions / jour (FCFA)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _maxTransactionsController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        cursorColor: IzyTelColors.primary,
                        decoration: _darkInputDecoration(
                          'Nombre max de transactions / jour',
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...AgentNetwork.values.map(
                        (network) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextField(
                            controller: _capacityControllers[network],
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              color: IzyTelColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: IzyTelColors.primary,
                            decoration: _darkInputDecoration(
                              'Capacité ${network.label} (FCFA)',
                              prefixIcon: Icon(
                                Symbols.account_balance_wallet_rounded,
                                color: _networkColor(network),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Réseaux autorisés',
                  icon: Symbols.hub_rounded,
                  child: Column(
                    children: AgentNetwork.values
                        .map((network) {
                          final bool enabled = _viewModel.authorizedNetworks
                              .contains(network);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: IzyTelColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: IzyTelColors.outline),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _networkColor(network),
                                    borderRadius: BorderRadius.circular(999),
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
                                          color: IzyTelColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        enabled ? 'Autorisé' : 'Non autorisé',
                                        style: const TextStyle(
                                          color: IzyTelColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: enabled,
                                  onChanged: (_) =>
                                      _viewModel.toggleNetwork(network),
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
                  title: 'Activité récente',
                  icon: Symbols.history_rounded,
                  child: Column(
                    children: [
                      _ActivityLine(
                        color: IzyTelColors.primary,
                        title: 'Dernière activité',
                        value: profile?.lastSeenAt == null
                            ? 'Aucune donnée'
                            : _formatDate(profile!.lastSeenAt!),
                      ),
                      const SizedBox(height: 10),
                      _ActivityLine(
                        color: IzyTelColors.success,
                        title: 'Dernière déclaration de capacité',
                        value: profile?.lastCapacityUpdateAt == null
                            ? 'Aucune donnée'
                            : _formatDate(profile!.lastCapacityUpdateAt!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _viewModel.isSaving ? null : _save,
                  icon: _viewModel.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.save_rounded),
                  label: const Text('Enregistrer les modifications'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _viewModel.setActive(!_viewModel.isActive),
                  icon: Icon(
                    _viewModel.isActive
                        ? Symbols.block_rounded
                        : Symbols.check_circle_rounded,
                  ),
                  label: Text(
                    _viewModel.isActive
                        ? 'Suspendre l’agent'
                        : 'Réactiver l’agent',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _viewModel.isActive
                        ? IzyTelColors.error
                        : IzyTelColors.success,
                  ),
                ),
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: IzyTelColors.error),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.agent, required this.isActive});
  final AgentDirectoryEntry agent;
  final bool isActive;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: IzyTelColors.outline),
    ),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: IzyTelColors.primary.withAlpha(35),
              child: Text(
                _initials(agent.name),
                style: const TextStyle(
                  color: IzyTelColors.primary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              right: 1,
              bottom: 2,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: isActive ? IzyTelColors.success : IzyTelColors.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: IzyTelColors.surface, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          agent.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: IzyTelColors.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          agent.agentCode,
          style: const TextStyle(color: IzyTelColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (isActive ? IzyTelColors.success : IzyTelColors.error)
                .withAlpha(28),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isActive ? 'Actif' : 'Suspendu',
            style: TextStyle(
              color: isActive ? IzyTelColors.success : IzyTelColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: IzyTelColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: IzyTelColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _ReadOnlyLine extends StatelessWidget {
  const _ReadOnlyLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: IzyTelColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: IzyTelColors.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: IzyTelColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: IzyTelColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({
    required this.color,
    required this.title,
    required this.value,
  });
  final Color color;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

InputDecoration _darkInputDecoration(
  String label, {
  Widget? prefixIcon,
  String? hintText,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: IzyTelColors.surfaceMuted,
    labelStyle: const TextStyle(
      color: IzyTelColors.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    floatingLabelStyle: const TextStyle(
      color: IzyTelColors.primary,
      fontWeight: FontWeight.w700,
    ),
    hintStyle: const TextStyle(color: IzyTelColors.textSecondary),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: IzyTelColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: IzyTelColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: IzyTelColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: IzyTelColors.error, width: 1.5),
    ),
  );
}

String _initials(String value) {
  final List<String> parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} à ${two(value.hour)}:${two(value.minute)}';
}

Color _networkColor(AgentNetwork network) {
  switch (network) {
    case AgentNetwork.orange:
      return IzyTelColors.orange;
    case AgentNetwork.mtn:
      return IzyTelColors.mtnText;
    case AgentNetwork.moov:
      return IzyTelColors.primary;
  }
}
