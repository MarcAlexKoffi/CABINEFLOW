import 'dart:async';

import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _OrdersScope { all, active, completed, failed }

class BackofficeOrdersPage extends StatefulWidget {
  const BackofficeOrdersPage({
    super.key,
    required this.user,
    required this.repository,
    required this.onOpenAssignments,
    required this.onOpenPayments,
  });

  final AppUser user;
  final OrderHistoryRepository repository;
  final ValueChanged<QueueOrder> onOpenAssignments;
  final VoidCallback onOpenPayments;

  @override
  State<BackofficeOrdersPage> createState() => _BackofficeOrdersPageState();
}

class _BackofficeOrdersPageState extends State<BackofficeOrdersPage> {
  StreamSubscription<List<QueueOrder>>? _subscription;
  final TextEditingController _searchController = TextEditingController();

  List<QueueOrder> _orders = const <QueueOrder>[];
  bool _loading = true;
  String? _error;
  _OrdersScope _scope = _OrdersScope.all;
  MobileNetwork? _network;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    _subscription?.cancel();
    _loading = true;
    _error = null;
    _subscription = widget.repository.watchOrderHistory().listen(
      (List<QueueOrder> orders) {
        if (!mounted) return;
        setState(() {
          _orders = orders;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Impossible de charger les commandes.';
        });
      },
    );
  }

  Future<void> _refresh() async {
    try {
      final List<QueueOrder> orders = await widget.repository.fetchOrderHistory();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible d’actualiser les commandes.');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<QueueOrder> get _visibleOrders {
    final String query = _searchController.text.trim().toLowerCase();
    Iterable<QueueOrder> result = _orders;

    if (_network != null) {
      result = result.where((QueueOrder order) => order.network == _network);
    }

    result = result.where((QueueOrder order) {
      switch (_scope) {
        case _OrdersScope.all:
          return true;
        case _OrdersScope.active:
          return <QueueOrderStatus>{
            QueueOrderStatus.awaitingPayment,
            QueueOrderStatus.paymentToVerify,
            QueueOrderStatus.paidReady,
            QueueOrderStatus.inProgress,
            QueueOrderStatus.onHold,
            QueueOrderStatus.refundPending,
          }.contains(order.status);
        case _OrdersScope.completed:
          return <QueueOrderStatus>{
            QueueOrderStatus.awaitingCustomerConfirmation,
            QueueOrderStatus.completed,
            QueueOrderStatus.refunded,
          }.contains(order.status);
        case _OrdersScope.failed:
          return <QueueOrderStatus>{
            QueueOrderStatus.failed,
            QueueOrderStatus.cancelled,
            QueueOrderStatus.expired,
          }.contains(order.status);
      }
    });

    if (query.isNotEmpty) {
      result = result.where((QueueOrder order) {
        final String haystack = <String>[
          order.reference,
          order.clientName,
          order.clientWhatsappPhone,
          order.beneficiaryPhone,
          order.offerLabel,
          order.assignedAgentName ?? '',
          networkLabel(order.network),
          orderStatusLabel(order.status),
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }

    return result.toList(growable: false);
  }

  int get _activeCount => _orders.where((QueueOrder order) {
    return <QueueOrderStatus>{
      QueueOrderStatus.awaitingPayment,
      QueueOrderStatus.paymentToVerify,
      QueueOrderStatus.paidReady,
      QueueOrderStatus.inProgress,
      QueueOrderStatus.onHold,
      QueueOrderStatus.refundPending,
    }.contains(order.status);
  }).length;

  int get _todayCount {
    final DateTime now = DateTime.now();
    return _orders.where((QueueOrder order) {
      final DateTime date = order.createdAt.toLocal();
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).length;
  }

  int get _completedCount => _orders.where((QueueOrder order) {
    return <QueueOrderStatus>{
      QueueOrderStatus.awaitingCustomerConfirmation,
      QueueOrderStatus.completed,
      QueueOrderStatus.refunded,
    }.contains(order.status);
  }).length;

  int get _failedCount => _orders.where((QueueOrder order) {
    return <QueueOrderStatus>{
      QueueOrderStatus.failed,
      QueueOrderStatus.cancelled,
      QueueOrderStatus.expired,
    }.contains(order.status);
  }).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BackofficePageIntro(
          eyebrow: 'Opérations / Commandes',
          title: 'Centre des commandes',
          description:
              'Retrouve l’ensemble des commandes IzyTel, leur statut, leur paiement et leur affectation depuis une vue unique pensée pour le grand écran.',
          icon: Symbols.receipt_long_rounded,
          trailing: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Symbols.refresh_rounded),
            label: const Text('Actualiser'),
          ),
        ),
        const SizedBox(height: 16),
        _MetricsGrid(
          cards: <Widget>[
            BackofficeMetricCard(
              label: 'Aujourd’hui',
              value: '$_todayCount',
              caption: 'commandes créées',
              icon: Symbols.today_rounded,
            ),
            BackofficeMetricCard(
              label: 'Actives',
              value: '$_activeCount',
              caption: 'à suivre maintenant',
              icon: Symbols.bolt_rounded,
              emphasis: BackofficePalette.primaryStrong,
            ),
            BackofficeMetricCard(
              label: 'Terminées',
              value: '$_completedCount',
              caption: 'traitées avec succès',
              icon: Symbols.check_circle_rounded,
              emphasis: BackofficePalette.success,
            ),
            BackofficeMetricCard(
              label: 'Alertes',
              value: '$_failedCount',
              caption: 'échecs / expirations',
              icon: Symbols.error_rounded,
              emphasis: BackofficePalette.danger,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _filters(context),
        const SizedBox(height: 14),
        if (_error != null) ...<Widget>[
          BackofficeInlineError(message: _error!, onRetry: _refresh),
          const SizedBox(height: 14),
        ],
        if (_loading && _orders.isEmpty)
          const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_visibleOrders.isEmpty)
          const BackofficeEmptyState(
            icon: Symbols.search_off_rounded,
            title: 'Aucune commande trouvée',
            message: 'Modifie les filtres ou la recherche pour retrouver une commande.',
          )
        else
          _OrdersList(
            orders: _visibleOrders,
            onOpen: (QueueOrder order) => showBackofficeOrderDetails(context, order),
            onAssign: widget.onOpenAssignments,
            onPayments: widget.onOpenPayments,
          ),
      ],
    );
  }

  Widget _filters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: backofficePanelDecoration(),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 820;
          final Widget search = TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Référence, client, numéro, offre ou agent',
              prefixIcon: Icon(Symbols.search_rounded),
              isDense: true,
            ),
          );
          final Widget scope = DropdownButtonFormField<_OrdersScope>(
            initialValue: _scope,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'État'),
            items: const <DropdownMenuItem<_OrdersScope>>[
              DropdownMenuItem(value: _OrdersScope.all, child: Text('Toutes')),
              DropdownMenuItem(value: _OrdersScope.active, child: Text('Actives')),
              DropdownMenuItem(value: _OrdersScope.completed, child: Text('Terminées')),
              DropdownMenuItem(value: _OrdersScope.failed, child: Text('Alertes')),
            ],
            onChanged: (_OrdersScope? value) {
              if (value != null) setState(() => _scope = value);
            },
          );
          final Widget network = DropdownButtonFormField<MobileNetwork?>(
            initialValue: _network,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Réseau'),
            items: const <DropdownMenuItem<MobileNetwork?>>[
              DropdownMenuItem(value: null, child: Text('Tous les réseaux')),
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
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.cards});

  final List<Widget> cards;

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
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards.map((Widget card) => SizedBox(width: width, child: card)).toList(),
        );
      },
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.onOpen,
    required this.onAssign,
    required this.onPayments,
  });

  final List<QueueOrder> orders;
  final ValueChanged<QueueOrder> onOpen;
  final ValueChanged<QueueOrder> onAssign;
  final VoidCallback onPayments;

  bool _canAssign(QueueOrder order) {
    return order.status == QueueOrderStatus.paidReady && !order.isAssignedToAgent;
  }

  bool _paymentNeedsReview(QueueOrder order) {
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
        if (constraints.maxWidth < 880) {
          return Column(
            children: orders.map((QueueOrder order) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderCard(
                  order: order,
                  onOpen: () => onOpen(order),
                  onAssign: _canAssign(order) ? () => onAssign(order) : null,
                  onPayments: onPayments,
                ),
              );
            }).toList(),
          );
        }

        return BackofficeDesktopTable(
          columns: const <BackofficeTableColumnSpec>[
            BackofficeTableColumnSpec(label: 'STATUT', flex: 2),
            BackofficeTableColumnSpec(label: 'COMMANDE', flex: 2),
            BackofficeTableColumnSpec(label: 'CLIENT', flex: 2),
            BackofficeTableColumnSpec(
              label: 'MONTANT',
              flex: 1,
              alignment: Alignment.centerRight,
            ),
            BackofficeTableColumnSpec(label: 'AFFECTATION', flex: 2),
            BackofficeTableColumnSpec(
              label: 'ACTION',
              flex: 2,
              alignment: Alignment.centerRight,
            ),
          ],
          rows: orders.map((QueueOrder order) {
            final bool paymentNeedsReview = _paymentNeedsReview(order);
            final bool assignable = _canAssign(order);
            final Color statusColor = paymentNeedsReview
                ? BackofficePalette.warning
                : assignable
                ? BackofficePalette.primaryStrong
                : orderStatusColor(order.status);
            final String statusLabel = paymentNeedsReview
                ? 'Paiement à vérifier'
                : assignable
                ? 'À affecter'
                : orderStatusLabel(order.status);
            return BackofficeDesktopTableRow(
              onTap: () => onOpen(order),
              backgroundColor: paymentNeedsReview
                  ? BackofficePalette.warning.withValues(alpha: .04)
                  : assignable
                  ? BackofficePalette.primarySoft.withValues(alpha: .42)
                  : null,
              accentColor: paymentNeedsReview
                  ? BackofficePalette.warning
                  : assignable
                  ? BackofficePalette.primary
                  : null,
              cells: <BackofficeTableCellSpec>[
                BackofficeTableCellSpec(
                  flex: 2,
                  child: BackofficeStatusBadge(
                    label: statusLabel,
                    color: statusColor,
                    icon: paymentNeedsReview
                        ? Symbols.priority_high_rounded
                        : assignable
                        ? Symbols.person_add_rounded
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(child: BackofficeNetworkBadge(network: order.network)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              formatOrderDateTime(order.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: BackofficePalette.faint,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  alignment: Alignment.centerRight,
                  child: Text(
                    formatCfa(order.amount),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        order.assignedAgentName?.trim().isNotEmpty == true
                            ? order.assignedAgentName!
                            : 'Non affectée',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: assignable
                              ? BackofficePalette.primaryStrong
                              : BackofficePalette.ink,
                        ),
                      ),
                      if (order.manualAssignmentRequired) ...<Widget>[
                        const SizedBox(height: 3),
                        const Text(
                          'Intervention manuelle requise',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BackofficePalette.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                BackofficeTableCellSpec(
                  flex: 2,
                  alignment: Alignment.centerRight,
                  child: paymentNeedsReview
                      ? FilledButton.tonalIcon(
                          onPressed: onPayments,
                          icon: const Icon(Symbols.payments_rounded, size: 18),
                          label: const Text('Paiement'),
                        )
                      : assignable
                      ? FilledButton.tonalIcon(
                          onPressed: () => onAssign(order),
                          icon: const Icon(Symbols.assignment_ind_rounded, size: 18),
                          label: const Text('Affecter'),
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

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onOpen,
    required this.onPayments,
    this.onAssign,
  });

  final QueueOrder order;
  final VoidCallback onOpen;
  final VoidCallback? onAssign;
  final VoidCallback onPayments;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                label: orderStatusLabel(order.status),
                color: orderStatusColor(order.status),
                icon: orderStatusIcon(order.status),
              ),
              if (order.assignedAgentName?.trim().isNotEmpty == true)
                BackofficeStatusBadge(
                  label: order.assignedAgentName!,
                  color: BackofficePalette.primary,
                  icon: Symbols.person_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Symbols.visibility_rounded, size: 18),
                label: const Text('Détails'),
              ),
              const SizedBox(width: 8),
              if (onAssign != null)
                FilledButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Symbols.assignment_ind_rounded, size: 18),
                  label: const Text('Affecter'),
                )
              else if (order.paymentStatus == OrderPaymentStatus.declared)
                TextButton.icon(
                  onPressed: onPayments,
                  icon: const Icon(Symbols.payments_rounded, size: 18),
                  label: const Text('Paiement'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
