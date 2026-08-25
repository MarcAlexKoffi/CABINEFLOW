import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/agent_orders_view_model.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class AgentOrderDetailView extends StatefulWidget {
  const AgentOrderDetailView({
    super.key,
    required this.user,
    required this.order,
    required this.viewModel,
    required this.onBack,
  });

  final AppUser user;
  final QueueOrder order;
  final AgentOrdersViewModel viewModel;
  final VoidCallback onBack;

  @override
  State<AgentOrderDetailView> createState() => _AgentOrderDetailViewState();
}

class _AgentOrderDetailViewState extends State<AgentOrderDetailView> {
  final ImagePicker _picker = ImagePicker();
  OrderProof? _proof;
  bool _isLoadingProof = true;

  bool get _isBusy => widget.viewModel.busyOrderId == widget.order.id;

  @override
  void initState() {
    super.initState();
    _loadProof();
  }

  @override
  void didUpdateWidget(covariant AgentOrderDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _proof = null;
      _isLoadingProof = true;
      _loadProof();
    }
  }

  Future<void> _loadProof() async {
    final OrderProof? proof = await widget.viewModel.loadProof(widget.order.id);
    if (!mounted) return;
    setState(() {
      _proof = proof;
      _isLoadingProof = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _accept() async {
    final bool accepted = await widget.viewModel.accept(widget.order);
    if (!mounted) return;
    if (!accepted) {
      _showMessage(widget.viewModel.errorMessage ?? 'Acceptation impossible.');
      return;
    }

    final QueueOrder? acceptedOrder = widget.viewModel.orderById(
      widget.order.id,
    );
    bool started = false;
    if (acceptedOrder != null) {
      started = await widget.viewModel.startProcessing(acceptedOrder);
    }
    if (!mounted) return;
    _showMessage(
      started
          ? 'Commande acceptée. Le traitement a démarré.'
          : 'Commande acceptée. Tu peux démarrer le traitement depuis ce détail.',
    );
  }

  Future<void> _refuse() async {
    final String? reason = await _showTextReasonSheet(
      title: 'Refuser la commande',
      subtitle:
          '${widget.order.reference} sera renvoyée dans le circuit de réaffectation.',
      label: 'Motif du refus',
      hint: 'Ex. réseau indisponible ou capacité insuffisante…',
      confirmLabel: 'Confirmer le refus',
      confirmColor: AppColors.error,
      maxLength: 500,
    );
    if (reason == null || !mounted) return;

    final bool success = await widget.viewModel.refuse(widget.order, reason);
    if (!mounted) return;
    if (success) {
      _showMessage('Commande refusée et renvoyée pour réaffectation.');
      widget.onBack();
    } else {
      _showMessage(widget.viewModel.errorMessage ?? 'Refus impossible.');
    }
  }

  Future<void> _startProcessing() async {
    final bool success = await widget.viewModel.startProcessing(widget.order);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Traitement démarré.'
          : widget.viewModel.errorMessage ?? 'Démarrage impossible.',
    );
  }

  Future<void> _resumeProcessing() async {
    final bool success = await widget.viewModel.resumeProcessing(widget.order);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Traitement repris.'
          : widget.viewModel.errorMessage ?? 'Reprise impossible.',
    );
  }

  Future<void> _pickProof() async {
    if (_isBusy || widget.order.status != QueueOrderStatus.inProgress) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2200,
      maxHeight: 2200,
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (picked == null || !mounted) return;

    try {
      final Uint8List sourceBytes = await picked.readAsBytes();
      final Uint8List compressed = await compute(
        _compressProofForFirestore,
        sourceBytes,
      );
      if (!mounted) return;

      final String safeReference = widget.order.reference.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      final OrderProof? proof = await widget.viewModel.saveProof(
        order: widget.order,
        fileName: '${safeReference}_preuve.jpg',
        mimeType: 'image/jpeg',
        bytes: compressed,
      );
      if (!mounted) return;

      if (proof == null) {
        _showMessage(
          widget.viewModel.errorMessage ??
              'Impossible d’enregistrer la preuve.',
        );
        return;
      }

      setState(() {
        _proof = proof;
      });
      _showMessage('Preuve enregistrée.');
    } on FormatException catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Impossible de préparer cette image. Essaie une autre capture.',
      );
    }
  }

  Future<void> _confirmSuccess() async {
    if (_proof == null) {
      _showMessage('Ajoute d’abord une capture comme preuve du transfert.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerHighest,
          title: const Text('Confirmer la réussite'),
          content: Text(
            'La commande ${widget.order.reference} sera marquée comme réussie.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final bool success = await widget.viewModel.markSuccessful(widget.order);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Traitement réussi et enregistré.'
          : widget.viewModel.errorMessage ?? 'Validation impossible.',
    );
  }

  Future<void> _markFailed() async {
    final _FailureResult? result = await showModalBottomSheet<_FailureResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FailureSheet(),
    );
    if (result == null || !mounted) return;

    final bool success = await widget.viewModel.markFailed(
      widget.order,
      result.reason,
      result.observation,
    );
    if (!mounted) return;
    _showMessage(
      success
          ? 'Échec enregistré.'
          : widget.viewModel.errorMessage ??
                'Impossible d’enregistrer l’échec.',
    );
  }

  Future<void> _putOnHold() async {
    final String? reason = await _showHoldReasonSheet();
    if (reason == null || !mounted) return;

    final bool success = await widget.viewModel.putOnHold(widget.order, reason);
    if (!mounted) return;
    _showMessage(
      success
          ? 'Commande mise en attente.'
          : widget.viewModel.errorMessage ?? 'Mise en attente impossible.',
    );
  }

  Future<String?> _showHoldReasonSheet() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HoldReasonSheet(),
    );
  }

  Future<String?> _showTextReasonSheet({
    required String title,
    required String subtitle,
    required String label,
    required String hint,
    required String confirmLabel,
    required Color confirmColor,
    required int maxLength,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReasonSheet(
        title: title,
        subtitle: subtitle,
        label: label,
        hint: hint,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        maxLength: maxLength,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final QueueOrder order = widget.order;
    return Column(
      children: [
        _DetailTopBar(order: order, onBack: widget.onBack),
        Divider(height: 1, color: AppColors.outlineVariant.withAlpha(90)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                'Détail de la commande\n#${order.reference}',
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 28,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Créée le ${_formatDateTime(order.createdAt)}',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              _GeneralInformationCard(order: order),
              const SizedBox(height: 16),
              _TrackingCard(order: order),
              const SizedBox(height: 16),
              if (order.assignmentStatus == OrderAssignmentStatus.assigned)
                _DecisionCard(
                  isBusy: _isBusy,
                  onAccept: _accept,
                  onRefuse: _refuse,
                )
              else if (order.assignmentStatus ==
                      OrderAssignmentStatus.accepted &&
                  order.status == QueueOrderStatus.paidReady)
                _StartProcessingCard(isBusy: _isBusy, onStart: _startProcessing)
              else if (order.status == QueueOrderStatus.onHold)
                _HoldCard(
                  order: order,
                  isBusy: _isBusy,
                  onResume: _resumeProcessing,
                )
              else if (order.status == QueueOrderStatus.inProgress)
                _ProcessingActionsCard(
                  proof: _proof,
                  isLoadingProof: _isLoadingProof,
                  isBusy: _isBusy,
                  onPickProof: _pickProof,
                  onSuccess: _confirmSuccess,
                  onFailure: _markFailed,
                  onHold: _putOnHold,
                )
              else
                _TerminalResultCard(order: order),
              if (order.status != QueueOrderStatus.inProgress &&
                  _proof != null) ...[
                const SizedBox(height: 16),
                _ReadOnlyProofCard(proof: _proof!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({required this.order, required this.onBack});

  final QueueOrder order;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(10, 9, 18, 9),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              order.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StatusPill(order: order),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final Color color = _agentStatusColor(order);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        _agentStatusLabel(order),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GeneralInformationCard extends StatelessWidget {
  const _GeneralInformationCard({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final Color networkAccent = networkColor(order.network);
    return _SectionCard(
      title: 'Informations générales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelValue(label: 'BÉNÉFICIAIRE', value: order.beneficiaryPhone),
          const SizedBox(height: 18),
          _LabelValue(
            label: 'MONTANT',
            value: formatCfa(order.amount),
            valueColor: AppColors.primaryContainer,
            valueSize: 23,
          ),
          const SizedBox(height: 18),
          const Text('RÉSEAU', style: _smallLabelStyle),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: networkAccent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                networkLabel(order.network),
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _LabelValue(label: 'OFFRE', value: order.offerLabel),
          const SizedBox(height: 18),
          _LabelValue(label: 'CLIENT', value: order.clientName),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final List<_TrackStep> steps = <_TrackStep>[
      _TrackStep(
        title: 'Commande reçue',
        subtitle: _formatDateTime(order.createdAt),
        state: _StepState.done,
      ),
      _TrackStep(
        title: 'Affectée à ${order.assignedAgentName ?? 'l’agent'}',
        subtitle: order.assignedAt == null
            ? 'Affectation enregistrée'
            : _formatDateTime(order.assignedAt!),
        state: order.assignedAt == null ? _StepState.upcoming : _StepState.done,
      ),
      _TrackStep(
        title: _processingStepTitle(order),
        subtitle: _processingStepSubtitle(order),
        state: _processingStepState(order),
      ),
    ];

    return _SectionCard(
      title: 'Suivi du traitement',
      child: Column(
        children: List<Widget>.generate(steps.length, (int index) {
          return _TimelineStep(
            step: steps[index],
            isLast: index == steps.length - 1,
          );
        }),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.isBusy,
    required this.onAccept,
    required this.onRefuse,
  });

  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Action requise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Accepte la commande si tu peux la traiter maintenant. Sinon, refuse-la avec un motif pour qu’elle soit réaffectée.',
            style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy ? null : onAccept,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Accepter et commencer'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onRefuse,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Refuser'),
          ),
        ],
      ),
    );
  }
}

class _StartProcessingCard extends StatelessWidget {
  const _StartProcessingCard({required this.isBusy, required this.onStart});

  final bool isBusy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Commande acceptée',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cette commande a été acceptée avant l’activation du traitement 9C. Démarre-la pour continuer.',
            style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy ? null : onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Démarrer le traitement'),
          ),
        ],
      ),
    );
  }
}

