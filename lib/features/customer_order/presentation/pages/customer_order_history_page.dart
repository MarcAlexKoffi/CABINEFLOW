import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

class CustomerOrderHistoryPage extends StatefulWidget {
  const CustomerOrderHistoryPage({
    super.key,
    required this.viewModel,
    required this.onBack,
    required this.onOpenOrder,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback onBack;
  final ValueChanged<CustomerOrderReceipt> onOpenOrder;

  @override
  State<CustomerOrderHistoryPage> createState() {
    return _CustomerOrderHistoryPageState();
  }
}

class _CustomerOrderHistoryPageState extends State<CustomerOrderHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  MobileNetwork? _networkFilter;
  _HistoryStatusFilter _statusFilter = _HistoryStatusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CustomerOrderReceipt> get _visibleOrders {
    final String rawQuery = _searchController.text.trim().toLowerCase();
    final String digitQuery = rawQuery.replaceAll(RegExp(r'[^0-9]'), '');

    return widget.viewModel.customerOrders.where((CustomerOrderReceipt order) {
      if (_networkFilter != null && order.draft.network != _networkFilter) {
        return false;
      }

      if (!_statusFilter.matches(order.status)) {
        return false;
      }

      if (rawQuery.isEmpty) {
        return true;
      }

      final String reference = order.reference.toLowerCase();
      final String service = order.draft.service!.label.toLowerCase();
      final String offer = order.draft.selectedOfferLabel!.toLowerCase();
      final String beneficiaryDigits = order.draft.beneficiaryNumber!.normalized
          .replaceAll(RegExp(r'[^0-9]'), '');

      return reference.contains(rawQuery) ||
          service.contains(rawQuery) ||
          offer.contains(rawQuery) ||
          (digitQuery.isNotEmpty && beneficiaryDigits.contains(digitQuery));
    }).toList();
  }

  bool get _hasActiveFilter {
    return _networkFilter != null || _statusFilter != _HistoryStatusFilter.all;
  }

  Future<void> _openFilters() async {
    final _HistoryFilters? filters =
        await showModalBottomSheet<_HistoryFilters>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return _HistoryFilterSheet(
              initialNetwork: _networkFilter,
              initialStatus: _statusFilter,
            );
          },
        );

    if (!mounted || filters == null) {
      return;
    }

