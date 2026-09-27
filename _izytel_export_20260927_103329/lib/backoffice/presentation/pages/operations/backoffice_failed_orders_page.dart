import 'dart:async';

import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:cabine_flow/shared/widgets/izytel_period_filter.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _FailureScope { failed, refundPending, refunded, all }

class BackofficeFailedOrdersPage extends StatefulWidget {
  const BackofficeFailedOrdersPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.historyRepository,
    required this.refundRepository,
    required this.onOpenAssignments,
    required this.onOpenRefunds,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final OrderHistoryRepository historyRepository;
  final RefundRepository refundRepository;
  final ValueChanged<QueueOrder> onOpenAssignments;
  final ValueChanged<String> onOpenRefunds;

  @override
  State<BackofficeFailedOrdersPage> createState() => _BackofficeFailedOrdersPageState();
}

class _BackofficeFailedOrdersPageState extends State<BackofficeFailedOrdersPage> {
  StreamSubscription<List<QueueOrder>>? _subscription;
  StreamSubscription<List<RefundCase>>? _refundSubscription;
  final TextEditingController _searchController = TextEditingController();
  List<QueueOrder> _orders = const <QueueOrder>[];
  Map<String, RefundCase> _refundsByOrder = const <String, RefundCase>{};
  final Set<String> _processing = <String>{};
  bool _loading = true;
  String? _error;
  _FailureScope _scope = _FailureScope.failed;
  MobileNetwork? _network;
  IzyTelPeriodFilterValue _period = const IzyTelPeriodFilterValue();

  @override
  void initState() {
    super.initState();
    _listen();
    _listenRefunds();
  }