class _ProcessingActionsCard extends StatelessWidget {
  const _ProcessingActionsCard({
    required this.proof,
    required this.isLoadingProof,
    required this.isBusy,
    required this.onPickProof,
    required this.onSuccess,
    required this.onFailure,
    required this.onHold,
  });

  final OrderProof? proof;
  final bool isLoadingProof;
  final bool isBusy;
  final VoidCallback onPickProof;
  final VoidCallback onSuccess;
  final VoidCallback onFailure;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Traitement',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primaryContainer,
              ),
              SizedBox(width: 8),
              Text(
                'APRÈS LE TRANSFERT',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Preuve de transfert',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          _ProofPicker(
            proof: proof,
            isLoading: isLoadingProof,
            enabled: !isBusy,
            onTap: onPickProof,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isBusy ? null : onSuccess,
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Marquer comme réussi'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onFailure,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Signaler échec'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onHold,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('En attente'),
                ),
              ),
            ],
          ),
          if (isBusy) ...[
            const SizedBox(height: 14),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _ProofPicker extends StatelessWidget {
  const _ProofPicker({
    required this.proof,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  });

  final OrderProof? proof;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 150,
        decoration: _proofDecoration(),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: proof == null ? 150 : 205,
          clipBehavior: Clip.antiAlias,
          decoration: _proofDecoration(),
          child: proof == null
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.onSurfaceVariant,
                      size: 34,
                    ),
                    SizedBox(height: 9),
                    Text(
                      'Ajouter une capture',
                      style: TextStyle(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'L’image sera compressée automatiquement',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(proof!.bytes, fit: BoxFit.cover),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background.withAlpha(220),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 18,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Preuve enregistrée — toucher pour remplacer',
                                style: TextStyle(
                                  color: AppColors.onBackground,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  BoxDecoration _proofDecoration() {
    return BoxDecoration(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppColors.outlineVariant, width: 1.2),
    );
  }
}

class _HoldCard extends StatelessWidget {
  const _HoldCard({
    required this.order,
    required this.isBusy,
    required this.onResume,
  });

  final QueueOrder order;
  final bool isBusy;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Commande en attente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withAlpha(90)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.pause_circle_outline_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.lastHoldReason ??
                        'Traitement temporairement suspendu.',
                    style: const TextStyle(
                      color: AppColors.onBackground,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: isBusy ? null : onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Reprendre le traitement'),
          ),
        ],
      ),
    );
  }
}

