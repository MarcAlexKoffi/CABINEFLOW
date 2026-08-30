import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
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
import 'package:material_symbols_icons/symbols.dart';

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
      confirmColor: IzyTelColors.error,
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

  Future<void> _chooseProofSource() async {
    if (_isBusy || widget.order.status != QueueOrderStatus.inProgress) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ProofSourceSheet(),
    );
    if (source == null || !mounted) return;

    await _pickProof(source);
  }

  Future<void> _pickProof(ImageSource source) async {
    if (_isBusy || widget.order.status != QueueOrderStatus.inProgress) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 88,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;

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
      _showMessage(
        source == ImageSource.camera
            ? 'Photo prise et preuve enregistrée.'
            : 'Preuve enregistrée.',
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        source == ImageSource.camera
            ? 'Impossible d’utiliser cette photo. Réessaie ou choisis la galerie.'
            : 'Impossible de préparer cette image. Essaie une autre capture.',
      );
    }
  }

  Future<void> _confirmSuccess() async {
    if (_proof == null) {
      _showMessage('Ajoute d’abord une preuve du transfert.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: IzyTelColors.surface,
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
              style: FilledButton.styleFrom(
                backgroundColor: IzyTelColors.success,
              ),
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

  void _showInfoSheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          decoration: const BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: IzyTelColors.outlineStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        );
      },
    );
  }

  int _activityCount(QueueOrder order) {
    int count = 1;
    if (order.paymentConfirmedAt != null || order.paidAt != null) count++;
    if (order.assignedAt != null) count++;
    if (order.takenAt != null) count++;
    if (order.lastHeldAt != null) count++;
    if (order.lastResumedAt != null) count++;
    if (order.completedAt != null) count++;
    return count;
  }

  Widget? _buildBottomActions(QueueOrder order) {
    if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
      return _SingleBottomAction(
        isBusy: _isBusy,
        label: 'Accepter',
        icon: Symbols.check_rounded,
        onPressed: _accept,
      );
    }

    if (order.assignmentStatus == OrderAssignmentStatus.accepted &&
        order.status == QueueOrderStatus.paidReady) {
      return _SingleBottomAction(
        isBusy: _isBusy,
        label: 'Démarrer le traitement',
        icon: Symbols.play_arrow_rounded,
        onPressed: _startProcessing,
      );
    }

    if (order.status == QueueOrderStatus.onHold) {
      return _SingleBottomAction(
        isBusy: _isBusy,
        label: 'Reprendre le traitement',
        icon: Symbols.play_arrow_rounded,
        onPressed: _resumeProcessing,
      );
    }

    if (order.status == QueueOrderStatus.inProgress) {
      return _ProcessingBottomActions(
        isBusy: _isBusy,
        onHold: _putOnHold,
        onSuccess: _confirmSuccess,
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final QueueOrder order = widget.order;
    final Widget? bottomActions = _buildBottomActions(order);
    final double referenceScale = (MediaQuery.sizeOf(context).width / 290)
        .clamp(.95, 1.35);

    return Column(
      children: [
        _ReferenceDetailTopBar(
          order: order,
          onBack: widget.onBack,
          onMenuSelected: (String value) {
            if (value == 'refuse') {
              _refuse();
            } else if (value == 'failure') {
              _markFailed();
            }
          },
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12 * referenceScale,
              13 * referenceScale,
              12 * referenceScale,
              bottomActions == null ? 24 : 106,
            ),
            children: [
              _ReferenceOrderSummary(order: order),
              SizedBox(height: 18 * referenceScale),
              _ReferenceProgress(order: order),
              SizedBox(height: 18 * referenceScale),
              _DetailMenuCard(
                rows: [
                  _DetailMenuRowData(
                    icon: Symbols.person_rounded,
                    label: 'Client',
                    onTap: () => _showInfoSheet(
                      title: 'Client',
                      child: _InfoSheetRows(
                        rows: <MapEntry<String, String>>[
                          MapEntry('Nom', order.clientName),
                          MapEntry(
                            'WhatsApp',
                            formatIvorianPhone(order.clientWhatsappPhone),
                          ),
                          MapEntry(
                            'Bénéficiaire',
                            formatIvorianPhone(order.beneficiaryPhone),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _DetailMenuRowData(
                    icon: Symbols.wallet_rounded,
                    label: 'Paiement',
                    trailing:
                        order.paymentStatus == OrderPaymentStatus.confirmed
                        ? const _TinyStateBadge(
                            label: 'Confirmé',
                            color: IzyTelColors.success,
                          )
                        : null,
                    onTap: () => _showInfoSheet(
                      title: 'Paiement',
                      child: _InfoSheetRows(
                        rows: <MapEntry<String, String>>[
                          MapEntry('Montant', formatCfaFull(order.amount)),
                          MapEntry(
                            'Payeur',
                            order.paymentPayerName ?? order.clientName,
                          ),
                          MapEntry(
                            'Référence',
                            order.paymentReference ?? 'Non renseignée',
                          ),
                          MapEntry(
                            'Statut',
                            order.paymentStatus == OrderPaymentStatus.confirmed
                                ? 'Confirmé'
                                : 'En attente',
                          ),
                        ],
                      ),
                    ),
                  ),
                  _DetailMenuRowData(
                    icon: Symbols.format_list_bulleted_rounded,
                    label: 'Détails de l’offre',
                    onTap: () => _showInfoSheet(
                      title: 'Détails de l’offre',
                      child: _InfoSheetRows(
                        rows: <MapEntry<String, String>>[
                          MapEntry('Réseau', networkLabel(order.network)),
                          MapEntry('Offre', order.offerLabel),
                          MapEntry('Montant', formatCfaFull(order.amount)),
                          MapEntry(
                            'Bénéficiaire',
                            formatIvorianPhone(order.beneficiaryPhone),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _DetailMenuRowData(
                    icon: Symbols.image_rounded,
                    label: 'Preuve',
                    trailing: _ProofThumbnail(
                      proof: _proof,
                      isLoading: _isLoadingProof,
                    ),
                    onTap: order.status == QueueOrderStatus.inProgress
                        ? _chooseProofSource
                        : () {
                            if (_proof == null) {
                              _showMessage('Aucune preuve enregistrée.');
                              return;
                            }
                            _showInfoSheet(
                              title: 'Preuve de transfert',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  _proof!.bytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            );
                          },
                  ),
                  _DetailMenuRowData(
                    icon: Symbols.history_rounded,
                    label: 'Journal d’activité',
                    trailing: _CountBadge(value: _activityCount(order)),
                    onTap: () => _showInfoSheet(
                      title: 'Journal d’activité',
                      child: _ActivitySheet(order: order),
                    ),
                  ),
                  _DetailMenuRowData(
                    icon: Symbols.chat_bubble_rounded,
                    label: 'Demande client',
                    onTap: () => _showInfoSheet(
                      title: 'Demande client',
                      child: Text(
                        'Les demandes liées à cette commande sont consultables depuis le centre de support IzyTel.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  _DetailMenuRowData(
                    icon: Symbols.payments_rounded,
                    label: 'Remboursement',
                    onTap: () => _showInfoSheet(
                      title: 'Remboursement',
                      child: Text(
                        'Les remboursements sont validés depuis l’espace administrateur.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ?bottomActions,
      ],
    );
  }
}

class _ReferenceDetailTopBar extends StatelessWidget {
  const _ReferenceDetailTopBar({
    required this.order,
    required this.onBack,
    required this.onMenuSelected,
  });

  final QueueOrder order;
  final VoidCallback onBack;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final List<PopupMenuEntry<String>> actions = <PopupMenuEntry<String>>[];
    if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
      actions.add(
        const PopupMenuItem<String>(
          value: 'refuse',
          child: Text('Refuser la commande'),
        ),
      );
    }
    if (order.status == QueueOrderStatus.inProgress) {
      actions.add(
        const PopupMenuItem<String>(
          value: 'failure',
          child: Text('Signaler un échec'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 6, 7, 6),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(bottom: BorderSide(color: IzyTelColors.outline)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Symbols.arrow_back_rounded,
              size: IzyTelIconSize.action,
            ),
          ),
          Expanded(
            child: Text(
              'Détail commande',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: IzyTelTypeScale.cardTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actions.isNotEmpty)
            PopupMenuButton<String>(
              key: const ValueKey<String>('agent-order-detail-actions'),
              tooltip: 'Actions de la commande',
              onSelected: onMenuSelected,
              itemBuilder: (_) => actions,
              icon: const Icon(
                Symbols.more_vert_rounded,
                size: IzyTelIconSize.action,
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _ReferenceOrderSummary extends StatelessWidget {
  const _ReferenceOrderSummary({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final Color accent = networkColor(order.network);
    final Color statusColor = _agentStatusColor(order);
    final double scale = (MediaQuery.sizeOf(context).width / 290).clamp(
      .95,
      1.35,
    );

    return SizedBox(
      height: 132 * scale,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          12 * scale,
          14 * scale,
          12 * scale,
          12 * scale,
        ),
        decoration: BoxDecoration(
          color: IzyTelColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: IzyTelColors.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 27 * scale,
                  height: 27 * scale,
                  padding: EdgeInsets.all(2.5 * scale),
                  decoration: BoxDecoration(
                    color: accent.withAlpha(15),
                    borderRadius: BorderRadius.circular(7 * scale),
                  ),
                  child: Image.asset(
                    networkAsset(order.network),
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 8 * scale),
                Expanded(
                  child: Text(
                    networkLabel(order.network),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontSize: IzyTelTypeScale.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _TinyStateBadge(
                  label: _agentStatusLabel(order),
                  color: statusColor,
                ),
              ],
            ),
            Text(
              order.offerLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: IzyTelTypeScale.title3,
                height: 1.22,
                fontWeight: FontWeight.w700,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatIvorianPhone(order.beneficiaryPhone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: IzyTelColors.textPrimary,
                      fontSize: IzyTelTypeScale.title3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .15,
                    ),
                  ),
                ),
                SizedBox(width: 8 * scale),
                Text(
                  formatCfa(order.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.primaryStrong,
                    fontSize: IzyTelTypeScale.title2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                order.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: IzyTelColors.textMuted,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReferenceStepState { done, active, pending }

class _ReferenceProgress extends StatelessWidget {
  const _ReferenceProgress({required this.order});

  final QueueOrder order;

  bool get _isAssigned =>
      order.assignedAt != null ||
      order.assignmentStatus != OrderAssignmentStatus.unassigned;

  bool get _isProcessing => <QueueOrderStatus>{
    QueueOrderStatus.inProgress,
    QueueOrderStatus.onHold,
    QueueOrderStatus.awaitingCustomerConfirmation,
    QueueOrderStatus.completed,
    QueueOrderStatus.failed,
    QueueOrderStatus.refunded,
  }.contains(order.status);

  bool get _isFinished => <QueueOrderStatus>{
    QueueOrderStatus.completed,
    QueueOrderStatus.failed,
    QueueOrderStatus.refunded,
  }.contains(order.status);

  _ReferenceStepState _state(int index) {
    if (index == 0) {
      return order.paymentStatus == OrderPaymentStatus.confirmed
          ? _ReferenceStepState.done
          : _ReferenceStepState.active;
    }
    if (index == 1) {
      if (_isAssigned) return _ReferenceStepState.done;
      return _ReferenceStepState.pending;
    }
    if (index == 2) {
      if (_isFinished) return _ReferenceStepState.done;
      if (_isProcessing) return _ReferenceStepState.active;
      return _ReferenceStepState.pending;
    }
    return _isFinished ? _ReferenceStepState.done : _ReferenceStepState.pending;
  }

  String _dateLabel(int index) {
    final DateTime? date = switch (index) {
      0 => order.paymentConfirmedAt ?? order.paidAt,
      1 => order.assignedAt,
      2 => order.takenAt ?? order.lastResumedAt,
      _ => order.completedAt,
    };
    if (date == null) return '';
    final DateTime local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Payée',
      'Affectée',
      'En traitement',
      'Terminée',
    ];
    final double scale = (MediaQuery.sizeOf(context).width / 290).clamp(
      .95,
      1.35,
    );
    return SizedBox(
      height: 54 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 2 * scale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(labels.length, (int index) {
            final _ReferenceStepState state = _state(index);
            return Expanded(
              child: _ReferenceProgressStep(
                label: labels[index],
                date: _dateLabel(index),
                state: state,
                showLeftLine: index > 0,
                showRightLine: index < labels.length - 1,
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ReferenceProgressStep extends StatelessWidget {
  const _ReferenceProgressStep({
    required this.label,
    required this.date,
    required this.state,
    required this.showLeftLine,
    required this.showRightLine,
  });

  final String label;
  final String date;
  final _ReferenceStepState state;
  final bool showLeftLine;
  final bool showRightLine;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      _ReferenceStepState.done => IzyTelColors.success,
      _ReferenceStepState.active => IzyTelColors.primary,
      _ReferenceStepState.pending => IzyTelColors.outlineStrong,
    };
    return Column(
      children: [
        SizedBox(
          height: 31,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (showLeftLine)
                Positioned(
                  left: 0,
                  right: 15,
                  child: Container(
                    height: 1.5,
                    color: state == _ReferenceStepState.pending
                        ? IzyTelColors.outline
                        : color.withAlpha(140),
                  ),
                ),
              if (showRightLine)
                Positioned(
                  left: 15,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    color: state == _ReferenceStepState.done
                        ? IzyTelColors.success.withAlpha(140)
                        : IzyTelColors.outline,
                  ),
                ),
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == _ReferenceStepState.pending
                      ? Colors.white
                      : color,
                  shape: BoxShape.circle,
                  border: state == _ReferenceStepState.pending
                      ? Border.all(color: IzyTelColors.outlineStrong)
                      : null,
                ),
                child: Icon(
                  state == _ReferenceStepState.done
                      ? Symbols.check_rounded
                      : state == _ReferenceStepState.active
                      ? Symbols.hourglass_top_rounded
                      : Symbols.person_rounded,
                  size: IzyTelIconSize.info,
                  color: state == _ReferenceStepState.pending
                      ? IzyTelColors.textMuted
                      : Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: state == _ReferenceStepState.pending
                    ? IzyTelColors.textSecondary
                    : IzyTelColors.textPrimary,
                fontSize: IzyTelTypeScale.micro,
                fontWeight: state == _ReferenceStepState.active
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              date,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: IzyTelColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailMenuRowData {
  const _DetailMenuRowData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
}

class _DetailMenuCard extends StatelessWidget {
  const _DetailMenuCard({required this.rows});

  final List<_DetailMenuRowData> rows;

  @override
  Widget build(BuildContext context) {
    final double scale = (MediaQuery.sizeOf(context).width / 290).clamp(
      .95,
      1.35,
    );
    final double rowHeight = 41 * scale;

    return Container(
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        children: List<Widget>.generate(rows.length, (int index) {
          final _DetailMenuRowData row = rows[index];
          return Column(
            children: [
              SizedBox(
                height: rowHeight,
                child: InkWell(
                  onTap: row.onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                    child: Row(
                      children: [
                        Icon(
                          row.icon,
                          size: IzyTelIconSize.action,
                          color: IzyTelColors.textPrimary,
                        ),
                        SizedBox(width: 10 * scale),
                        Expanded(
                          child: Text(
                            row.label,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: IzyTelColors.textPrimary,
                                  fontSize: IzyTelTypeScale.text,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        if (row.trailing != null) ...[
                          row.trailing!,
                          SizedBox(width: 5 * scale),
                        ],
                        Icon(
                          Symbols.chevron_right_rounded,
                          size: IzyTelIconSize.info,
                          color: IzyTelColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (index < rows.length - 1)
                Divider(indent: 12 * scale, endIndent: 12 * scale),
            ],
          );
        }),
      ),
    );
  }
}

class _TinyStateBadge extends StatelessWidget {
  const _TinyStateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontSize: IzyTelTypeScale.micro,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: IzyTelColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$value',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: IzyTelColors.primary,
          fontSize: IzyTelTypeScale.micro,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProofThumbnail extends StatelessWidget {
  const _ProofThumbnail({required this.proof, required this.isLoading});

  final OrderProof? proof;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox.square(
        dimension: 28,
        child: Padding(
          padding: EdgeInsets.all(7),
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      );
    }
    if (proof == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Image.memory(
        proof!.bytes,
        width: 34,
        height: 28,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _InfoSheetRows extends StatelessWidget {
  const _InfoSheetRows({required this.rows});
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (MapEntry<String, String> row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      row.key,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: IzyTelTypeScale.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({required this.order});
  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, DateTime?>> entries =
        <MapEntry<String, DateTime?>>[
          MapEntry('Commande reçue', order.createdAt),
          MapEntry(
            'Paiement confirmé',
            order.paymentConfirmedAt ?? order.paidAt,
          ),
          MapEntry('Commande affectée', order.assignedAt),
          MapEntry('Traitement démarré', order.takenAt),
          MapEntry('Traitement terminé', order.completedAt),
        ];
    return Column(
      children: entries
          .where((MapEntry<String, DateTime?> e) => e.value != null)
          .map((MapEntry<String, DateTime?> entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  const Icon(
                    Symbols.check_circle_rounded,
                    size: 17,
                    color: IzyTelColors.success,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: IzyTelTypeScale.label,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _formatDateTime(entry.value!),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontSize: IzyTelTypeScale.micro,
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ProcessingBottomActions extends StatelessWidget {
  const _ProcessingBottomActions({
    required this.isBusy,
    required this.onHold,
    required this.onSuccess,
  });

  final bool isBusy;
  final VoidCallback onHold;
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(top: BorderSide(color: IzyTelColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: isBusy ? null : onHold,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Symbols.pause_rounded, size: IzyTelIconSize.info),
                      SizedBox(width: 6),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Mettre en attente',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: IzyTelTypeScale.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: isBusy ? null : onSuccess,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isBusy)
                        const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            color: Colors.white,
                          ),
                        )
                      else
                        const Icon(
                          Symbols.check_circle_rounded,
                          size: IzyTelIconSize.info,
                        ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Marquer comme réussie',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: IzyTelTypeScale.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleBottomAction extends StatelessWidget {
  const _SingleBottomAction({
    required this.isBusy,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final bool isBusy;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        border: Border(top: BorderSide(color: IzyTelColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isBusy ? null : onPressed,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, size: 16),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class _ProofSourceSheet extends StatelessWidget {
  const _ProofSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: IzyTelColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: IzyTelColors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: IzyTelColors.outline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajouter une preuve',
              style: TextStyle(
                color: IzyTelColors.textPrimary,
                fontSize: IzyTelTypeScale.title2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choisis une photo existante ou prends-en une maintenant.',
              style: TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: IzyTelTypeScale.micro,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _ProofSourceTile(
              icon: Symbols.photo_camera_rounded,
              title: 'Appareil photo',
              subtitle: 'Prendre une photo en temps réel',
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            _ProofSourceTile(
              icon: Symbols.photo_library_rounded,
              title: 'Galerie',
              subtitle: 'Choisir une capture déjà enregistrée',
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofSourceTile extends StatelessWidget {
  const _ProofSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: IzyTelColors.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: IzyTelColors.primary),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.label,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textSecondary,
              ),
            ],
          ),
        ),
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
            style: const TextStyle(color: IzyTelColors.textSecondary),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            maxLength: widget.maxLength,
            style: const TextStyle(color: IzyTelColors.textPrimary),
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
            style: TextStyle(color: IzyTelColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: suggestions.map((String suggestion) {
              return ActionChip(
                backgroundColor: IzyTelColors.surface,
                side: const BorderSide(color: IzyTelColors.outline),
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
            style: const TextStyle(color: IzyTelColors.textPrimary),
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
              backgroundColor: IzyTelColors.warningSoft,
              foregroundColor: IzyTelColors.textPrimary,
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
            style: TextStyle(color: IzyTelColors.textSecondary),
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
                selectedColor: IzyTelColors.error.withAlpha(35),
                backgroundColor: IzyTelColors.surface,
                side: BorderSide(
                  color: selected ? IzyTelColors.error : IzyTelColors.outline,
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
            style: const TextStyle(color: IzyTelColors.textPrimary),
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
            style: FilledButton.styleFrom(backgroundColor: IzyTelColors.error),
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
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.title2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Symbols.close_rounded),
          color: IzyTelColors.textSecondary,
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
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: IzyTelColors.outline),
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
    fillColor: IzyTelColors.surface,
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    labelStyle: const TextStyle(color: IzyTelColors.textSecondary),
    floatingLabelStyle: const TextStyle(color: IzyTelColors.primary),
    hintStyle: const TextStyle(color: IzyTelColors.textSecondary),
    counterStyle: const TextStyle(color: IzyTelColors.textSecondary),
    border: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.outline),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.outline),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.primary, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: IzyTelColors.error, width: 1.5),
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

String _agentStatusLabel(QueueOrder order) {
  if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return 'À accepter';
  }
  switch (order.status) {
    case QueueOrderStatus.paidReady:
      return 'Acceptée';
    case QueueOrderStatus.inProgress:
      return 'En traitement';
    case QueueOrderStatus.onHold:
      return 'En attente';
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
      return 'Réussie';
    case QueueOrderStatus.failed:
      return 'Échec';
    default:
      return orderStatusLabel(order.status);
  }
}

Color _agentStatusColor(QueueOrder order) {
  if (order.assignmentStatus == OrderAssignmentStatus.assigned) {
    return IzyTelColors.warning;
  }
  switch (order.status) {
    case QueueOrderStatus.inProgress:
    case QueueOrderStatus.paidReady:
      return IzyTelColors.primary;
    case QueueOrderStatus.onHold:
      return IzyTelColors.warning;
    case QueueOrderStatus.awaitingCustomerConfirmation:
    case QueueOrderStatus.completed:
      return IzyTelColors.success;
    case QueueOrderStatus.failed:
      return IzyTelColors.error;
    default:
      return IzyTelColors.textSecondary;
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
