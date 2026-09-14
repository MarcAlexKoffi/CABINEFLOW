import 'package:cabine_flow/backoffice/presentation/services/backoffice_whatsapp_service.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _SupportScope { all, newRequests, inProgress, resolved }

class BackofficeSupportRequestsPage extends StatefulWidget {
  const BackofficeSupportRequestsPage({
    super.key,
    required this.user,
    required this.repository,
    required this.refundRepository,
    required this.orderHistoryRepository,
    this.onOpenRefunds,
    this.initialOrderReference,
  });

  final AppUser user;
  final SupportRequestRepository repository;
  final RefundRepository refundRepository;
  final OrderHistoryRepository orderHistoryRepository;
  final ValueChanged<String>? onOpenRefunds;
  final String? initialOrderReference;

  @override
  State<BackofficeSupportRequestsPage> createState() =>
      _BackofficeSupportRequestsPageState();
}

class _BackofficeSupportRequestsPageState
    extends State<BackofficeSupportRequestsPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<SupportRequest>> _stream;
  late final Stream<List<RefundCase>> _refundStream;
  _SupportScope _scope = _SupportScope.all;
  String _query = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchAllRequests();
    _refundStream = widget.refundRepository.watchAll();
    final String initialReference = widget.initialOrderReference?.trim() ?? '';
    if (initialReference.isNotEmpty) {
      _scope = _SupportScope.all;
      _query = initialReference;
      _searchController.text = initialReference;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportRequest>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<SupportRequest>> requestSnapshot) {
        if (requestSnapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.cloud_off_rounded,
            title: 'Demandes clients indisponibles',
            message:
                'Le centre d’assistance ne peut pas être chargé pour le moment.',
          );
        }
        if (!requestSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<RefundCase>>(
          stream: _refundStream,
          builder: (BuildContext context, AsyncSnapshot<List<RefundCase>> refundSnapshot) {
            final List<SupportRequest> all = requestSnapshot.data!;
            final List<RefundCase> refunds =
                refundSnapshot.data ?? const <RefundCase>[];
            final int newCount = all
                .where(
                  (SupportRequest item) =>
                      item.status == SupportRequestStatus.newRequest,
                )
                .length;
            final int inProgressCount = all
                .where(
                  (SupportRequest item) =>
                      item.status == SupportRequestStatus.inProgress,
                )
                .length;
            final int resolvedCount = all
                .where((SupportRequest item) => item.isResolved)
                .length;
            final List<SupportRequest> visible = _filtered(all);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                BackofficePageIntro(
                  eyebrow: 'Clients / Assistance',
                  title: 'Centre des demandes clients',
                  description: widget.user.permissions.canProcessSupportRequests
                      ? 'Traite chaque demande jusqu’à son issue réelle : résolution simple ou remboursement lié, avec notification WhatsApp vérifiable.'
                      : 'Supervise les demandes clients, leurs remboursements liés et leur avancement en lecture seule.',
                  icon: Symbols.support_agent_rounded,
                ),
                const SizedBox(height: 18),
                _metrics(
                  allCount: all.length,
                  newCount: newCount,
                  inProgressCount: inProgressCount,
                  resolvedCount: resolvedCount,
                ),
                const SizedBox(height: 14),
                if (refundSnapshot.hasError) ...<Widget>[
                  _linkedWorkflowBanner(
                    icon: Symbols.warning_rounded,
                    title: 'Lien remboursements temporairement indisponible',
                    message:
                        'Les demandes restent consultables, mais leur dossier de remboursement associé ne peut pas être vérifié pour le moment.',
                    color: BackofficePalette.warning,
                  ),
                  const SizedBox(height: 14),
                ] else ...<Widget>[
                  _linkedWorkflowBanner(
                    icon: Symbols.account_tree_rounded,
                    title: 'Workflow lié Demande → Remboursement',
                    message:
                        'Après vérification, choisissez explicitement « Résoudre sans remboursement » ou « Créer remboursement ». Aucun dossier financier n’est créé automatiquement. Une fois un remboursement réellement effectué, sa sortie est intégrée à la Caisse Wave et aux mouvements financiers.',
                    color: BackofficePalette.primary,
                  ),
                  const SizedBox(height: 14),
                ],
                _filters(
                  allCount: all.length,
                  newCount: newCount,
                  inProgressCount: inProgressCount,
                  resolvedCount: resolvedCount,
                ),
                const SizedBox(height: 14),
                if (visible.isEmpty)
                  const BackofficeEmptyState(
                    icon: Symbols.inbox_rounded,
                    title: 'Aucune demande dans cette vue',
                    message:
                        'Les demandes correspondant aux filtres actifs apparaîtront ici.',
                  )
                else
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          if (constraints.maxWidth >= 920) {
                            return _desktopTable(visible, refunds);
                          }
                          return Column(
                            children: visible
                                .map(
                                  (SupportRequest request) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _mobileCard(
                                      request,
                                      _refundFor(request, refunds),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
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

  Widget _linkedWorkflowBanner({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color, fill: 1, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics({
    required int allCount,
    required int newCount,
    required int inProgressCount,
    required int resolvedCount,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        const double gap = 10;
        final double width =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(
            label: 'À traiter',
            value: '$newCount',
            caption: 'nouvelles demandes',
            icon: Symbols.support_agent_rounded,
            emphasis: BackofficePalette.warning,
          ),
          BackofficeMetricCard(
            label: 'En cours',
            value: '$inProgressCount',
            caption: 'prises en charge',
            icon: Symbols.fact_check_rounded,
          ),
          BackofficeMetricCard(
            label: 'Traitées',
            value: '$resolvedCount',
            caption: 'résolues ou fermées',
            icon: Symbols.task_alt_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Total',
            value: '$allCount',
            caption: 'demandes suivies',
            icon: Symbols.support_agent_rounded,
            emphasis: BackofficePalette.cyan,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((Widget card) => SizedBox(width: width, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _filters({
    required int allCount,
    required int newCount,
    required int inProgressCount,
    required int resolvedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Référence, motif, description ou responsable',
              prefixIcon: Icon(Symbols.search_rounded),
            ),
          );
          final Widget scope = DropdownButtonFormField<_SupportScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Vue'),
            items: <DropdownMenuItem<_SupportScope>>[
              DropdownMenuItem(
                value: _SupportScope.all,
                child: Text('Toutes ($allCount)'),
              ),
              DropdownMenuItem(
                value: _SupportScope.newRequests,
                child: Text('À traiter ($newCount)'),
              ),
              DropdownMenuItem(
                value: _SupportScope.inProgress,
                child: Text('En cours ($inProgressCount)'),
              ),
              DropdownMenuItem(
                value: _SupportScope.resolved,
                child: Text('Historique ($resolvedCount)'),
              ),
            ],
            onChanged: (_SupportScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          if (constraints.maxWidth < 760) {
            return Column(
              children: <Widget>[search, const SizedBox(height: 10), scope],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(flex: 3, child: search),
              const SizedBox(width: 10),
              SizedBox(width: 250, child: scope),
            ],
          );
        },
      ),
    );
  }

  List<SupportRequest> _filtered(List<SupportRequest> all) {
    final String query = _query.trim().toLowerCase();
    final Iterable<SupportRequest> scoped = all.where((SupportRequest item) {
      switch (_scope) {
        case _SupportScope.all:
          return true;
        case _SupportScope.newRequests:
          return item.status == SupportRequestStatus.newRequest;
        case _SupportScope.inProgress:
          return item.status == SupportRequestStatus.inProgress;
        case _SupportScope.resolved:
          return item.isResolved;
      }
    });
    final List<SupportRequest> result = scoped
        .where((SupportRequest item) {
          if (query.isEmpty) return true;
          return <String>[
            item.orderReference,
            item.type.label,
            item.description,
            item.status.label,
            item.assignedToName ?? '',
            item.resolvedByName ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
    result.sort(
      (SupportRequest a, SupportRequest b) =>
          b.updatedAt.compareTo(a.updatedAt),
    );
    return result;
  }

  RefundCase? _refundFor(SupportRequest request, List<RefundCase> refunds) {
    for (final RefundCase refund in refunds) {
      if (refund.supportRequestId == request.id) return refund;
    }
    for (final RefundCase refund in refunds) {
      if (refund.orderId == request.orderId) return refund;
    }
    return null;
  }

  Widget _desktopTable(
    List<SupportRequest> requests,
    List<RefundCase> refunds,
  ) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'DEMANDE', flex: 4),
        BackofficeTableColumnSpec(label: 'COMMANDE', flex: 3),
        BackofficeTableColumnSpec(label: 'SUIVI', flex: 3),
        BackofficeTableColumnSpec(
          label: 'ACTION',
          flex: 2,
          alignment: Alignment.centerRight,
        ),
      ],
      rows: requests
          .map((SupportRequest request) {
            final RefundCase? refund = _refundFor(request, refunds);
            final Color color = _statusColor(request.status);
            return BackofficeDesktopTableRow(
              accentColor: request.status == SupportRequestStatus.newRequest
                  ? BackofficePalette.warning
                  : null,
              backgroundColor: request.status == SupportRequestStatus.newRequest
                  ? BackofficePalette.warning.withValues(alpha: .025)
                  : null,
              onTap: () => _openDetails(request, refund),
              cells: <BackofficeTableCellSpec>[
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeStatusBadge(
                    label: request.status.label,
                    color: color,
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 4,
                  child: _twoLines(
                    request.type.label,
                    request.description.isEmpty
                        ? 'Sans description'
                        : request.description,
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 3,
                  child: _twoLines(
                    request.orderReference,
                    _formatDate(request.createdAt),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 3,
                  child: _twoLines(
                    request.assignedToName ?? 'Non attribuée',
                    refund != null
                        ? 'Remboursement • ${refund.status.label}'
                        : request.customerWasNotified
                        ? 'Client notifié sur WhatsApp'
                        : 'Aucun remboursement lié',
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  alignment: Alignment.centerRight,
                  child: _primaryAction(request, refund),
                ),
              ],
            );
          })
          .toList(growable: false),
    );
  }

  Widget _mobileCard(SupportRequest request, RefundCase? refund) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(request, refund),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: BackofficeStatusBadge(
                      label: request.status.label,
                      color: _statusColor(request.status),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(request.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.type.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                request.orderReference,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (refund != null) ...<Widget>[
                const SizedBox(height: 8),
                BackofficeStatusBadge(
                  label: 'Remboursement • ${refund.status.label}',
                  color: _refundStatusColor(refund.status),
                ),
              ],
              if (request.description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  request.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _primaryAction(request, refund),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twoLines(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _primaryAction(SupportRequest request, RefundCase? refund) {
    if (!widget.user.permissions.canProcessSupportRequests) {
      return OutlinedButton(
        onPressed: () => _openDetails(request, refund),
        child: const Text('Voir'),
      );
    }
    switch (request.status) {
      case SupportRequestStatus.newRequest:
        return FilledButton(
          onPressed: _submitting ? null : () => _takeInCharge(request),
          child: const Text('Prendre'),
        );
      case SupportRequestStatus.inProgress:
        return FilledButton(
          onPressed: _submitting ? null : () => _openDetails(request, refund),
          child: const Text('Traiter'),
        );
      case SupportRequestStatus.resolved:
        if (refund != null) {
          return FilledButton.tonal(
            onPressed: widget.onOpenRefunds == null
                ? null
                : () => widget.onOpenRefunds!.call(request.orderReference),
            child: const Text('Voir remboursement'),
          );
        }
        if (!request.customerWasNotified) {
          return FilledButton(
            onPressed: _submitting ? null : () => _notifyCustomer(request),
            child: const Text('WhatsApp'),
          );
        }
        return OutlinedButton(
          onPressed: _submitting ? null : () => _close(request),
          child: const Text('Fermer'),
        );
      case SupportRequestStatus.closed:
        return OutlinedButton(
          onPressed: () => _openDetails(request, refund),
          child: const Text('Voir'),
        );
    }
  }

  Future<void> _takeInCharge(SupportRequest request) async {
    await _runAction(
      () => widget.repository.takeInCharge(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'La demande est maintenant en cours de traitement.',
      onSuccess: () {
        if (_scope != _SupportScope.all) {
          setState(() => _scope = _SupportScope.all);
        }
      },
    );
  }

  Future<void> _resolve(SupportRequest request) async {
    final String? note = await _textDialog(
      title: 'Résoudre sans remboursement',
      hint: 'Expliquez au client la solution apportée.',
      actionLabel: 'Confirmer la résolution',
    );
    if (note == null) return;
    await _runAction(
      () => widget.repository.resolve(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
        resolutionNote: note,
      ),
      successMessage:
          'La demande est résolue. Vous pouvez maintenant notifier le client sur WhatsApp.',
    );
  }

  Future<void> _createRefund(SupportRequest request, QueueOrder order) async {
    if (order.paymentStatus != OrderPaymentStatus.confirmed) {
      _showMessage(
        'Le paiement doit être confirmé avant de créer un remboursement Wave.',
      );
      return;
    }
    final RefundCreationDraft? draft = await _refundDialog(request, order);
    if (draft == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      final RefundCase refund = await widget.refundRepository.create(
        request: RefundCreationRequest(
          orderId: order.id,
          orderReference: order.reference,
          origin: RefundOrigin.supportRequest,
          supportRequestId: request.id,
          supportRequestType: request.type.storageValue,
          supportRequestDescription: request.description,
          customerAuthUid: request.customerAuthUid,
          clientName: order.clientName,
          clientWhatsappPhone: order.clientWhatsappPhone,
          originalAmount: order.amount,
          amount: draft.amount,
          reason: draft.reason,
          reasonNote: draft.reasonNote,
          paymentChannel: 'wave',
          originalPaymentReference: _initialPaymentReference(order),
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      );

      if (!mounted) return;
      _showMessage(
        'Remboursement créé. La demande reste en cours jusqu’au remboursement réel du client.',
      );
      widget.onOpenRefunds?.call(refund.orderReference);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _notifyCustomer(SupportRequest request) async {
    final QueueOrder? order = await _loadOrder(request);
    if (!mounted) return;
    if (order == null) {
      _showMessage('Impossible de retrouver la commande liée à cette demande.');
      return;
    }
    final String resolution = request.resolutionNote?.trim() ?? '';
    final String message = resolution.isEmpty
        ? 'Bonjour ${order.clientName}, votre demande concernant la commande ${request.orderReference} a été traitée par IzyTel.'
        : 'Bonjour ${order.clientName}, votre demande concernant la commande ${request.orderReference} a été traitée par IzyTel. Réponse : $resolution';
    final bool opened = await BackofficeWhatsAppService.openMessage(
      phone: order.clientWhatsappPhone,
      message: message,
    );
    if (!mounted) return;
    if (!opened) {
      _showMessage('Impossible d’ouvrir WhatsApp pour ce client.');
      return;
    }
    final bool confirmed = await _confirm(
      title: 'Message WhatsApp réellement envoyé ?',
      message:
          'IzyTel ne marquera le client comme notifié qu’après votre confirmation.',
      confirmLabel: 'Oui, envoyé',
    );
    if (!confirmed) return;
    await _runAction(
      () => widget.repository.markCustomerNotified(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'Notification WhatsApp tracée dans le dossier.',
    );
  }

  Future<void> _close(SupportRequest request) async {
    final bool confirmed = await _confirm(
      title: 'Fermer le dossier ?',
      message:
          'La demande restera conservée dans l’historique avec toutes ses traces de traitement.',
      confirmLabel: 'Fermer',
    );
    if (!confirmed) return;
    await _runAction(
      () => widget.repository.close(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'Le dossier est fermé et conservé dans l’historique.',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
    VoidCallback? onSuccess,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      onSuccess?.call();
      if (!mounted) return;
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String?> _textDialog({
    required String title,
    required String hint,
    required String actionLabel,
  }) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            autofocus: true,
            maxLength: 1000,
            decoration: InputDecoration(hintText: hint),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final String value = controller.text.trim();
              if (value.length >= 3) Navigator.pop(dialogContext, value);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<RefundCreationDraft?> _refundDialog(
    SupportRequest request,
    QueueOrder order,
  ) async {
    final TextEditingController amountController = TextEditingController(
      text: '${order.amount}',
    );
    final TextEditingController noteController = TextEditingController();
    RefundReason reason = _defaultRefundReason(request.type);
    String? errorMessage;

    final RefundCreationDraft? result = await showDialog<RefundCreationDraft>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Créer un remboursement lié'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${order.reference} • ${order.clientName}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Montant à rembourser',
                          suffixText: 'F',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<RefundReason>(
                        initialValue: reason,
                        decoration: const InputDecoration(
                          labelText: 'Motif du remboursement',
                        ),
                        items: RefundReason.values
                            .map(
                              (RefundReason value) =>
                                  DropdownMenuItem<RefundReason>(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                            )
                            .toList(growable: false),
                        onChanged: (RefundReason? value) {
                          if (value == null) return;
                          setDialogState(() {
                            reason = value;
                            errorMessage = null;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: reason == RefundReason.other
                              ? 'Précision obligatoire'
                              : 'Note de remboursement',
                          hintText:
                              'Ajoutez le contexte utile pour la validation et l’audit.',
                        ),
                      ),
                      if (errorMessage != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: BackofficePalette.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: BackofficePalette.primary.withValues(
                            alpha: .06,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'La création ouvre un dossier « À valider ». La sortie Wave ne sera comptabilisée qu’au moment où le remboursement réel sera marqué effectué avec sa référence Wave.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final int? amount = int.tryParse(
                      amountController.text.trim(),
                    );
                    final String note = noteController.text.trim();
                    if (amount == null ||
                        amount <= 0 ||
                        amount > order.amount) {
                      setDialogState(() {
                        errorMessage =
                            'Le montant doit être compris entre 1 F et ${formatCfa(order.amount)}.';
                      });
                      return;
                    }
                    if (reason == RefundReason.other && note.length < 3) {
                      setDialogState(() {
                        errorMessage = 'Précisez le motif du remboursement.';
                      });
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      RefundCreationDraft(
                        amount: amount,
                        reason: reason,
                        reasonNote: note,
                      ),
                    );
                  },
                  icon: const Icon(Symbols.currency_exchange_rounded),
                  label: const Text('Créer le dossier'),
                ),
              ],
            );
          },
        );
      },
    );
    amountController.dispose();
    noteController.dispose();
    return result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? value = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return value == true;
  }

  Future<QueueOrder?> _loadOrder(SupportRequest request) async {
    try {
      return await widget.orderHistoryRepository.fetchOrderById(
        orderId: request.orderId,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _openDetails(
    SupportRequest request,
    RefundCase? knownRefund,
  ) async {
    final QueueOrder? order = await _loadOrder(request);
    RefundCase? refund = knownRefund;
    if (refund == null) {
      try {
        refund = await widget.refundRepository
            .watchForOrder(orderId: request.orderId)
            .first;
      } on Object {
        refund = null;
      }
    }
    if (!mounted) return;
    final RefundCase? linkedRefund = refund;

    final bool canManage = widget.user.permissions.canProcessSupportRequests;
    final bool canCreateRefund =
        canManage &&
        linkedRefund == null &&
        order != null &&
        order.paymentStatus == OrderPaymentStatus.confirmed &&
        request.status == SupportRequestStatus.inProgress;
    final bool linkedRefundCompleted =
        linkedRefund != null &&
        linkedRefund.isRefundCompleted &&
        linkedRefund.customerWasNotified;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Row(
          children: <Widget>[
            Expanded(child: Text(request.orderReference)),
            BackofficeStatusBadge(
              label: request.status.label,
              color: _statusColor(request.status),
            ),
          ],
        ),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _detail('Motif', request.type.label),
                _detail(
                  'Description',
                  request.description.isEmpty
                      ? 'Aucune description'
                      : request.description,
                ),
                _detail('Créée le', _formatDate(request.createdAt)),
                _detail(
                  'Responsable',
                  request.assignedToName ?? 'Non attribuée',
                ),
                if (order != null) ...<Widget>[
                  const Divider(height: 28),
                  _detail('Client', order.clientName),
                  _detail('WhatsApp', order.clientWhatsappPhone),
                  _detail('Montant commande', formatCfa(order.amount)),
                  _detail('Paiement', _paymentStatusLabel(order.paymentStatus)),
                ],
                if (request.resolutionNote != null)
                  _detail('Résolution', request.resolutionNote!),
                const Divider(height: 28),
                if (linkedRefund == null)
                  _detail('Remboursement lié', 'Aucun dossier')
                else ...<Widget>[
                  _detail('Remboursement lié', linkedRefund.status.label),
                  _detail(
                    'Montant remboursement',
                    formatCfa(linkedRefund.amount),
                  ),
                  _detail('Motif remboursement', linkedRefund.reason.label),
                  if (linkedRefund.refundReference != null)
                    _detail('Référence Wave', linkedRefund.refundReference!),
                ],
                _detail(
                  'Client notifié',
                  linkedRefund != null
                      ? linkedRefund.customerWasNotified
                            ? 'Oui, via le remboursement'
                            : 'Non'
                      : request.customerWasNotified
                      ? 'Oui'
                      : 'Non',
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
          if (canManage && request.status == SupportRequestStatus.newRequest)
            FilledButton.tonal(
              onPressed: () {
                Navigator.pop(dialogContext);
                _takeInCharge(request);
              },
              child: const Text('Prendre en charge'),
            ),
          if (canManage &&
              request.status == SupportRequestStatus.inProgress &&
              linkedRefund == null)
            OutlinedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _resolve(request);
              },
              child: const Text('Résoudre sans remboursement'),
            ),
          if (canCreateRefund)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _createRefund(request, order);
              },
              icon: const Icon(Symbols.currency_exchange_rounded),
              label: const Text('Créer remboursement'),
            ),
          if (linkedRefund != null && widget.onOpenRefunds != null)
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(dialogContext);
                widget.onOpenRefunds!.call(request.orderReference);
              },
              icon: const Icon(Symbols.open_in_new_rounded),
              label: const Text('Voir le remboursement'),
            ),
          if (canManage &&
              request.status == SupportRequestStatus.resolved &&
              linkedRefund == null &&
              !request.customerWasNotified)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _notifyCustomer(request);
              },
              icon: const Icon(Symbols.chat_rounded),
              label: const Text('Notifier sur WhatsApp'),
            ),
          if (canManage &&
              request.status == SupportRequestStatus.resolved &&
              ((linkedRefund == null && request.customerWasNotified) ||
                  linkedRefundCompleted))
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _close(request);
              },
              icon: const Icon(Symbols.archive_rounded),
              label: const Text('Clore le dossier'),
            ),
        ],
      ),
    );
  }

  String? _initialPaymentReference(QueueOrder order) {
    final String direct = order.paymentReference?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final String declared = order.paymentDeclaredReference?.trim() ?? '';
    return declared.isEmpty ? null : declared;
  }

  RefundReason _defaultRefundReason(SupportRequestType type) {
    switch (type) {
      case SupportRequestType.completedButNotReceived:
        return RefundReason.serviceNotReceived;
      case SupportRequestType.transactionFailed:
        return RefundReason.transactionFailed;
      case SupportRequestType.wrongAmount:
        return RefundReason.wrongAmount;
      case SupportRequestType.wrongNumber:
        return RefundReason.wrongNumber;
      case SupportRequestType.paymentNotRecognized:
        return RefundReason.paymentIssue;
      case SupportRequestType.other:
        return RefundReason.other;
    }
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BackofficePalette.faint,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Color _statusColor(SupportRequestStatus status) {
    switch (status) {
      case SupportRequestStatus.newRequest:
        return BackofficePalette.warning;
      case SupportRequestStatus.inProgress:
        return BackofficePalette.primary;
      case SupportRequestStatus.resolved:
        return BackofficePalette.success;
      case SupportRequestStatus.closed:
        return BackofficePalette.muted;
    }
  }

  Color _refundStatusColor(RefundStatus status) {
    switch (status) {
      case RefundStatus.pendingApproval:
        return BackofficePalette.warning;
      case RefundStatus.approved:
        return BackofficePalette.primary;
      case RefundStatus.refunded:
      case RefundStatus.reconciled:
        return BackofficePalette.success;
      case RefundStatus.rejected:
        return BackofficePalette.danger;
    }
  }

  String _paymentStatusLabel(OrderPaymentStatus status) {
    switch (status) {
      case OrderPaymentStatus.notDeclared:
        return 'Non déclaré';
      case OrderPaymentStatus.pending:
        return 'En attente';
      case OrderPaymentStatus.declared:
        return 'Déclaré';
      case OrderPaymentStatus.confirmed:
        return 'Confirmé';
      case OrderPaymentStatus.credit:
        return 'Vente à crédit';
      case OrderPaymentStatus.rejected:
        return 'Rejeté';
      case OrderPaymentStatus.expired:
        return 'Expiré';
    }
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }

  void _showMessage(String message) {
    IzyTelFeedback.show(context, message);
  }
}