  void _listen() {
    _subscription?.cancel();
    _subscription = widget.historyRepository.watchOrderHistory().listen(
      (List<QueueOrder> orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders.where(_isFailureRelated).toList(growable: false);
          _loading = false;
          _error = null;
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Impossible de charger le centre des commandes échouées.';
        });
      },
    );
  }

  void _listenRefunds() {
    _refundSubscription?.cancel();
    _refundSubscription = widget.refundRepository.watchAll().listen(
      (List<RefundCase> refunds) {
        if (!mounted) return;
        setState(() {
          _refundsByOrder = <String, RefundCase>{
            for (final RefundCase refund in refunds) refund.orderId: refund,
          };
        });
      },
      onError: (_) {
        // Le centre des échecs reste lisible si le module remboursements
        // rencontre une panne transitoire. Les actions financières restent
        // alors simplement indisponibles jusqu'au prochain polling réussi.
      },
    );
  }

  RefundCase? _refundFor(QueueOrder order) => _refundsByOrder[order.id];

  bool _isFailureRelated(QueueOrder order) {
    return <QueueOrderStatus>{
      QueueOrderStatus.failed,
      QueueOrderStatus.refundPending,
      QueueOrderStatus.refunded,
      QueueOrderStatus.cancelled,
    }.contains(order.status);
  }

  Future<void> _refresh() async {
    try {
      final List<QueueOrder> orders = await widget.historyRepository.fetchOrderHistory();
      if (!mounted) return;
      setState(() {
        _orders = orders.where(_isFailureRelated).toList(growable: false);
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible d’actualiser les commandes échouées.');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _refundSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Iterable<QueueOrder> get _periodOrders =>
      _orders.where((QueueOrder order) => _period.contains(order.createdAt));

  List<QueueOrder> get _visibleOrders {
    final String query = _searchController.text.trim().toLowerCase();
    Iterable<QueueOrder> result = _periodOrders;
    if (_network != null) {
      result = result.where((QueueOrder order) => order.network == _network);
    }
    result = result.where((QueueOrder order) {
      switch (_scope) {
        case _FailureScope.failed:
          return order.status == QueueOrderStatus.failed || order.status == QueueOrderStatus.cancelled;
        case _FailureScope.refundPending:
          return order.status == QueueOrderStatus.refundPending;
        case _FailureScope.refunded:
          return order.status == QueueOrderStatus.refunded;
        case _FailureScope.all:
          return true;
      }
    });
    if (query.isNotEmpty) {
      result = result.where((QueueOrder order) {
        final String haystack = <String>[
          order.reference,
          order.clientName,
          order.beneficiaryPhone,
          order.assignedAgentName ?? '',
          failureReasonLabel(order.failureReason),
          order.observation ?? '',
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }
    return result.toList(growable: false);
  }

  int get _failedCount => _periodOrders.where((QueueOrder order) => order.status == QueueOrderStatus.failed || order.status == QueueOrderStatus.cancelled).length;
  int get _refundPendingCount => _periodOrders.where((QueueOrder order) => order.status == QueueOrderStatus.refundPending).length;
  int get _refundedCount => _periodOrders.where((QueueOrder order) => order.status == QueueOrderStatus.refunded).length;
  int get _failedAmount => _periodOrders.where((QueueOrder order) => order.status == QueueOrderStatus.failed).fold<int>(0, (int sum, QueueOrder order) => sum + order.amount);

  Future<QueueOrder?> _freshOrderForTreatment(QueueOrder order) async {
    try {
      final QueueOrder fresh = await widget.historyRepository.fetchOrderById(
        orderId: order.id,
      );
      if (fresh.status != QueueOrderStatus.failed) {
        if (mounted) {
          IzyTelFeedback.show(
            context,
            'Cette commande a déjà évolué. Aucun remboursement ni réaffectation supplémentaire ne sera lancé.',
            tone: IzyTelFeedbackTone.warning,
          );
        }
        return null;
      }
      return fresh;
    } catch (error) {
      if (mounted) {
        IzyTelFeedback.error(
          context,
          'Impossible de relire la commande avant le traitement financier : ${error.toString()}',
        );
      }
      return null;
    }
  }

  Future<void> _prepareReassignment(QueueOrder order) async {
    if (_processing.contains(order.id)) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Préparer la réaffectation ?'),
          content: Text(
            'La commande ${order.reference} sera remise dans la file payée et marquée pour une affectation manuelle. Son ancien échec restera traçable dans l’historique.',
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Symbols.restart_alt_rounded),
              label: const Text('Préparer'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final QueueOrder? fresh = await _freshOrderForTreatment(order);
    if (fresh == null || !mounted) return;

    setState(() => _processing.add(fresh.id));
    try {
      final QueueOrder reopened = await widget.ordersRepository.prepareFailedOrderForReassignment(orderId: fresh.id);
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        '${fresh.reference} est prête pour une nouvelle affectation.',
      );
      widget.onOpenAssignments(reopened);
    } catch (error) {
      if (!mounted) return;
      final String raw = error.toString().replaceFirst('Bad state: ', '');
      IzyTelFeedback.error(
        context,
        raw.isEmpty ? 'Impossible de préparer la réaffectation.' : raw,
      );
    } finally {
      if (mounted) setState(() => _processing.remove(fresh.id));
    }
  }

  Future<void> _chooseTreatment(QueueOrder order) async {
    final RefundCase? knownRefund = _refundFor(order);
    if (knownRefund != null && knownRefund.status != RefundStatus.rejected) {
      widget.onOpenRefunds(order.reference);
      return;
    }

    final QueueOrder? fresh = await _freshOrderForTreatment(order);
    if (fresh == null || !mounted) return;
    final RefundCase? existing = _refundFor(fresh);

    final bool canReassign = fresh.status == QueueOrderStatus.failed &&
        fresh.isFundedForProcessing &&
        (existing == null || existing.status == RefundStatus.rejected);
    final bool canRefund = fresh.status == QueueOrderStatus.failed &&
        fresh.paymentStatus == OrderPaymentStatus.confirmed &&
        existing == null;

    if (canReassign && !canRefund) {
      await _prepareReassignment(fresh);
      return;
    }
    if (!canReassign && canRefund) {
      await _createRefund(fresh);
      return;
    }
    if (!canReassign && !canRefund) return;

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Traiter ${fresh.reference}'),
        content: const Text(
          'Choisissez la suite adaptée après vos vérifications. Une réaffectation remet la commande en circulation ; un remboursement ouvre un dossier financier distinct.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'reassign'),
            icon: const Icon(Symbols.restart_alt_rounded),
            label: const Text('Réaffecter'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, 'refund'),
            icon: const Icon(Symbols.currency_exchange_rounded),
            label: const Text('Rembourser'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'reassign') {
      await _prepareReassignment(fresh);
    } else if (choice == 'refund') {
      await _createRefund(fresh);
    }
  }

  Future<void> _createRefund(QueueOrder order) async {
    final QueueOrder? fresh = await _freshOrderForTreatment(order);
    if (fresh == null || !mounted) return;
    if (fresh.paymentStatus != OrderPaymentStatus.confirmed) {
      IzyTelFeedback.show(
        context,
        'Cette commande n’a pas de paiement Wave confirmé à rembourser.',
        tone: IzyTelFeedbackTone.warning,
      );
      return;
    }
    if (_refundFor(fresh) != null) {
      widget.onOpenRefunds(fresh.reference);
      return;
    }

    final RefundCreationDraft? draft = await _refundDraft(fresh);
    if (draft == null || _processing.contains(fresh.id)) return;
    setState(() => _processing.add(fresh.id));
    try {
      await widget.refundRepository.create(
        request: RefundCreationRequest(
          orderId: fresh.id,
          orderReference: fresh.reference,
          origin: RefundOrigin.failedOrder,
          customerAuthUid: fresh.customerAuthUid,
          clientName: fresh.clientName,
          clientWhatsappPhone: fresh.clientWhatsappPhone,
          originalAmount: fresh.amount,
          amount: draft.amount,
          reason: draft.reason,
          reasonNote: draft.reasonNote,
          paymentChannel: 'wave',
          originalPaymentReference: _initialPaymentReference(fresh),
        ),
        staffId: widget.user.id,
        staffName: widget.user.name,
      );
      if (!mounted) return;
      IzyTelFeedback.success(
        context,
        'Dossier de remboursement créé pour ${fresh.reference}.',
      );
      widget.onOpenRefunds(fresh.reference);
    } catch (error) {
      if (!mounted) return;
      IzyTelFeedback.error(context, error.toString());
    } finally {
      if (mounted) setState(() => _processing.remove(fresh.id));
    }
  }

  Future<RefundCreationDraft?> _refundDraft(QueueOrder order) async {
    final TextEditingController amountController = TextEditingController(
      text: order.amount.toString(),
    );
    final TextEditingController noteController = TextEditingController(
      text: <String>[
        failureReasonLabel(order.failureReason),
        if (order.observation?.trim().isNotEmpty == true) order.observation!.trim(),
      ].join(' • '),
    );
    RefundReason reason = RefundReason.transactionFailed;
    String? validation;
    final RefundCreationDraft? result = await showDialog<RefundCreationDraft>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) => AlertDialog(
          title: Text('Rembourser ${order.reference}'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '${order.clientName} • paiement confirmé • ${formatCfa(order.amount)}',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant à rembourser',
                    suffixText: 'F CFA',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RefundReason>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: 'Motif'),
                  items: RefundReason.values
                      .map(
                        (RefundReason value) => DropdownMenuItem<RefundReason>(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (RefundReason? value) {
                    if (value != null) setDialogState(() => reason = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Note / vérification',
                  ),
                ),
                if (validation != null)
                  Text(
                    validation!,
                    style: const TextStyle(color: BackofficePalette.danger),
                  ),
              ],
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
                  amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                );
                final String note = noteController.text.trim();
                if (amount == null || amount <= 0 || amount > order.amount) {
                  setDialogState(
                    () => validation =
                        'Le montant doit être compris entre 1 F et ${formatCfa(order.amount)}.',
                  );
                  return;
                }
                if (reason == RefundReason.other && note.length < 3) {
                  setDialogState(
                    () => validation = 'Précisez le motif du remboursement.',
                  );
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
              label: const Text('Créer le remboursement'),
            ),
          ],
        ),
      ),
    );
    amountController.dispose();
    noteController.dispose();
    return result;
  }

  String? _initialPaymentReference(QueueOrder order) {
    final String direct = order.paymentReference?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final String declared = order.paymentDeclaredReference?.trim() ?? '';
    return declared.isEmpty ? null : declared;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BackofficePageIntro(
          eyebrow: 'Opérations / Alertes',
          title: 'Commandes échouées',
          description:
              'Centralise les échecs opérationnels et laisse l’administrateur décider, après vérification, entre une nouvelle affectation et un remboursement lorsqu’un paiement Wave a réellement été confirmé.',
          icon: Symbols.error_rounded,
          trailing: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Symbols.refresh_rounded),
            label: const Text('Actualiser'),
          ),
        ),
        const SizedBox(height: 16),
        _FailureMetrics(
          failed: _failedCount,
          failedAmount: _failedAmount,
          pending: _refundPendingCount,
          refunded: _refundedCount,
        ),
        const SizedBox(height: 12),
        _filters(),
        const SizedBox(height: 14),
        if (_error != null) ...<Widget>[
          BackofficeInlineError(message: _error!, onRetry: _refresh),
          const SizedBox(height: 14),
        ],
        if (_loading && _orders.isEmpty)
          const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()))
        else if (_visibleOrders.isEmpty)
          const BackofficeEmptyState(
            icon: Symbols.task_alt_rounded,
            title: 'Aucune commande dans cette vue',
            message: 'Les incidents correspondant à ce filtre apparaîtront ici.',
          )
        else
          _FailedOrdersList(
            orders: _visibleOrders,
            processing: _processing,
            refundsByOrder: _refundsByOrder,
            onOpen: (QueueOrder order) => showBackofficeOrderDetails(context, order),
            onTreat: _chooseTreatment,
            onOpenRefund: (QueueOrder order) => widget.onOpenRefunds(order.reference),
          ),
      ],
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 820;
              final Widget search = TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Référence, client, motif, observation ou agent',
                  prefixIcon: Icon(Symbols.search_rounded),
                ),
              );
              final Widget scope = DropdownButtonFormField<_FailureScope>(
                initialValue: _scope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vue'),
                items: const <DropdownMenuItem<_FailureScope>>[
                  DropdownMenuItem(value: _FailureScope.failed, child: Text('Échouées')),
                  DropdownMenuItem(value: _FailureScope.refundPending, child: Text('Remboursement')),
                  DropdownMenuItem(value: _FailureScope.refunded, child: Text('Remboursées')),
                  DropdownMenuItem(value: _FailureScope.all, child: Text('Toutes')),
                ],
                onChanged: (_FailureScope? value) {
                  if (value != null) setState(() => _scope = value);
                },
              );
              final Widget network = DropdownButtonFormField<MobileNetwork?>(
                initialValue: _network,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Réseau'),
                items: const <DropdownMenuItem<MobileNetwork?>>[
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: MobileNetwork.orange, child: Text('Orange')),
                  DropdownMenuItem(value: MobileNetwork.mtn, child: Text('MTN')),
                  DropdownMenuItem(value: MobileNetwork.moov, child: Text('Moov Africa')),
                ],
                onChanged: (MobileNetwork? value) => setState(() => _network = value),
              );
              if (compact) {
                return Column(
                  children: <Widget>[
                    search,
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(child: scope),
                        const SizedBox(width: 10),
                        Expanded(child: network),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(flex: 5, child: search),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: scope),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: network),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          IzyTelPeriodFilterBar(
            value: _period,
            onChanged: (IzyTelPeriodFilterValue value) {
              setState(() => _period = value);
            },
            compact: MediaQuery.sizeOf(context).width < 760,
            calendarHelpText: 'Retrouver d’anciennes commandes échouées',
          ),
        ],
      ),
    );
  }
}

