import 'package:cabine_flow/backoffice/presentation/services/backoffice_whatsapp_service.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel_period_filter.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _RefundScope { all, pending, approved, refunded, reconciled, rejected }

class BackofficeRefundsPage extends StatefulWidget {
  const BackofficeRefundsPage({
    super.key,
    required this.user,
    required this.repository,
    this.orderHistoryRepository,
    this.supportRepository,
    this.onOpenSupportRequests,
    this.initialOrderReference,
  });

  final AppUser user;
  final RefundRepository repository;
  final OrderHistoryRepository? orderHistoryRepository;
  final SupportRequestRepository? supportRepository;
  final ValueChanged<String>? onOpenSupportRequests;
  final String? initialOrderReference;

  @override
  State<BackofficeRefundsPage> createState() => _BackofficeRefundsPageState();
}

class _BackofficeRefundsPageState extends State<BackofficeRefundsPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<RefundCase>> _stream;
  _RefundScope _scope = _RefundScope.pending;
  String _query = '';
  bool _submitting = false;
  IzyTelPeriodFilterValue _period = const IzyTelPeriodFilterValue();

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.watchAll();
    final String initialReference = widget.initialOrderReference?.trim() ?? '';
    if (initialReference.isNotEmpty) {
      _scope = _RefundScope.all;
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
    return StreamBuilder<List<RefundCase>>(
      stream: _stream,
      builder: (BuildContext context, AsyncSnapshot<List<RefundCase>> snapshot) {
        if (snapshot.hasError) {
          return const BackofficeEmptyState(
            icon: Symbols.cloud_off_rounded,
            title: 'Remboursements indisponibles',
            message: 'Les dossiers de remboursement ne peuvent pas être chargés pour le moment.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<RefundCase> all = snapshot.data!;
        final List<RefundCase> periodItems = all
            .where((RefundCase item) => _period.contains(item.requestedAt))
            .toList(growable: false);
        final int pending = periodItems.where((RefundCase item) => item.status == RefundStatus.pendingApproval).length;
        final int approved = periodItems.where((RefundCase item) => item.status == RefundStatus.approved).length;
        final int completed = periodItems.where((RefundCase item) => item.isRefundCompleted).length;
        final int exposure = periodItems.where((RefundCase item) => item.status.isActive).fold<int>(0, (int total, RefundCase item) => total + item.amount);
        final List<RefundCase> visible = _filtered(periodItems);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BackofficePageIntro(
              eyebrow: 'Clients / Remboursements',
              title: 'Centre des remboursements',
              description: 'Crée, valide, exécute et rapproche les remboursements IzyTel, qu’ils proviennent d’une demande client, d’une commande échouée ou d’un traitement manuel. La sortie Wave est comptabilisée uniquement lorsque le remboursement réel est marqué effectué.',
              icon: Symbols.currency_exchange_rounded,
              trailing: widget.user.permissions.canManageRefunds &&
                      widget.orderHistoryRepository != null
                  ? FilledButton.icon(
                      onPressed: _submitting ? null : () => _createManualRefund(all),
                      icon: const Icon(Symbols.add_rounded),
                      label: const Text('Nouveau remboursement'),
                    )
                  : null,
            ),
            const SizedBox(height: 18),
            _metrics(pending: pending, approved: approved, completed: completed, exposure: exposure),
            const SizedBox(height: 14),
            _financeNotice(),
            const SizedBox(height: 14),
            _filters(all: all, visibleCount: visible.length),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              const BackofficeEmptyState(
                icon: Symbols.currency_exchange_rounded,
                title: 'Aucun remboursement',
                message: 'Les dossiers correspondant aux filtres actifs apparaîtront ici.',
              )
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  if (constraints.maxWidth >= 920) return _desktopTable(visible);
                  return Column(
                    children: visible.map((RefundCase refund) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _mobileCard(refund),
                    )).toList(growable: false),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _financeNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BackofficePalette.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BackofficePalette.primary.withValues(alpha: .18),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Symbols.account_balance_wallet_rounded,
            color: BackofficePalette.primary,
            fill: 1,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Un dossier créé ou approuvé ne réduit pas encore la Caisse Wave. La déduction devient effective uniquement après « Marquer remboursé » avec une référence Wave, afin que le solde théorique corresponde à une vraie sortie d’argent.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _metrics({required int pending, required int approved, required int completed, required int exposure}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920 ? 4 : 2;
        final double gap = 10;
        final double width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(label: 'À valider', value: '$pending', caption: 'dossiers en attente', icon: Symbols.fact_check_rounded, emphasis: BackofficePalette.warning),
          BackofficeMetricCard(label: 'À effectuer', value: '$approved', caption: 'remboursements approuvés', icon: Symbols.payments_rounded),
          BackofficeMetricCard(label: 'Finalisés', value: '$completed', caption: 'remboursés / rapprochés', icon: Symbols.task_alt_rounded, emphasis: BackofficePalette.success),
          BackofficeMetricCard(label: 'Exposition', value: formatCfa(exposure), caption: 'montant encore engagé', icon: Symbols.account_balance_wallet_rounded, emphasis: BackofficePalette.cyan),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }

  Widget _filters({required List<RefundCase> all, required int visibleCount}) {
    final List<RefundCase> periodItems = all
        .where((RefundCase item) => _period.contains(item.requestedAt))
        .toList(growable: false);
    int count(RefundStatus status) => periodItems
        .where((RefundCase item) => item.status == status)
        .length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget search = TextField(
                controller: _searchController,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Référence, client, téléphone ou motif',
                  prefixIcon: const Icon(Symbols.search_rounded),
                  suffixIcon: _query.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          onPressed: _clearSearch,
                          icon: const Icon(Symbols.close_rounded),
                        ),
                ),
              );
              final Widget scope = DropdownButtonFormField<_RefundScope>(
                initialValue: _scope,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vue'),
                items: <DropdownMenuItem<_RefundScope>>[
                  DropdownMenuItem(value: _RefundScope.all, child: Text('Tous (${periodItems.length})')),
                  DropdownMenuItem(value: _RefundScope.pending, child: Text('À valider (${count(RefundStatus.pendingApproval)})')),
                  DropdownMenuItem(value: _RefundScope.approved, child: Text('À effectuer (${count(RefundStatus.approved)})')),
                  DropdownMenuItem(value: _RefundScope.refunded, child: Text('Remboursés (${count(RefundStatus.refunded)})')),
                  DropdownMenuItem(value: _RefundScope.reconciled, child: Text('Rapprochés (${count(RefundStatus.reconciled)})')),
                  DropdownMenuItem(value: _RefundScope.rejected, child: Text('Rejetés (${count(RefundStatus.rejected)})')),
                ],
                onChanged: (_RefundScope? value) {
                  if (value != null) setState(() => _scope = value);
                },
              );
              final int scopeTotal = _scopeCount(all);
              final Widget indicator = Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    _query.trim().isEmpty
                        ? '$scopeTotal dossier${scopeTotal > 1 ? 's' : ''} dans cette vue'
                        : '$visibleCount affiché${visibleCount > 1 ? 's' : ''} sur $scopeTotal dans cette vue',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BackofficePalette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  children: <Widget>[
                    search,
                    const SizedBox(height: 10),
                    scope,
                    indicator,
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(flex: 3, child: search),
                      const SizedBox(width: 10),
                      SizedBox(width: 260, child: scope),
                    ],
                  ),
                  indicator,
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
            calendarHelpText: 'Retrouver d’anciens remboursements',
          ),
        ],
      ),
    );
  }


  int _scopeCount(List<RefundCase> all) {
    return all.where((RefundCase item) {
      if (!_period.contains(item.requestedAt)) return false;
      return switch (_scope) {
        _RefundScope.all => true,
        _RefundScope.pending => item.status == RefundStatus.pendingApproval,
        _RefundScope.approved => item.status == RefundStatus.approved,
        _RefundScope.refunded => item.status == RefundStatus.refunded,
        _RefundScope.reconciled => item.status == RefundStatus.reconciled,
        _RefundScope.rejected => item.status == RefundStatus.rejected,
      };
    }).length;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  List<RefundCase> _filtered(List<RefundCase> all) {
    final String query = _query.trim().toLowerCase();
    final List<RefundCase> result = all.where((RefundCase item) {
      if (!_period.contains(item.requestedAt)) return false;
      final bool inScope = switch (_scope) {
        _RefundScope.all => true,
        _RefundScope.pending => item.status == RefundStatus.pendingApproval,
        _RefundScope.approved => item.status == RefundStatus.approved,
        _RefundScope.refunded => item.status == RefundStatus.refunded,
        _RefundScope.reconciled => item.status == RefundStatus.reconciled,
        _RefundScope.rejected => item.status == RefundStatus.rejected,
      };
      if (!inScope) return false;
      if (query.isEmpty) return true;
      return <String>[item.orderReference, item.clientName, item.clientWhatsappPhone, item.reason.label, item.status.label].join(' ').toLowerCase().contains(query);
    }).toList(growable: false);
    result.sort((RefundCase a, RefundCase b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Widget _desktopTable(List<RefundCase> refunds) {
    return BackofficeDesktopTable(
      columns: const <BackofficeTableColumnSpec>[
        BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
        BackofficeTableColumnSpec(label: 'DOSSIER', flex: 3),
        BackofficeTableColumnSpec(label: 'CLIENT', flex: 3),
        BackofficeTableColumnSpec(label: 'MONTANT / MOTIF', flex: 3),
        BackofficeTableColumnSpec(label: 'ACTION', flex: 2, alignment: Alignment.centerRight),
      ],
      rows: refunds.map((RefundCase refund) {
        final Color color = _statusColor(refund.status);
        return BackofficeDesktopTableRow(
          accentColor: refund.status.isActive ? color : null,
          backgroundColor: refund.status == RefundStatus.pendingApproval ? BackofficePalette.warning.withValues(alpha: .025) : null,
          onTap: () => _openDetails(refund),
          cells: <BackofficeTableCellSpec>[
            BackofficeTableCellSpec(flex: 2, child: BackofficeStatusBadge(label: refund.status.label, color: color)),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(refund.orderReference, _formatDate(refund.requestedAt))),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(refund.clientName, refund.clientWhatsappPhone)),
            BackofficeTableCellSpec(flex: 3, child: _twoLines(formatCfa(refund.amount), refund.reason.label)),
            BackofficeTableCellSpec(flex: 2, alignment: Alignment.centerRight, child: _primaryAction(refund)),
          ],
        );
      }).toList(growable: false),
    );
  }

  Widget _mobileCard(RefundCase refund) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openDetails(refund),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: backofficePanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(children: <Widget>[Expanded(child: BackofficeStatusBadge(label: refund.status.label, color: _statusColor(refund.status))), const SizedBox(width: 8), Text(formatCfa(refund.amount), style: Theme.of(context).textTheme.titleMedium)]),
              const SizedBox(height: 10),
              Text(refund.orderReference, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('${refund.clientName} • ${refund.reason.label}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: _primaryAction(refund)),
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
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _primaryAction(RefundCase refund) {
    if (!widget.user.permissions.canManageRefunds) {
      return OutlinedButton(onPressed: () => _openDetails(refund), child: const Text('Voir'));
    }
    switch (refund.status) {
      case RefundStatus.pendingApproval:
        return FilledButton(onPressed: _submitting ? null : () => _approve(refund), child: const Text('Valider'));
      case RefundStatus.approved:
        return FilledButton(onPressed: _submitting ? null : () => _markRefunded(refund), child: const Text('Rembourser'));
      case RefundStatus.refunded:
        if (!refund.customerWasNotified) {
          return FilledButton(onPressed: _submitting ? null : () => _notifyCustomer(refund), child: const Text('Notifier'));
        }
        return OutlinedButton(onPressed: _submitting ? null : () => _reconcile(refund), child: const Text('Rapprocher'));
      case RefundStatus.reconciled:
        if (!refund.customerWasNotified) {
          return FilledButton(
            onPressed: _submitting ? null : () => _notifyCustomer(refund),
            child: const Text('Notifier'),
          );
        }
        return OutlinedButton(
          onPressed: () => _openDetails(refund),
          child: const Text('Voir'),
        );
      case RefundStatus.rejected:
        return OutlinedButton(
          onPressed: () => _openDetails(refund),
          child: const Text('Voir'),
        );
    }
  }

  Future<void> _createManualRefund(List<RefundCase> existing) async {
    final OrderHistoryRepository? history = widget.orderHistoryRepository;
    if (history == null || _submitting) return;

    setState(() => _submitting = true);
    List<QueueOrder> orders;
    try {
      orders = await history.fetchOrderHistory();
    } catch (error) {
      if (mounted) _showMessage('Impossible de charger les commandes : $error');
      if (mounted) setState(() => _submitting = false);
      return;
    }
    if (mounted) setState(() => _submitting = false);
    if (!mounted) return;

    final Set<String> existingOrderIds = existing
        .map((RefundCase value) => value.orderId)
        .toSet();
    final List<QueueOrder> eligible = orders
        .where(
          (QueueOrder order) =>
              order.paymentStatus == OrderPaymentStatus.confirmed &&
              order.status != QueueOrderStatus.refundPending &&
              order.status != QueueOrderStatus.refunded &&
              !existingOrderIds.contains(order.id),
        )
        .toList(growable: false)
      ..sort((QueueOrder a, QueueOrder b) => b.createdAt.compareTo(a.createdAt));

    if (eligible.isEmpty) {
      _showMessage(
        'Aucune commande payée sans dossier de remboursement n’est disponible.',
      );
      return;
    }

    final QueueOrder? order = await _selectOrderForManualRefund(eligible);
    if (order == null || !mounted) return;
    final RefundCreationDraft? draft = await _manualRefundDraft(order);
    if (draft == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.repository.create(
        request: RefundCreationRequest(
          orderId: order.id,
          orderReference: order.reference,
          origin: RefundOrigin.manual,
          customerAuthUid: order.customerAuthUid,
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
      _clearSearch();
      setState(() => _scope = _RefundScope.pending);
      _showMessage(
        'Dossier créé. Il est maintenant disponible dans « À valider ».',
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<QueueOrder?> _selectOrderForManualRefund(
    List<QueueOrder> orders,
  ) async {
    String query = '';
    return showDialog<QueueOrder>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String cleanQuery = query.trim().toLowerCase();
            final List<QueueOrder> visible = orders.where((QueueOrder order) {
              if (cleanQuery.isEmpty) return true;
              return <String>[
                order.reference,
                order.clientName,
                order.clientWhatsappPhone,
                order.beneficiaryPhone,
              ].join(' ').toLowerCase().contains(cleanQuery);
            }).take(12).toList(growable: false);
            return AlertDialog(
              title: const Text('Choisir la commande à rembourser'),
              content: SizedBox(
                width: 680,
                height: 470,
                child: Column(
                  children: <Widget>[
                    TextField(
                      autofocus: true,
                      onChanged: (String value) =>
                          setDialogState(() => query = value),
                      decoration: const InputDecoration(
                        hintText: 'Référence, client ou numéro',
                        prefixIcon: Icon(Symbols.search_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: visible.isEmpty
                          ? const Center(
                              child: Text('Aucune commande payée correspondante.'),
                            )
                          : ListView.separated(
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final QueueOrder order = visible[index];
                                return ListTile(
                                  onTap: () => Navigator.pop(dialogContext, order),
                                  title: Text(
                                    order.reference,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  subtitle: Text(
                                    '${order.clientName} • ${order.clientWhatsappPhone}',
                                  ),
                                  trailing: Text(
                                    formatCfa(order.amount),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<RefundCreationDraft?> _manualRefundDraft(QueueOrder order) async {
    final TextEditingController amountController = TextEditingController(
      text: order.amount.toString(),
    );
    final TextEditingController noteController = TextEditingController();
    RefundReason reason = RefundReason.serviceNotReceived;
    String? validationMessage;

    final RefundCreationDraft? result = await showDialog<RefundCreationDraft>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: Text('Nouveau remboursement • ${order.reference}'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    '${order.clientName} • paiement confirmé • ${formatCfa(order.amount)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
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
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note / justification',
                      hintText: 'Contexte de ce remboursement manuel',
                    ),
                  ),
                  if (validationMessage != null)
                    Text(
                      validationMessage!,
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
                      () => validationMessage =
                          'Le montant doit être compris entre 1 F et ${formatCfa(order.amount)}.',
                    );
                    return;
                  }
                  if (reason == RefundReason.other && note.length < 3) {
                    setDialogState(
                      () => validationMessage = 'Précisez le motif dans la note.',
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
                icon: const Icon(Symbols.add_rounded),
                label: const Text('Créer le dossier'),
              ),
            ],
          );
        },
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

  Future<void> _approve(RefundCase refund) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Valider le remboursement ?'),
        content: Text('${refund.orderReference} • ${formatCfa(refund.amount)}'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runAction(
      () => widget.repository.approve(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'Remboursement validé. Il passe dans « À effectuer ».',
    );
  }

  Future<void> _markRefunded(RefundCase refund) async {
    final String? reference = await _textDialog(
      title: 'Confirmer le remboursement',
      hint: 'Référence de remboursement Wave',
      actionLabel: 'Marquer remboursé',
    );
    if (reference == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await widget.repository.markRefunded(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
        refundReference: reference,
      );

      final bool hasSupport = refund.hasLinkedSupportRequest;
      bool supportSynced = !hasSupport;
      final SupportRequestRepository? support = widget.supportRepository;
      if (support != null && hasSupport) {
        try {
          await support.resolve(
            requestId: refund.supportRequestId,
            staffId: widget.user.id,
            staffName: widget.user.name,
            resolutionNote:
                'Remboursement de ${formatCfa(refund.amount)} effectué. Référence Wave : $reference.',
          );
        } on Object {
          supportSynced = false;
        }
      }

      if (!mounted) return;
      _showMessage(
        !hasSupport
            ? 'Remboursement effectué. La sortie est déduite de la Caisse Wave théorique.'
            : supportSynced
            ? 'Remboursement effectué. La demande client est résolue et la sortie est déduite de la Caisse Wave théorique.'
            : 'Remboursement effectué et déduit de Wave, mais la demande client n’a pas pu être synchronisée automatiquement.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _notifyCustomer(RefundCase refund) async {
    final String reference = refund.refundReference?.trim() ?? '';
    final String referenceSentence = reference.isEmpty
        ? ''
        : ' Référence du remboursement : $reference.';
    final String message =
        'Bonjour ${refund.clientName}, le remboursement de ${formatCfa(refund.amount)} concernant votre commande ${refund.orderReference} a été effectué par IzyTel.$referenceSentence';
    final bool opened = await BackofficeWhatsAppService.openMessage(
      phone: refund.clientWhatsappPhone,
      message: message,
    );
    if (!mounted) return;
    if (!opened) {
      _showMessage('Impossible d’ouvrir WhatsApp pour ce client.');
      return;
    }

    final bool confirmed = await _confirmNotificationSent();
    if (!confirmed) return;

    final bool hasSupport = refund.hasLinkedSupportRequest;
    await _runAction(
      () async {
        await widget.repository.markCustomerNotified(
          orderId: refund.orderId,
          staffId: widget.user.id,
          staffName: widget.user.name,
        );
        final SupportRequestRepository? support = widget.supportRepository;
        if (support != null && hasSupport) {
          await support.markCustomerNotified(
            requestId: refund.supportRequestId,
            staffId: widget.user.id,
            staffName: widget.user.name,
          );
        }
      },
      successMessage: hasSupport
          ? 'Notification WhatsApp confirmée et synchronisée avec la demande client.'
          : 'Notification WhatsApp confirmée dans le dossier de remboursement.',
    );
  }

  Future<bool> _confirmNotificationSent() async {
    final bool? value = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Message WhatsApp réellement envoyé ?'),
        content: const Text(
          'Confirmez uniquement après avoir envoyé le message dans WhatsApp. Sans confirmation, IzyTel ne marquera pas le client comme notifié.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Oui, envoyé'),
          ),
        ],
      ),
    );
    return value == true;
  }

  Future<void> _reconcile(RefundCase refund) async {
    await _runAction(
      () => widget.repository.reconcile(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'Remboursement rapproché et conservé dans l’historique.',
    );
  }

  Future<void> _reject(RefundCase refund) async {
    final String? reason = await _textDialog(title: 'Rejeter le remboursement', hint: 'Motif du rejet', actionLabel: 'Rejeter');
    if (reason == null) return;
    await _runAction(
      () => widget.repository.reject(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
        reason: reason,
      ),
      successMessage: 'Remboursement rejeté et conservé pour audit.',
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<String?> _textDialog({required String title, required String hint, required String actionLabel}) async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 440, child: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: hint))),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () {
            final String value = controller.text.trim();
            if (value.length >= 3) Navigator.pop(context, value);
          }, child: Text(actionLabel)),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _openDetails(RefundCase refund) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Row(children: <Widget>[Expanded(child: Text(refund.orderReference)), BackofficeStatusBadge(label: refund.status.label, color: _statusColor(refund.status))]),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _detail('Client', refund.clientName),
                _detail('WhatsApp', refund.clientWhatsappPhone),
                _detail('Montant', formatCfa(refund.amount)),
                _detail('Motif', refund.reason.label),
                if (refund.reasonNote.trim().isNotEmpty) _detail('Note', refund.reasonNote),
                _detail('Demandé le', _formatDate(refund.requestedAt)),
                _detail('Origine', refund.origin.label),
                if (refund.hasLinkedSupportRequest)
                  _detail('Demande client liée', refund.supportRequestId),
                if (refund.refundReference != null) _detail('Référence remboursement', refund.refundReference!),
                _detail('Client notifié', refund.customerWasNotified ? 'Oui' : 'Non'),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          if (refund.hasLinkedSupportRequest &&
              widget.onOpenSupportRequests != null)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenSupportRequests!.call(refund.orderReference);
              },
              icon: const Icon(Symbols.support_agent_rounded),
              label: const Text('Voir la demande client'),
            ),
          if (widget.user.permissions.canManageRefunds && refund.status == RefundStatus.pendingApproval)
            TextButton(onPressed: () { Navigator.pop(context); _reject(refund); }, style: TextButton.styleFrom(foregroundColor: BackofficePalette.danger), child: const Text('Rejeter')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: BackofficePalette.faint, fontWeight: FontWeight.w800, letterSpacing: .6)),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ]),
    );
  }

  Color _statusColor(RefundStatus status) {
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

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
  }
}
