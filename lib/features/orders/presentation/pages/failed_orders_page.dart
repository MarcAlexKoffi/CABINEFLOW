import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/agent_assignment_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/features/refunds/data/repositories/operational_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/refunds/presentation/pages/refund_management_page.dart';
import 'package:cabine_flow/features/refunds/presentation/widgets/refund_creation_sheet.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FailedOrdersPage extends StatefulWidget {
  const FailedOrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.orderHistoryRepository,
    required this.agentRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final OrderHistoryRepository orderHistoryRepository;
  final AgentRepository agentRepository;

  @override
  State<FailedOrdersPage> createState() => _FailedOrdersPageState();
}

class _FailedOrdersPageState extends State<FailedOrdersPage> {
  late final RefundRepository _refundRepository;
  late Stream<List<QueueOrder>> _orderHistoryStream;
  late Stream<List<RefundCase>> _refundStream;
  String? _busyOrderId;

  @override
  void initState() {
    super.initState();
    _refundRepository = createOperationalRefundRepository();
    _orderHistoryStream = widget.orderHistoryRepository.watchOrderHistory();
    _refundStream = _refundRepository.watchAll();
  }

  void _retryOrderHistory() {
    setState(() {
      _orderHistoryStream = widget.orderHistoryRepository.watchOrderHistory();
    });
  }

