import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/features/payments/presentation/view_models/payments_view_model.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class BackofficePaymentsPage extends StatefulWidget {
  const BackofficePaymentsPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.onOpenOrders,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final VoidCallback onOpenOrders;

  @override
  State<BackofficePaymentsPage> createState() => _BackofficePaymentsPageState();
}

class _BackofficePaymentsPageState extends State<BackofficePaymentsPage> {
  late final PaymentsViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = PaymentsViewModel(ordersRepository: widget.ordersRepository);
    _viewModel.startRealtime();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _requiresVerification(QueueOrder order) {
    return order.hasPaymentToReviewAfterExpiration ||
        (order.source == OrderSource.customerWeb &&
            order.paymentStatus == OrderPaymentStatus.declared &&
            (order.status == QueueOrderStatus.paymentToVerify ||
                order.status == QueueOrderStatus.awaitingPayment));
  }

  List<QueueOrder> _searchedOrders(List<QueueOrder> orders) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<QueueOrder> result = orders.where((QueueOrder order) {
      if (query.isEmpty) return true;
      final String haystack = <String>[
        order.reference,
        order.clientName,
        order.clientWhatsappPhone,
        order.beneficiaryPhone,
        order.paymentReference ?? '',
        order.paymentDeclaredReference ?? '',
        networkLabel(order.network),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: true);

    // Dans la vue globale, les paiements qui demandent une action restent
    // toujours en tête. On évite ainsi qu'une déclaration à vérifier soit
    // visuellement noyée parmi les paiements déjà confirmés.
    if (_viewModel.selectedFilter == PaymentOrderFilter.all) {
      result.sort((QueueOrder a, QueueOrder b) {
        final bool aActionable = _requiresVerification(a);
        final bool bActionable = _requiresVerification(b);
        if (aActionable != bActionable) return aActionable ? -1 : 1;
        final DateTime aDate = a.paymentDeclaredAt ?? a.createdAt;
        final DateTime bDate = b.paymentDeclaredAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    }

    return result;
  }

  int get _verificationCount =>
      _viewModel.allOrders.where(_requiresVerification).length;

  int get _verificationAmount => _viewModel.allOrders
      .where(_requiresVerification)
      .fold<int>(0, (int sum, QueueOrder order) => sum + order.amount);

  int get _confirmedCount => _viewModel.allOrders.where((QueueOrder order) {
    return order.paymentStatus == OrderPaymentStatus.confirmed;
  }).length;

  int get _declaredCount => _viewModel.allOrders.where((QueueOrder order) {
    return order.paymentStatus == OrderPaymentStatus.declared;
  }).length;

  Future<void> _confirmPayment(QueueOrder order) async {
    final String? reference = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _PaymentConfirmationDialog(order: order);
      },
    );
    if (reference == null || !mounted) return;

    final bool success = await _viewModel.confirmPayment(
      order: order,
      paymentReference: reference.trim().isEmpty ? null : reference.trim(),
    );
    if (!mounted) return;

    final String message = success
        ? 'Paiement ${order.reference} confirmé. La commande est prête pour le traitement.'
        : (_viewModel.errorMessage ?? 'Impossible de confirmer ce paiement.');
    IzyTelFeedback.show(context, message);
  }

  String _filterLabel(PaymentOrderFilter filter) {
    return switch (filter) {
      PaymentOrderFilter.all => 'Tous',
      PaymentOrderFilter.linkToSend => 'Liens à envoyer',
      PaymentOrderFilter.awaitingPayment => 'À vérifier',
      PaymentOrderFilter.afterExpiration => 'Expirés',
      PaymentOrderFilter.confirmed => 'Confirmés',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final List<QueueOrder> visible = _searchedOrders(_viewModel.visibleOrders);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            BackofficePageIntro(
              eyebrow: 'Opérations / Paiements',
              title: 'Centre de vérification des paiements',
              description:
                  'Contrôle les déclarations Wave, les paiements expirés et les confirmations sans perdre la visibilité sur les commandes déjà réglées.',
              icon: Symbols.payments_rounded,
              trailing: OutlinedButton.icon(
                onPressed: _viewModel.loadPayments,
                icon: const Icon(Symbols.refresh_rounded),
                label: const Text('Actualiser'),
              ),
            ),
            const SizedBox(height: 16),
            _PaymentMetrics(
              verificationCount: _verificationCount,
              verificationAmount: _verificationAmount,
              declaredCount: _declaredCount,
              confirmedCount: _confirmedCount,
            ),
            const SizedBox(height: 12),
            if (_verificationCount > 0) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: BackofficePalette.warning.withValues(alpha: .08),
                  border: Border.all(
                    color: BackofficePalette.warning.withValues(alpha: .24),
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: BackofficePalette.warning.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Symbols.priority_high_rounded,
                        color: BackofficePalette.warning,
                        fill: 1,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '$_verificationCount paiement${_verificationCount > 1 ? 's' : ''} à vérifier',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: BackofficePalette.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatCfa(_verificationAmount)} nécessitent une validation avant traitement.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => _viewModel.selectFilter(
                        PaymentOrderFilter.awaitingPayment,
                      ),
                      icon: const Icon(Symbols.fact_check_rounded, size: 18),
                      label: const Text('Voir à vérifier'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else
              const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: backofficePanelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Référence, client, bénéficiaire ou référence Wave',
                      prefixIcon: Icon(Symbols.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PaymentOrderFilter.values.map((PaymentOrderFilter filter) {
                      final int count = _viewModel.countForFilter(filter);
                      if (filter == PaymentOrderFilter.linkToSend && count == 0) {
                        return const SizedBox.shrink();
                      }
                      final bool selected = _viewModel.selectedFilter == filter;
                      return ChoiceChip(
                        label: Text('${_filterLabel(filter)}  $count'),
                        selected: selected,
                        onSelected: (_) => _viewModel.selectFilter(filter),
                        selectedColor: BackofficePalette.primarySoft,
                        side: BorderSide(
                          color: selected
                              ? BackofficePalette.primary.withValues(alpha: .30)
                              : BackofficePalette.line,
                        ),
                        labelStyle: TextStyle(
                          color: selected
                              ? BackofficePalette.primaryStrong
                              : BackofficePalette.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_viewModel.errorMessage != null) ...<Widget>[
              BackofficeInlineError(
                message: _viewModel.errorMessage!,
                onRetry: _viewModel.loadPayments,
              ),
              const SizedBox(height: 14),
            ],
            if (_viewModel.isLoading && _viewModel.allOrders.isEmpty)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (visible.isEmpty)
              BackofficeEmptyState(
                icon: Symbols.verified_rounded,
                title: 'Aucun paiement dans cette vue',
                message: 'La file de vérification est à jour pour ce filtre.',
                action: OutlinedButton.icon(
                  onPressed: widget.onOpenOrders,
                  icon: const Icon(Symbols.receipt_long_rounded),
                  label: const Text('Voir les commandes'),
                ),
              )
            else
              _PaymentList(
                orders: visible,
                viewModel: _viewModel,
                onConfirm: _confirmPayment,
                onOpen: (QueueOrder order) => showBackofficeOrderDetails(context, order),
              ),
          ],
        );
      },
    );
  }
}

class _PaymentMetrics extends StatelessWidget {
  const _PaymentMetrics({
    required this.verificationCount,
    required this.verificationAmount,
    required this.declaredCount,
    required this.confirmedCount,
  });

  final int verificationCount;
  final int verificationAmount;
  final int declaredCount;
  final int confirmedCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 920
            ? 4
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final double gap = 10;
        final double width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final List<Widget> cards = <Widget>[
          BackofficeMetricCard(
            label: 'À vérifier',
            value: '$verificationCount',
            caption: formatCfa(verificationAmount),
            icon: Symbols.fact_check_rounded,
            emphasis: BackofficePalette.warning,
          ),
          BackofficeMetricCard(
            label: 'Déclarés',
            value: '$declaredCount',
            caption: 'déclarations reçues',
            icon: Symbols.notifications_active_rounded,
          ),
          BackofficeMetricCard(
            label: 'Confirmés',
            value: '$confirmedCount',
            caption: 'paiements validés',
            icon: Symbols.verified_rounded,
            emphasis: BackofficePalette.success,
          ),
          BackofficeMetricCard(
            label: 'Suivis',
            value: '${verificationCount + confirmedCount}',
            caption: 'paiements utiles',
            icon: Symbols.monitoring_rounded,
            emphasis: BackofficePalette.primaryStrong,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }
}

class _PaymentList extends StatelessWidget {
  const _PaymentList({
    required this.orders,
    required this.viewModel,
    required this.onConfirm,
    required this.onOpen,
  });

  final List<QueueOrder> orders;
  final PaymentsViewModel viewModel;
  final ValueChanged<QueueOrder> onConfirm;
  final ValueChanged<QueueOrder> onOpen;

  bool _canConfirm(QueueOrder order) {
    return order.hasPaymentToReviewAfterExpiration ||
        (order.source == OrderSource.customerWeb &&
            order.paymentStatus == OrderPaymentStatus.declared &&
            (order.status == QueueOrderStatus.paymentToVerify ||
                order.status == QueueOrderStatus.awaitingPayment));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 900) {
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(order.reference, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 3),
                                Text('${order.clientName} • ${formatCfa(order.amount)}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                          BackofficeNetworkBadge(network: order.network),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          BackofficeStatusBadge(
                            label: paymentStatusLabel(order.paymentStatus),
                            color: order.paymentStatus == OrderPaymentStatus.confirmed
                                ? BackofficePalette.success
                                : BackofficePalette.warning,
                            icon: Symbols.account_balance_wallet_rounded,
                          ),
                          BackofficeStatusBadge(
                            label: orderStatusLabel(order.status),
                            color: orderStatusColor(order.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => onOpen(order),
                            icon: const Icon(Symbols.visibility_rounded, size: 18),
                            label: const Text('Détails'),
                          ),
                          const SizedBox(width: 8),
                          if (_canConfirm(order))
                            FilledButton.icon(
                              onPressed: viewModel.isProcessing(order.id)
                                  ? null
                                  : () => onConfirm(order),
                              icon: const Icon(Symbols.verified_rounded, size: 18),
                              label: const Text('Confirmer'),
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
            BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
            BackofficeTableColumnSpec(label: 'PAIEMENT', flex: 2),
            BackofficeTableColumnSpec(label: 'CLIENT', flex: 2),
            BackofficeTableColumnSpec(label: 'RÉSEAU', flex: 1),
            BackofficeTableColumnSpec(
              label: 'MONTANT',
              flex: 1,
              alignment: Alignment.centerRight,
            ),
            BackofficeTableColumnSpec(
              label: 'ACTION',
              flex: 2,
              alignment: Alignment.centerRight,
            ),
          ],
          rows: orders.map((QueueOrder order) {
            final bool actionable = _canConfirm(order);
            final Color statusColor = actionable
                ? BackofficePalette.warning
                : order.paymentStatus == OrderPaymentStatus.confirmed
                ? BackofficePalette.success
                : BackofficePalette.primaryStrong;
            final String statusLabel = actionable
                ? 'À vérifier'
                : paymentStatusLabel(order.paymentStatus);
            final String paymentReference =
                order.paymentDeclaredReference?.trim().isNotEmpty == true
                ? order.paymentDeclaredReference!
                : (order.paymentReference ?? 'Sans référence');
            return BackofficeDesktopTableRow(
              onTap: () => onOpen(order),
              backgroundColor: actionable
                  ? BackofficePalette.warning.withValues(alpha: .045)
                  : null,
              accentColor: actionable ? BackofficePalette.warning : null,
              cells: <BackofficeTableCellSpec>[
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeStatusBadge(
                    label: statusLabel,
                    color: statusColor,
                    icon: actionable
                        ? Symbols.priority_high_rounded
                        : Symbols.account_balance_wallet_rounded,
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
                      const SizedBox(height: 2),
                      Text(
                        paymentReference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (order.paymentDeclaredAt != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          formatOrderDateTime(order.paymentDeclaredAt!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: BackofficePalette.faint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatIvorianPhone(order.beneficiaryPhone),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 1,
                  child: BackofficeNetworkBadge(network: order.network),
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
                  flex: 2,
                  alignment: Alignment.centerRight,
                  child: actionable
                      ? FilledButton.tonalIcon(
                          onPressed: viewModel.isProcessing(order.id)
                              ? null
                              : () => onConfirm(order),
                          icon: const Icon(Symbols.fact_check_rounded, size: 18),
                          label: const Text('Vérifier'),
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

class _PaymentConfirmationDialog extends StatefulWidget {
  const _PaymentConfirmationDialog({required this.order});

  final QueueOrder order;

  @override
  State<_PaymentConfirmationDialog> createState() => _PaymentConfirmationDialogState();
}

class _PaymentConfirmationDialogState extends State<_PaymentConfirmationDialog> {
  late final TextEditingController _referenceController;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController(
      text: widget.order.paymentDeclaredReference ?? '',
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QueueOrder order = widget.order;
    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Symbols.verified_rounded, color: BackofficePalette.primary, fill: 1),
          SizedBox(width: 10),
          Text('Confirmer le paiement'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: BackofficePalette.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(order.reference, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 5),
                  Text('${order.clientName} • ${formatCfaFull(order.amount)}'),
                  const SizedBox(height: 4),
                  Text('Bénéficiaire : ${formatIvorianPhone(order.beneficiaryPhone)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Référence Wave / paiement',
                prefixIcon: Icon(Symbols.tag_rounded),
              ),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _checked,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('J’ai vérifié le paiement dans le canal de paiement.'),
              subtitle: const Text('La confirmation rend la commande disponible pour le traitement.'),
              onChanged: (bool? value) => setState(() => _checked = value ?? false),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _checked
              ? () => Navigator.of(context).pop(_referenceController.text)
              : null,
          icon: const Icon(Symbols.verified_rounded),
          label: const Text('Confirmer le paiement'),
        ),
      ],
    );
  }
}