    setState(() {
      _networkFilter = filters.network;
      _statusFilter = filters.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<CustomerOrderReceipt> orders = _visibleOrders;

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: CustomerAppColors.surface,
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0x33C2C6D8)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _HistoryTopBar(onBack: widget.onBack),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: widget.viewModel.reloadHistory,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
                        children: [
                          Text(
                            'Historique des commandes',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Retrouvez vos commandes passées et reprenez le suivi d’une opération.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    hintText:
                                        'Référence ou numéro bénéficiaire',
                                    prefixIcon: Icon(Icons.search_rounded),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned.fill(
                                      child: OutlinedButton(
                                        onPressed: _openFilters,
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(52, 52),
                                        ),
                                        child: const Icon(
                                          Icons.tune_rounded,
                                          color: CustomerAppColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (_hasActiveFilter)
                                      const Positioned(
                                        right: -2,
                                        top: -2,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: CustomerAppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox(
                                            width: 11,
                                            height: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_hasActiveFilter) ...[
                            const SizedBox(height: 14),
                            _ActiveFilters(
                              network: _networkFilter,
                              status: _statusFilter,
                              onClear: () {
                                setState(() {
                                  _networkFilter = null;
                                  _statusFilter = _HistoryStatusFilter.all;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 22),
                          if (widget.viewModel.isLoadingHistory)
                            const _HistoryLoading()
                          else if (widget.viewModel.historyErrorMessage != null)
                            _HistoryError(
                              message: widget.viewModel.historyErrorMessage!,
                              onRetry: widget.viewModel.reloadHistory,
                            )
                          else if (orders.isEmpty)
                            _HistoryEmpty(
                              hasSearchOrFilter:
                                  _hasActiveFilter ||
                                  _searchController.text.trim().isNotEmpty,
                            )
                          else
                            ...orders.map((CustomerOrderReceipt order) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _OrderHistoryCard(
                                  order: order,
                                  onTap: () => widget.onOpenOrder(order),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTopBar extends StatelessWidget {
  const _HistoryTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: CustomerAppColors.primary,
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'CabineFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CustomerAppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  const _OrderHistoryCard({required this.order, required this.onTap});

  final CustomerOrderReceipt order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final MobileNetwork network = order.draft.network!;
    final _StatusPresentation status = _StatusPresentation.from(order);

    return Material(
      color: CustomerAppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CustomerAppColors.surfaceContainerHigh),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NetworkBadge(network: network),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.draft.service!.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CustomerAppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${network.customerLabel} · ${order.draft.beneficiaryNumber!.displayValue}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CustomerAppColors.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${formatCfa(order.draft.amount!)} CFA',
                        style: const TextStyle(
                          color: CustomerAppColors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatDate(order.createdAt),
                        style: const TextStyle(
                          color: CustomerAppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                color: CustomerAppColors.surfaceContainerHigh,
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Réf. ${order.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: status.backgroundColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          status.icon,
                          size: 13,
                          color: status.foregroundColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status.label,
                          style: TextStyle(
                            color: status.foregroundColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _NetworkBadge extends StatelessWidget {
  const _NetworkBadge({required this.network});

  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    final (
      String label,
      Color background,
      Color foreground,
    ) = switch (network) {
      MobileNetwork.orange => (
        'OR',
        const Color(0xFFFFEDD5),
        const Color(0xFFC2410C),
      ),
      MobileNetwork.mtn => (
        'MTN',
        const Color(0xFFFEF3C7),
        const Color(0xFFA16207),
      ),
      MobileNetwork.moov => (
        'MV',
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
      ),
    };

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HistoryLoading extends StatelessWidget {
  const _HistoryLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 70),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _MessageState(
      icon: Icons.cloud_off_rounded,
      title: 'Historique indisponible',
      message: message,
      actionLabel: 'Réessayer',
      onAction: onRetry,
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty({required this.hasSearchOrFilter});

  final bool hasSearchOrFilter;

  @override
  Widget build(BuildContext context) {
    return _MessageState(
      icon: hasSearchOrFilter
          ? Icons.search_off_rounded
          : Icons.receipt_long_outlined,
      title: hasSearchOrFilter
          ? 'Aucune commande correspondante'
          : 'Aucune commande enregistrée',
      message: hasSearchOrFilter
          ? 'Modifiez votre recherche ou retirez les filtres appliqués.'
          : 'Vos commandes apparaîtront ici après leur création.',
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 42, 24, 38),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerAppColors.surfaceContainerHigh),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: CustomerAppColors.outline),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CustomerAppColors.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.network,
    required this.status,
    required this.onClear,
  });

  final MobileNetwork? network;
  final _HistoryStatusFilter status;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[
      if (network != null) network!.customerLabel,
      if (status != _HistoryStatusFilter.all) status.label,
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            'Filtres : ${labels.join(' · ')}',
            style: const TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(onPressed: onClear, child: const Text('Effacer')),
      ],
    );
  }
}

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({
    required this.initialNetwork,
    required this.initialStatus,
  });

  final MobileNetwork? initialNetwork;
  final _HistoryStatusFilter initialStatus;

  @override
  State<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  late MobileNetwork? _network;
  late _HistoryStatusFilter _status;

  @override
  void initState() {
    super.initState();
    _network = widget.initialNetwork;
    _status = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: const BoxDecoration(
          color: CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  color: CustomerAppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Filtrer l’historique',
              style: TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Réseau',
              style: TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tous'),
                  selected: _network == null,
                  onSelected: (_) => setState(() => _network = null),
                ),
                ...MobileNetwork.values.map((MobileNetwork network) {
                  return ChoiceChip(
                    label: Text(network.customerLabel),
                    selected: _network == network,
                    onSelected: (_) => setState(() => _network = network),
                  );
                }),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'État de la commande',
              style: TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _HistoryStatusFilter.values.map((filter) {
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: _status == filter,
                  onSelected: (_) => setState(() => _status = filter),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(_HistoryFilters(network: _network, status: _status));
              },
              child: const Text('Appliquer les filtres'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryFilters {
  const _HistoryFilters({required this.network, required this.status});

  final MobileNetwork? network;
  final _HistoryStatusFilter status;
}

enum _HistoryStatusFilter { all, active, completed, attention }

extension on _HistoryStatusFilter {
  String get label {
    switch (this) {
      case _HistoryStatusFilter.all:
        return 'Toutes';
      case _HistoryStatusFilter.active:
        return 'En cours';
      case _HistoryStatusFilter.completed:
        return 'Terminées';
      case _HistoryStatusFilter.attention:
        return 'À examiner';
    }
  }

  bool matches(QueueOrderStatus status) {
    switch (this) {
      case _HistoryStatusFilter.all:
        return true;
      case _HistoryStatusFilter.active:
        return status == QueueOrderStatus.awaitingPayment ||
            status == QueueOrderStatus.paymentToVerify ||
            status == QueueOrderStatus.paidReady ||
            status == QueueOrderStatus.inProgress ||
            status == QueueOrderStatus.onHold ||
            status == QueueOrderStatus.awaitingCustomerConfirmation;
      case _HistoryStatusFilter.completed:
        return status == QueueOrderStatus.completed ||
            status == QueueOrderStatus.refunded;
      case _HistoryStatusFilter.attention:
        return status == QueueOrderStatus.failed ||
            status == QueueOrderStatus.expired ||
            status == QueueOrderStatus.cancelled ||
            status == QueueOrderStatus.refundPending;
    }
  }
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  factory _StatusPresentation.from(CustomerOrderReceipt order) {
    switch (order.status) {
      case QueueOrderStatus.awaitingPayment:
        return const _StatusPresentation(
          label: 'À payer',
          icon: Icons.account_balance_wallet_outlined,
          foregroundColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFFF3D6),
        );
      case QueueOrderStatus.paymentToVerify:
        return const _StatusPresentation(
          label: 'À vérifier',
          icon: Icons.schedule_rounded,
          foregroundColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFFF3D6),
        );
      case QueueOrderStatus.paidReady:
        return const _StatusPresentation(
          label: 'Confirmé',
          icon: Icons.verified_rounded,
          foregroundColor: Color(0xFF047857),
          backgroundColor: Color(0xFFD1FAE5),
        );
      case QueueOrderStatus.inProgress:
        return const _StatusPresentation(
          label: 'En traitement',
          icon: Icons.sync_rounded,
          foregroundColor: Color(0xFF1D4ED8),
          backgroundColor: Color(0xFFDBEAFE),
        );
      case QueueOrderStatus.onHold:
        return const _StatusPresentation(
          label: 'En attente',
          icon: Icons.pause_circle_outline_rounded,
          foregroundColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFFF3D6),
        );
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return const _StatusPresentation(
          label: 'Effectuée',
          icon: Icons.task_alt_rounded,
          foregroundColor: Color(0xFF047857),
          backgroundColor: Color(0xFFD1FAE5),
        );
      case QueueOrderStatus.completed:
        return const _StatusPresentation(
          label: 'Terminée',
          icon: Icons.check_circle_rounded,
          foregroundColor: Color(0xFF047857),
          backgroundColor: Color(0xFFD1FAE5),
        );
      case QueueOrderStatus.failed:
        return const _StatusPresentation(
          label: 'Échouée',
          icon: Icons.error_outline_rounded,
          foregroundColor: Color(0xFFB91C1C),
          backgroundColor: Color(0xFFFEE2E2),
        );
      case QueueOrderStatus.expired:
        if (order.hasPaymentToReviewAfterExpiration) {
          return const _StatusPresentation(
            label: 'Paiement à examiner',
            icon: Icons.manage_search_rounded,
            foregroundColor: Color(0xFFB45309),
            backgroundColor: Color(0xFFFFF3D6),
          );
        }

        return const _StatusPresentation(
          label: 'Expirée',
          icon: Icons.timer_off_outlined,
          foregroundColor: Color(0xFFB91C1C),
          backgroundColor: Color(0xFFFEE2E2),
        );
      case QueueOrderStatus.cancelled:
        return const _StatusPresentation(
          label: 'Annulée',
          icon: Icons.cancel_outlined,
          foregroundColor: Color(0xFFB91C1C),
          backgroundColor: Color(0xFFFEE2E2),
        );
      case QueueOrderStatus.refundPending:
        return const _StatusPresentation(
          label: 'Remboursement',
          icon: Icons.currency_exchange_rounded,
          foregroundColor: Color(0xFFB45309),
          backgroundColor: Color(0xFFFFF3D6),
        );
      case QueueOrderStatus.refunded:
        return const _StatusPresentation(
          label: 'Remboursée',
          icon: Icons.check_circle_outline_rounded,
          foregroundColor: Color(0xFF047857),
          backgroundColor: Color(0xFFD1FAE5),
        );
    }
  }
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime date = DateTime(local.year, local.month, local.day);
  final String time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  if (date == today) {
    return 'Aujourd’hui, $time';
  }

  if (date == today.subtract(const Duration(days: 1))) {
    return 'Hier, $time';
  }

  const List<String> months = <String>[
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  return '${local.day} ${months[local.month - 1]}, $time';
}
