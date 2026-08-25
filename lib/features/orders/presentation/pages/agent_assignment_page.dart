import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_assignment_view_model.dart';
import 'package:flutter/material.dart';

class AgentAssignmentPage extends StatefulWidget {
  const AgentAssignmentPage({
    super.key,
    required this.user,
    required this.order,
    required this.agentRepository,
    required this.ordersRepository,
  });

  final AppUser user;
  final QueueOrder order;
  final AgentRepository agentRepository;
  final OrdersRepository ordersRepository;

  @override
  State<AgentAssignmentPage> createState() => _AgentAssignmentPageState();
}

class _AgentAssignmentPageState extends State<AgentAssignmentPage> {
  late final AgentAssignmentViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AgentAssignmentViewModel(
      order: widget.order,
      adminUserId: widget.user.id,
      agentRepository: widget.agentRepository,
      ordersRepository: widget.ordersRepository,
    );
    _viewModel.start();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _assign(AgentAssignmentCandidate candidate) async {
    final AgentDirectoryEntry agent = candidate.agent;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmer l’affectation'),
          content: Text(
            'Affecter la commande ${widget.order.reference} à ${agent.name} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Affecter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final bool success = await _viewModel.assign(candidate);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              _viewModel.errorMessage ?? 'Impossible d’affecter la commande.',
            ),
          ),
        );
      return;
    }

    Navigator.of(context).pop(_viewModel.order);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLow,
        foregroundColor: AppColors.onBackground,
        elevation: 0,
        titleSpacing: 4,
        title: const Text(
          'Affecter une commande',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _viewModel,
          builder: (BuildContext context, Widget? child) {
            return RefreshIndicator(
              onRefresh: _viewModel.start,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  const Text(
                    'Affecter Commande',
                    style: TextStyle(
                      color: AppColors.onBackground,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sélectionne un agent disponible et capable de traiter cette opération.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 22),
                  _OrderSummary(order: _viewModel.order),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Agents compatibles',
                          style: TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Text(
                          '${_viewModel.assignableCount} disponibles',
                          style: const TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_viewModel.errorMessage != null) ...[
                    _MessageCard(
                      message: _viewModel.errorMessage!,
                      isError: true,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_viewModel.isLoading && _viewModel.candidates.isEmpty)
                    const SizedBox(
                      height: 220,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_viewModel.candidates.isEmpty)
                    const _MessageCard(
                      message:
                          'Aucun agent n’est encore autorisé pour ce réseau. Vérifie les profils agents dans Administration.',
                    )
                  else
                    ..._viewModel.candidates.map(
                      (AgentAssignmentCandidate candidate) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AgentCandidateCard(
                          order: _viewModel.order,
                          candidate: candidate,
                          isSubmitting:
                              _viewModel.assigningAgentId ==
                              candidate.agent.userId,
                          onAssign: () => _assign(candidate),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primaryContainer,
                          size: 19,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'La compatibilité est calculée avec la disponibilité, le réseau actif et la capacité déclarée. La commande ne contient pas encore de zone client, donc la zone n’est pas utilisée pour bloquer une affectation à ce stade.',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Résumé de la commande',
          style: TextStyle(
            color: AppColors.onBackground,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _SummaryTile(
          icon: Icons.tag_rounded,
          label: 'RÉFÉRENCE',
          value: order.reference,
        ),
        const SizedBox(height: 10),
        _SummaryTile(
          icon: Icons.cell_tower_rounded,
          label: 'RÉSEAU',
          value: _networkLabel(order.network),
          accent: _networkColor(order.network),
        ),
        const SizedBox(height: 10),
        _SummaryTile(
          icon: Icons.payments_outlined,
          label: 'MONTANT',
          value: formatCfa(order.amount),
        ),
        const SizedBox(height: 10),
        const _SummaryTile(
          icon: Icons.location_on_outlined,
          label: 'ZONE',
          value: 'Non renseignée pour cette commande',
        ),
        if (order.isAssignedToAgent) ...[
          const SizedBox(height: 10),
          _SummaryTile(
            icon: Icons.person_pin_circle_outlined,
            label: 'AFFECTATION ACTUELLE',
            value: order.assignedAgentName ?? 'Agent affecté',
            accent: AppColors.warning,
          ),
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.primaryContainer,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCandidateCard extends StatelessWidget {
  const _AgentCandidateCard({
    required this.order,
    required this.candidate,
    required this.isSubmitting,
    required this.onAssign,
  });

  final QueueOrder order;
  final AgentAssignmentCandidate candidate;
  final bool isSubmitting;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final AgentDirectoryEntry agent = candidate.agent;
    final AgentProfile profile = agent.profile!;
    final String zoneLabel = candidate.zones.isEmpty
        ? 'Aucune zone assignée'
        : candidate.zones
              .map((AgentZone zone) => zone.displayLabel)
              .join(' • ');
    final int requiredPercent = candidate.capacity <= 0
        ? 100
        : (((order.amount / candidate.capacity) * 100).ceil() > 100
              ? 100
              : ((order.amount / candidate.capacity) * 100).ceil());
    final Color accent = _networkColor(order.network);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: candidate.isCurrentAssignment
              ? AppColors.warning
              : AppColors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceContainerHighest,
                child: Text(
                  _initials(agent.name),
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.w900,
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
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${profile.agentCode} • $zoneLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _AvailabilityBadge(candidate: candidate),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: AppColors.outlineVariant.withAlpha(120)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'RÉSEAU GÉRÉ',
                  value: _networkLabel(order.network),
                  valueColor: accent,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'CHARGE ACTUELLE',
                  value:
                      '${candidate.activeAssignments} commande${candidate.activeAssignments > 1 ? 's' : ''}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CAPACITÉ DISPONIBLE',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                formatCfa(candidate.capacity),
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: requiredPercent / 100,
              backgroundColor: AppColors.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                candidate.capacity >= order.amount ? accent : AppColors.error,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Cette commande utilise environ $requiredPercent % de la capacité déclarée.',
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: candidate.isAssignable && !isSubmitting
                  ? onAssign
                  : null,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.assignment_ind_outlined),
              label: Text(
                isSubmitting
                    ? 'Affectation...'
                    : candidate.isAssignable
                    ? 'Affecter'
                    : candidate.unavailableReason ?? 'Indisponible',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.valueColor = AppColors.onBackground,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.candidate});

  final AgentAssignmentCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final bool available = candidate.isAssignable;
    final Color color = available
        ? AppColors.success
        : AppColors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        available
            ? 'Disponible'
            : candidate.unavailableReason ?? 'Indisponible',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final Color color = isError ? AppColors.error : AppColors.primaryContainer;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

String _networkLabel(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'Orange';
    case MobileNetwork.mtn:
      return 'MTN';
    case MobileNetwork.moov:
      return 'Moov';
  }
}

Color _networkColor(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return AppColors.orange;
    case MobileNetwork.mtn:
      return AppColors.mtn;
    case MobileNetwork.moov:
      return AppColors.primaryContainer;
  }
}

String _initials(String name) {
  final List<String> words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
      .toUpperCase();
}