class _TerminalResultCard extends StatelessWidget {
  const _TerminalResultCard({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final bool success =
        order.status == QueueOrderStatus.completed ||
        order.status == QueueOrderStatus.awaitingCustomerConfirmation;
    final Color color = success ? AppColors.success : AppColors.error;
    return _SectionCard(
      title: 'Résultat du traitement',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success ? 'Traitement réussi' : 'Échec signalé',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  success
                      ? (order.status ==
                                QueueOrderStatus.awaitingCustomerConfirmation
                            ? 'Le travail de l’agent est terminé. Le retour client reste à clôturer.'
                            : 'Cette commande est terminée.')
                      : _failureSummary(order),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
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

class _ReadOnlyProofCard extends StatelessWidget {
  const _ReadOnlyProofCard({required this.proof});

  final OrderProof proof;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Preuve de transfert',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(proof.bytes, fit: BoxFit.cover),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.outlineVariant.withAlpha(100)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.valueColor = AppColors.onBackground,
    this.valueSize = 15,
  });

  final String label;
  final String value;
  final Color valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _smallLabelStyle),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

const TextStyle _smallLabelStyle = TextStyle(
  color: AppColors.onSurfaceVariant,
  fontSize: 10,
  fontWeight: FontWeight.w900,
  letterSpacing: .55,
);

enum _StepState { done, current, upcoming, warning, failed }

class _TrackStep {
  const _TrackStep({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final _StepState state;
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.step, required this.isLast});

  final _TrackStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (step.state) {
      _StepState.done => AppColors.primaryContainer,
      _StepState.current => AppColors.primary,
      _StepState.warning => AppColors.warning,
      _StepState.failed => AppColors.error,
      _StepState.upcoming => AppColors.outline,
    };
    final IconData icon = switch (step.state) {
      _StepState.done => Icons.check_rounded,
      _StepState.current => Icons.autorenew_rounded,
      _StepState.warning => Icons.pause_rounded,
      _StepState.failed => Icons.close_rounded,
      _StepState.upcoming => Icons.more_horiz_rounded,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withAlpha(150)),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: AppColors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 19),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: step.state == _StepState.upcoming
                          ? AppColors.onSurfaceVariant
                          : AppColors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.subtitle,
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.hint,
    required this.confirmLabel,
    required this.confirmColor,
    required this.maxLength,
  });

  final String title;
  final String subtitle;
  final String label;
  final String hint;
  final String confirmLabel;
  final Color confirmColor;
  final int maxLength;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < 3) {
      setState(() => _error = 'Précise le motif.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetHeader(title: widget.title),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: widget.maxLength,
            style: const TextStyle(color: AppColors.onBackground),
            decoration: _darkInputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(backgroundColor: widget.confirmColor),
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _HoldReasonSheet extends StatefulWidget {
  const _HoldReasonSheet();

  @override
  State<_HoldReasonSheet> createState() => _HoldReasonSheetState();
}

class _HoldReasonSheetState extends State<_HoldReasonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  static const List<String> suggestions = <String>[
    'Réseau momentanément indisponible',
    'Solde ou capacité à vérifier',
    'Problème technique temporaire',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String value = _controller.text.trim();
    if (value.length < 3) {
      setState(
        () => _error = 'Indique pourquoi la commande est mise en attente.',
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHeader(title: 'Mettre en attente'),
          const SizedBox(height: 5),
          const Text(
            'Choisis un motif rapide ou saisis le tien.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: suggestions.map((String suggestion) {
              return ActionChip(
                backgroundColor: AppColors.surfaceContainerHigh,
                side: const BorderSide(color: AppColors.outlineVariant),
                label: Text(suggestion),
                onPressed: () {
                  _controller.text = suggestion;
                  setState(() => _error = null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            style: const TextStyle(color: AppColors.onBackground),
            decoration: _darkInputDecoration(
              labelText: 'Motif',
              hintText: 'Ex. le réseau revient dans quelques minutes…',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningContainer,
              foregroundColor: AppColors.onBackground,
            ),
            child: const Text('Mettre en attente'),
          ),
        ],
      ),
    );
  }
}

class _FailureSheet extends StatefulWidget {
  const _FailureSheet();

  @override
  State<_FailureSheet> createState() => _FailureSheetState();
}

class _FailureSheetState extends State<_FailureSheet> {
  final TextEditingController _observationController = TextEditingController();
  OrderFailureReason? _selectedReason;

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHeader(title: 'Signaler un échec'),
          const SizedBox(height: 5),
          const Text(
            'Choisis la cause principale. Une observation reste facultative.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: OrderFailureReason.values.map((
              OrderFailureReason reason,
            ) {
              final bool selected = _selectedReason == reason;
              return ChoiceChip(
                selected: selected,
                label: Text(_failureReasonLabel(reason)),
                selectedColor: AppColors.error.withAlpha(35),
                backgroundColor: AppColors.surfaceContainerHigh,
                side: BorderSide(
                  color: selected ? AppColors.error : AppColors.outlineVariant,
                ),
                onSelected: (_) => setState(() => _selectedReason = reason),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _observationController,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            style: const TextStyle(color: AppColors.onBackground),
            decoration: _darkInputDecoration(
              labelText: 'Observation (facultatif)',
              hintText: 'Détail utile pour le suivi…',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selectedReason == null
                ? null
                : () {
                    final String text = _observationController.text.trim();
                    Navigator.of(context).pop(
                      _FailureResult(
                        reason: _selectedReason!,
                        observation: text.isEmpty ? null : text,
                      ),
                    );
                  },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirmer l’échec'),
          ),
        ],
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.onBackground,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, inset + 12),
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

class _FailureResult {
  const _FailureResult({required this.reason, this.observation});

  final OrderFailureReason reason;
  final String? observation;
}

InputDecoration _darkInputDecoration({
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
    counterStyle: const TextStyle(color: AppColors.onSurfaceVariant),
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

Uint8List _compressProofForFirestore(Uint8List source) {
  final img.Image? decoded = img.decodeImage(source);
  if (decoded == null) {
    throw FormatException('Cette image ne peut pas être lue.');
  }

  img.Image working = decoded;
  if (decoded.width > 1440 || decoded.height > 1440) {
    working = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: 1440)
        : img.copyResize(decoded, height: 1440);
  }

  for (final int quality in <int>[72, 62, 52, 42]) {
    final Uint8List encoded = Uint8List.fromList(
      img.encodeJpg(working, quality: quality),
    );
    if (encoded.lengthInBytes <= 700000) {
      return encoded;
    }
  }

  working = working.width >= working.height
      ? img.copyResize(working, width: 1080)
      : img.copyResize(working, height: 1080);
  final Uint8List encoded = Uint8List.fromList(
    img.encodeJpg(working, quality: 38),
  );
  if (encoded.lengthInBytes > 750000) {
    throw FormatException(
      'Cette capture reste trop lourde après compression. Choisis une image plus simple.',
    );
  }
  return encoded;
}

String _formatDateTime(DateTime date) {
  final DateTime local = date.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String hours = local.hour.toString().padLeft(2, '0');
  final String minutes = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} à $hours:$minutes';
}

String _processingStepTitle(QueueOrder order) {
  if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return 'En attente d’acceptation';
  }
  switch (order.status) {
    case QueueOrderStatus.paidReady:
      return 'Commande acceptée';
    case QueueOrderStatus.inProgress:
      return 'En cours de traitement';
    case QueueOrderStatus.onHold:
      return 'Traitement en attente';
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
      return 'Traitement réussi';
    case QueueOrderStatus.failed:
      return 'Échec signalé';
    default:
      return orderStatusLabel(order.status);
  }
}

String _processingStepSubtitle(QueueOrder order) {
  if (order.status == QueueOrderStatus.onHold) {
    return order.lastHoldReason ?? 'Reprise nécessaire.';
  }
  if (order.status == QueueOrderStatus.inProgress && order.takenAt != null) {
    return 'Démarré le ${_formatDateTime(order.takenAt!)}';
  }
  if ((order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
          order.status == QueueOrderStatus.completed ||
          order.status == QueueOrderStatus.failed) &&
      order.completedAt != null) {
    return _formatDateTime(order.completedAt!);
  }
  if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return 'Action requise par l’agent.';
  }
  if (order.status == QueueOrderStatus.paidReady) {
    return 'Prête à démarrer.';
  }
  return orderStatusLabel(order.status);
}

_StepState _processingStepState(QueueOrder order) {
  if (order.status == QueueOrderStatus.failed) return _StepState.failed;
  if (order.status == QueueOrderStatus.onHold) return _StepState.warning;
  if (order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
      order.status == QueueOrderStatus.completed) {
    return _StepState.done;
  }
  if (order.status == QueueOrderStatus.inProgress ||
      order.status == QueueOrderStatus.paidReady ||
      order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return _StepState.current;
  }
  return _StepState.upcoming;
}

String _agentStatusLabel(QueueOrder order) {
  if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return 'À ACCEPTER';
  }
  switch (order.status) {
    case QueueOrderStatus.paidReady:
      return 'ACCEPTÉE';
    case QueueOrderStatus.inProgress:
      return 'EN COURS';
    case QueueOrderStatus.onHold:
      return 'EN ATTENTE';
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
      return 'RÉUSSIE';
    case QueueOrderStatus.failed:
      return 'ÉCHEC';
    default:
      return orderStatusLabel(order.status).toUpperCase();
  }
}

Color _agentStatusColor(QueueOrder order) {
  if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return AppColors.warning;
  }
  switch (order.status) {
    case QueueOrderStatus.inProgress:
    case QueueOrderStatus.paidReady:
      return AppColors.primary;
    case QueueOrderStatus.onHold:
      return AppColors.warning;
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
      return AppColors.success;
    case QueueOrderStatus.failed:
      return AppColors.error;
    default:
      return AppColors.onSurfaceVariant;
  }
}

String _failureReasonLabel(OrderFailureReason reason) {
  switch (reason) {
    case OrderFailureReason.incorrectNumber:
      return 'Numéro incorrect';
    case OrderFailureReason.networkUnavailable:
      return 'Réseau indisponible';
    case OrderFailureReason.offerUnavailable:
      return 'Offre indisponible';
    case OrderFailureReason.insufficientBalance:
      return 'Solde insuffisant';
    case OrderFailureReason.technicalError:
      return 'Erreur technique';
    case OrderFailureReason.incorrectPayment:
      return 'Paiement incorrect';
    case OrderFailureReason.other:
      return 'Autre';
  }
}

String _failureSummary(QueueOrder order) {
  final OrderFailureReason? reason = order.failureReason;
  final String base = reason == null
      ? 'Échec enregistré.'
      : _failureReasonLabel(reason);
  final String? observation = order.observation;
  if (observation == null || observation.trim().isEmpty) return base;
  return '$base — ${observation.trim()}';
}