  Future<void> _openOrder(QueueOrder order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OrderDetailPage(
          user: widget.user,
          initialOrder: order,
          ordersRepository: widget.orderHistoryRepository,
          onBack: () => Navigator.of(context).pop(),
          onOpenCustomerHistory: (_) {},
        ),
      ),
    );
  }

  Future<void> _reassign(QueueOrder order) async {
    if (_busyOrderId != null) return;
    setState(() => _busyOrderId = order.id);
    try {
      final QueueOrder reopened = await widget.ordersRepository
          .prepareFailedOrderForReassignment(orderId: order.id);
      if (!mounted) return;
      final QueueOrder? assigned = await Navigator.of(context).push<QueueOrder>(
        MaterialPageRoute<QueueOrder>(
          builder: (BuildContext context) => AgentAssignmentPage(
            user: widget.user,
            order: reopened,
            agentRepository: widget.agentRepository,
            ordersRepository: widget.ordersRepository,
          ),
        ),
      );
      if (!mounted) return;
      if (assigned != null) {
        IzyTelFeedback.success(
          context,
          'La commande ${order.reference} a été réaffectée.',
        );
      } else {
        IzyTelFeedback.show(
          context,
          'La commande est prête pour une nouvelle affectation.',
          tone: IzyTelFeedbackTone.warning,
        );
      }
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        _friendlyError(error, 'Impossible de préparer la réaffectation.'),
      );
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _refund(QueueOrder order, RefundCase? existing) async {
    if (existing != null) {
      await _openRefund(existing);
      return;
    }
    if (order.paymentStatus != OrderPaymentStatus.confirmed) {
      IzyTelFeedback.show(
        context,
        order.isCreditSale
            ? 'Cette commande est à crédit : aucun paiement Wave confirmé n’est à rembourser.'
            : 'Le remboursement Wave exige un paiement confirmé.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }

    final DateTime now = DateTime.now();
    final String failureText = failureReasonLabel(order.failureReason);
    final SupportRequest syntheticRequest = SupportRequest(
      id: 'failed_${order.id}',
      orderId: order.id,
      orderReference: order.reference,
      customerAuthUid: order.customerAuthUid ?? '',
      type: SupportRequestType.transactionFailed,
      description: order.observation?.trim().isNotEmpty == true
          ? '$failureText — ${order.observation!.trim()}'
          : failureText,
      status: SupportRequestStatus.inProgress,
      createdAt: order.completedAt ?? now,
      updatedAt: now,
      assignedTo: widget.user.id,
      assignedToName: widget.user.name,
      inProgressAt: now,
    );

    final RefundCreationDraft? draft =
        await showModalBottomSheet<RefundCreationDraft>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withAlpha(120),
          builder: (BuildContext context) => RefundCreationSheet(
            order: order,
            supportRequest: syntheticRequest,
          ),
        );
    if (draft == null || !mounted) return;

    setState(() => _busyOrderId = order.id);
    try {
      final RefundCase refund = await _refundRepository.create(
        request: RefundCreationRequest(
          orderId: order.id,
          orderReference: order.reference,
          origin: RefundOrigin.failedOrder,
          supportRequestId: syntheticRequest.id,
          supportRequestType: syntheticRequest.type.storageValue,
          supportRequestDescription: syntheticRequest.description,
          customerAuthUid: order.customerAuthUid,
          clientName: order.clientName,
          clientWhatsappPhone: order.clientWhatsappPhone,
          originalAmount: order.amount,
          amount: draft.amount,
          reason: draft.reason,
          reasonNote: draft.reasonNote,
          paymentChannel: 'wave',
          originalPaymentReference: order.paymentReference,
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      );
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Dossier de remboursement créé pour ${order.reference}.',
      );
      await _openRefund(refund);
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(
        context,
        _friendlyError(error, 'Impossible de créer le remboursement.'),
      );
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _openRefund(RefundCase refund) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RefundDetailPage(
          user: widget.user,
          initialRefund: refund,
          repository: _refundRepository,
          orderHistoryRepository: widget.orderHistoryRepository,
        ),
      ),
    );
  }

  String _friendlyError(Object error, String fallback) {
    final String raw = error.toString();
    if (raw.startsWith('Bad state: ')) return raw.substring(11);
    if (raw.startsWith('StateError: ')) return raw.substring(12);
    if (error is PostgrestException) {
      final String normalized = '${error.code ?? ''} ${error.message}'.toLowerCase();
      if (normalized.contains('42501') || normalized.contains('permission')) {
        return 'Supabase refuse cette action pour l’état actuel de la commande.';
      }
      if (normalized.contains('order_not_failed')) {
        return 'Cette commande n’est plus en échec. Actualise la liste.';
      }
      if (normalized.contains('order_not_synced')) {
        return 'Cette commande n’est pas encore disponible dans le registre Supabase.';
      }
    }
    if (raw.contains('permission-denied')) {
      return 'L’accès au dossier de remboursement est momentanément refusé.';
    }
    return fallback;
  }

  String _friendlyHistoryError(Object error) {
    final String raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied')) {
      return 'La source historique Firebase n’est pas accessible. Les commandes opérationnelles doivent continuer à venir de Supabase.';
    }
    return _friendlyError(
      error,
      'Impossible de charger les commandes échouées depuis Supabase.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Commandes échouées',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: StreamBuilder<List<QueueOrder>>(
        stream: _orderHistoryStream,
        builder:
            (BuildContext context, AsyncSnapshot<List<QueueOrder>> ordersSnap) {
              return StreamBuilder<List<RefundCase>>(
                stream: _refundStream,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<RefundCase>> refundSnap,
                    ) {
                      if (ordersSnap.hasError && ordersSnap.data == null) {
                        return _FailedOrdersLoadError(
                          message: _friendlyHistoryError(ordersSnap.error!),
                          onRetry: _retryOrderHistory,
                        );
                      }

                      final Map<String, RefundCase> refunds =
                          <String, RefundCase>{
                            for (final RefundCase refund
                                in refundSnap.data ?? const <RefundCase>[])
                              refund.orderId: refund,
                          };
                      final List<QueueOrder> failed =
                          (ordersSnap.data ?? const <QueueOrder>[])
                              .where((QueueOrder order) {
                                if (order.status != QueueOrderStatus.failed) {
                                  return false;
                                }
                                final RefundCase? refund = refunds[order.id];
                                return refund == null ||
                                    (refund.status != RefundStatus.refunded &&
                                        refund.status !=
                                            RefundStatus.reconciled);
                              })
                              .toList(growable: false)
                            ..sort(
                              (QueueOrder a, QueueOrder b) =>
                                  (b.completedAt ?? b.createdAt).compareTo(
                                    a.completedAt ?? a.createdAt,
                                  ),
                            );

                      if (ordersSnap.connectionState ==
                              ConnectionState.waiting &&
                          failed.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (failed.isEmpty) {
                        return const _EmptyFailedOrders();
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                        children: <Widget>[
                          if (refundSnap.hasError) ...<Widget>[
                            const _RefundStatusWarning(),
                            const SizedBox(height: 12),
                          ],
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: IzyTelColors.errorSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Symbols.error_rounded,
                                  color: IzyTelColors.error,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Traite chaque échec : réaffecte la commande si le problème est temporaire, ou lance un remboursement si le paiement Wave doit être restitué.',
                                    style: TextStyle(
                                      color: IzyTelColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...failed.map((QueueOrder order) {
                            final RefundCase? refund = refunds[order.id];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FailedOrderCard(
                                order: order,
                                refund: refund,
                                busy: _busyOrderId == order.id,
                                onOpen: () => _openOrder(order),
                                onReassign: () => _reassign(order),
                                onRefund: () => _refund(order, refund),
                              ),
                            );
                          }),
                        ],
                      );
                    },
              );
            },
      ),
    );
  }
}