class _FailureMetrics extends StatelessWidget {
  const _FailureMetrics({required this.failed, required this.failedAmount, required this.pending, required this.refunded});

  final int failed;
  final int failedAmount;
  final int pending;
  final int refunded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : constraints.maxWidth >= 700 ? 2 : 1;
        final double gap = 10;
        final double width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'Échouées', value: '$failed', caption: 'incidents à traiter', icon: Symbols.error_rounded, emphasis: BackofficePalette.danger),
          BackofficeMetricCard(label: 'Montant exposé', value: formatCfa(failedAmount), caption: 'sur les échecs', icon: Symbols.payments_rounded, emphasis: BackofficePalette.warning),
          BackofficeMetricCard(label: 'Remboursement', value: '$pending', caption: 'dossiers en cours', icon: Symbols.currency_exchange_rounded, emphasis: BackofficePalette.primaryStrong),
          BackofficeMetricCard(label: 'Remboursées', value: '$refunded', caption: 'dossiers clôturés', icon: Symbols.task_alt_rounded, emphasis: BackofficePalette.success),
        ];
        return Wrap(spacing: gap, runSpacing: gap, children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList());
      },
    );
  }
}

class _FailedOrdersList extends StatelessWidget {
  const _FailedOrdersList({required this.orders, required this.processing, required this.refundsByOrder, required this.onOpen, required this.onTreat, required this.onOpenRefund});