class _FailedOrdersLoadError extends StatelessWidget {
  const _FailedOrdersLoadError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Symbols.cloud_off_rounded,
                size: 34,
                color: IzyTelColors.error,
              ),
              const SizedBox(height: 12),
              const Text(
                'Chargement impossible',
                style: TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: IzyTelColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundStatusWarning extends StatelessWidget {
  const _RefundStatusWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Symbols.info_rounded, color: IzyTelColors.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Les commandes échouées sont disponibles. Le statut des remboursements est en cours de resynchronisation.',
              style: TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedOrderCard extends StatelessWidget {
  const _FailedOrderCard({
    required this.order,
    required this.refund,
    required this.busy,
    required this.onOpen,
    required this.onReassign,
    required this.onRefund,
  });

  final QueueOrder order;
  final RefundCase? refund;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onReassign;
  final VoidCallback onRefund;

  bool get _preferReassign => switch (order.failureReason) {
    OrderFailureReason.networkUnavailable ||
    OrderFailureReason.offerUnavailable ||
    OrderFailureReason.insufficientBalance ||
    OrderFailureReason.technicalError => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final String reason = failureReasonLabel(order.failureReason);
    final bool canRefund = order.paymentStatus == OrderPaymentStatus.confirmed;
    final bool refundInProgress =
        refund != null &&
        refund!.status != RefundStatus.rejected &&
        refund!.status != RefundStatus.refunded &&
        refund!.status != RefundStatus.reconciled;
    final String recommendation = refundInProgress
        ? 'Remboursement en cours — termine ce dossier avant toute réaffectation'
        : _preferReassign
        ? 'Réaffectation conseillée'
        : canRefund
        ? 'Vérifier puis rembourser si nécessaire'
        : 'Vérification manuelle requise';

    return Material(
      color: IzyTelColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: IzyTelColors.outline),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: IzyTelColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: IzyTelColors.errorSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Symbols.error_rounded,
                      color: IzyTelColors.error,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.offerLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: IzyTelColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.reference,
                          style: const TextStyle(
                            color: IzyTelColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${order.amount} F',
                    style: const TextStyle(
                      color: IzyTelColors.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _Line(
                label: 'Motif',
                value: reason,
                valueColor: IzyTelColors.error,
              ),
              if (order.observation?.trim().isNotEmpty == true)
                _Line(label: 'Observation', value: order.observation!.trim()),
              _Line(
                label: 'Agent',
                value: order.assignedAgentName ?? 'Non renseigné',
              ),
              _Line(label: 'Action suggérée', value: recommendation),
              if (refund != null)
                _Line(
                  label: 'Remboursement',
                  value: refund!.status.label,
                  valueColor: IzyTelColors.warning,
                ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy || refundInProgress ? null : onReassign,
                      icon: const Icon(Symbols.swap_horiz_rounded, size: 19),
                      label: const Text('Réaffecter'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: IzyTelColors.primary,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onRefund,
                      icon: busy
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Symbols.currency_exchange_rounded,
                              size: 19,
                            ),
                      label: Text(
                        refund == null ? 'Rembourser' : 'Voir dossier',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: canRefund || refund != null
                            ? IzyTelColors.primary
                            : IzyTelColors.textMuted,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: IzyTelColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? IzyTelColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFailedOrders extends StatelessWidget {
  const _EmptyFailedOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(
              Symbols.task_alt_rounded,
              size: 52,
              color: IzyTelColors.success,
            ),
            SizedBox(height: 12),
            Text(
              'Aucune commande échouée à traiter',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: IzyTelColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Les nouveaux échecs apparaîtront ici automatiquement.',
              textAlign: TextAlign.center,
              style: TextStyle(color: IzyTelColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