  final List<QueueOrder> orders;
  final Set<String> processing;
  final Map<String, RefundCase> refundsByOrder;
  final ValueChanged<QueueOrder> onOpen;
  final ValueChanged<QueueOrder> onTreat;
  final ValueChanged<QueueOrder> onOpenRefund;

  RefundCase? _refundFor(QueueOrder order) => refundsByOrder[order.id];

  bool _canReassign(QueueOrder order) {
    final RefundCase? refund = _refundFor(order);
    return order.status == QueueOrderStatus.failed &&
        order.isFundedForProcessing &&
        (refund == null || refund.status == RefundStatus.rejected);
  }

  bool _canRefund(QueueOrder order) {
    return order.status == QueueOrderStatus.failed &&
        order.paymentStatus == OrderPaymentStatus.confirmed &&
        _refundFor(order) == null;
  }

  bool _hasOpenOrCompletedRefund(QueueOrder order) {
    final RefundCase? refund = _refundFor(order);
    return refund != null && refund.status != RefundStatus.rejected;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 920) {
          return Column(
            children: orders.map((QueueOrder order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: backofficePanelDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(child: Text(order.reference, style: Theme.of(context).textTheme.titleMedium)),
                          BackofficeNetworkBadge(network: order.network),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${order.clientName} • ${formatCfa(order.amount)}'),
                      const SizedBox(height: 10),
                      Text(failureReasonLabel(order.failureReason), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BackofficePalette.danger, fontWeight: FontWeight.w700)),
                      if (order.observation?.trim().isNotEmpty == true) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(order.observation!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          OutlinedButton.icon(onPressed: () => onOpen(order), icon: const Icon(Symbols.visibility_rounded, size: 18), label: const Text('Détails')),
                          const SizedBox(width: 8),
                          if (_hasOpenOrCompletedRefund(order))
                            FilledButton.tonalIcon(
                              onPressed: () => onOpenRefund(order),
                              icon: const Icon(Symbols.currency_exchange_rounded, size: 18),
                              label: const Text('Voir remboursement'),
                            )
                          else if (_canReassign(order) || _canRefund(order))
                            FilledButton.icon(
                              onPressed: processing.contains(order.id)
                                  ? null
                                  : () => onTreat(order),
                              icon: processing.contains(order.id)
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Symbols.rule_rounded, size: 18),
                              label: Text(
                                _canReassign(order) && _canRefund(order)
                                    ? 'Traiter'
                                    : _canRefund(order)
                                    ? 'Rembourser'
                                    : 'Réaffecter',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        }
        return BackofficeDesktopTable(
          columns: const <BackofficeTableColumnSpec>[
            BackofficeTableColumnSpec(label: 'ÉTAT', flex: 2),
            BackofficeTableColumnSpec(label: 'COMMANDE', flex: 2),
            BackofficeTableColumnSpec(label: 'CLIENT', flex: 2),
            BackofficeTableColumnSpec(
              label: 'MONTANT',
              flex: 1,
              alignment: Alignment.centerRight,
            ),
            BackofficeTableColumnSpec(label: 'INCIDENT / AGENT', flex: 3),
            BackofficeTableColumnSpec(
              label: 'ACTION',
              flex: 2,
              alignment: Alignment.centerRight,
            ),
          ],
          rows: orders.map((QueueOrder order) {
            final bool reassignable = _canReassign(order);
            final bool refundable = _canRefund(order);
            final bool hasRefund = _hasOpenOrCompletedRefund(order);
            final bool refundPending = order.status == QueueOrderStatus.refundPending;
            final bool refunded = order.status == QueueOrderStatus.refunded;
            final Color stateColor = reassignable
                ? BackofficePalette.danger
                : refundPending
                ? BackofficePalette.warning
                : refunded
                ? BackofficePalette.success
                : orderStatusColor(order.status);
            final String stateLabel = reassignable
                ? 'À traiter'
                : refundPending
                ? 'Remboursement'
                : refunded
                ? 'Remboursée'
                : orderStatusLabel(order.status);
            return BackofficeDesktopTableRow(
              onTap: () => onOpen(order),
              backgroundColor: reassignable
                  ? BackofficePalette.danger.withValues(alpha: .035)
                  : refundPending
                  ? BackofficePalette.warning.withValues(alpha: .035)
                  : null,
              accentColor: reassignable
                  ? BackofficePalette.danger
                  : refundPending
                  ? BackofficePalette.warning
                  : null,
              cells: <BackofficeTableCellSpec>[
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeStatusBadge(
                    label: stateLabel,
                    color: stateColor,
                    icon: reassignable
                        ? Symbols.error_rounded
                        : refundPending
                        ? Symbols.currency_exchange_rounded
                        : refunded
                        ? Symbols.task_alt_rounded
                        : orderStatusIcon(order.status),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      BackofficeNetworkBadge(network: order.network),
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Text(
                    order.clientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 1,
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatCfa(order.amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        failureReasonLabel(order.failureReason),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: BackofficePalette.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.assignedAgentName?.trim().isNotEmpty == true
                            ? order.assignedAgentName!
                            : 'Agent non renseigné',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BackofficePalette.faint,
                        ),
                      ),
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  alignment: Alignment.centerRight,
                  child: hasRefund
                      ? FilledButton.tonalIcon(
                          onPressed: () => onOpenRefund(order),
                          icon: const Icon(Symbols.currency_exchange_rounded, size: 18),
                          label: const Text('Voir remboursement'),
                        )
                      : reassignable || refundable
                      ? FilledButton.tonalIcon(
                          onPressed: processing.contains(order.id)
                              ? null
                              : () => onTreat(order),
                          icon: processing.contains(order.id)
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  reassignable && refundable
                                      ? Symbols.rule_rounded
                                      : refundable
                                      ? Symbols.currency_exchange_rounded
                                      : Symbols.restart_alt_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            reassignable && refundable
                                ? 'Traiter'
                                : refundable
                                ? 'Rembourser'
                                : 'Réaffecter',
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => onOpen(order),
                          icon: const Icon(Symbols.visibility_rounded, size: 18),
                          label: const Text('Détails'),
                        ),
                ),
              ],
            );
          }).toList(growable: false),
        );
      },
    );
  }
}
