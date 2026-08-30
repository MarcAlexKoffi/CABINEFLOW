import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

enum _JournalFilter { all, orders, requests }

class AdminActivityJournalPage extends StatefulWidget {
  const AdminActivityJournalPage({
    super.key,
    required this.orderHistoryRepository,
    required this.supportRequestRepository,
  });

  final OrderHistoryRepository orderHistoryRepository;
  final SupportRequestRepository supportRequestRepository;

  @override
  State<AdminActivityJournalPage> createState() =>
      _AdminActivityJournalPageState();
}

class _AdminActivityJournalPageState extends State<AdminActivityJournalPage> {
  final TextEditingController _searchController = TextEditingController();
  _JournalFilter _filter = _JournalFilter.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        title: const Text('Journal d’activité'),
        backgroundColor: IzyTelColors.background,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<QueueOrder>>(
          stream: widget.orderHistoryRepository.watchOrderHistory(),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<QueueOrder>> ordersSnapshot,
          ) {
            return StreamBuilder<List<SupportRequest>>(
              stream: widget.supportRequestRepository.watchAllRequests(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<SupportRequest>> requestSnapshot,
              ) {
                if (ordersSnapshot.hasError && requestSnapshot.hasError) {
                  return IzyTelEmptyState(
                    icon: Symbols.cloud_off_rounded,
                    title: 'Journal indisponible',
                    message:
                        'Impossible de charger l’activité opérationnelle pour le moment.',
                    actionLabel: 'Réessayer',
                    onAction: () => setState(() {}),
                  );
                }

                final bool loading =
                    ordersSnapshot.connectionState == ConnectionState.waiting &&
                    requestSnapshot.connectionState == ConnectionState.waiting;
                if (loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<_JournalEntry> entries = <_JournalEntry>[
                  ...?ordersSnapshot.data?.map(_JournalEntry.fromOrder),
                  ...?requestSnapshot.data?.map(_JournalEntry.fromRequest),
                ]..sort(
                    (_JournalEntry a, _JournalEntry b) =>
                        b.date.compareTo(a.date),
                  );

                final List<_JournalEntry> visible = entries.where((entry) {
                  if (_filter == _JournalFilter.orders &&
                      entry.kind != _JournalEntryKind.order) {
                    return false;
                  }
                  if (_filter == _JournalFilter.requests &&
                      entry.kind != _JournalEntryKind.request) {
                    return false;
                  }
                  final String query = _query.trim().toLowerCase();
                  if (query.isEmpty) return true;
                  return entry.searchable.contains(query);
                }).toList(growable: false);

                final int orderCount = entries
                    .where((entry) => entry.kind == _JournalEntryKind.order)
                    .length;
                final int requestCount = entries
                    .where((entry) => entry.kind == _JournalEntryKind.request)
                    .length;

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: IzyTelColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      const IzyTelPageHeader(
                        title: 'Activité récente',
                        subtitle:
                            'Vue synthétique des dernières évolutions. L’audit détaillé reste disponible dans chaque commande.',
                      ),
                      const SizedBox(height: IzyTelSpacing.lg),
                      IzyTelSearchField(
                        controller: _searchController,
                        hintText: 'Référence, client, numéro…',
                        onChanged: (String value) {
                          setState(() => _query = value);
                        },
                      ),
                      const SizedBox(height: IzyTelSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            IzyTelFilterPill(
                              label: 'Tout',
                              count: entries.length,
                              selected: _filter == _JournalFilter.all,
                              onTap: () => setState(
                                () => _filter = _JournalFilter.all,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IzyTelFilterPill(
                              label: 'Commandes',
                              count: orderCount,
                              selected: _filter == _JournalFilter.orders,
                              selectedColor: IzyTelColors.primary,
                              softColor: IzyTelColors.primarySoft,
                              onTap: () => setState(
                                () => _filter = _JournalFilter.orders,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IzyTelFilterPill(
                              label: 'Demandes',
                              count: requestCount,
                              selected: _filter == _JournalFilter.requests,
                              selectedColor: IzyTelColors.warning,
                              softColor: IzyTelColors.warningSoft,
                              onTap: () => setState(
                                () => _filter = _JournalFilter.requests,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: IzyTelSpacing.lg),
                      if (visible.isEmpty)
                        const IzyTelSurface(
                          child: IzyTelEmptyState(
                            icon: Symbols.history_rounded,
                            title: 'Aucune activité',
                            message:
                                'Aucun élément ne correspond à la recherche ou au filtre actuel.',
                          ),
                        )
                      else
                        ...visible.take(80).map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _JournalEntryCard(entry: entry),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

enum _JournalEntryKind { order, request }

class _JournalEntry {
  const _JournalEntry({
    required this.kind,
    required this.title,
    required this.reference,
    required this.subtitle,
    required this.date,
    required this.color,
    required this.softColor,
    required this.icon,
    required this.searchable,
  });

  factory _JournalEntry.fromOrder(QueueOrder order) {
    final DateTime activityAt = <DateTime?>[
      order.completedAt,
      order.customerConfirmationCompletedAt,
      order.lastResumedAt,
      order.lastHeldAt,
      order.takenAt,
      order.assignedAt,
      order.paymentConfirmedAt,
      order.paymentDeclaredAt,
      order.createdAt,
    ].whereType<DateTime>().reduce(
      (DateTime a, DateTime b) => a.isAfter(b) ? a : b,
    );
    final String status = _orderStatusLabel(order.status);
    return _JournalEntry(
      kind: _JournalEntryKind.order,
      title: '$status · ${_networkLabel(order.network)}',
      reference: order.reference,
      subtitle:
          '${order.clientName} · ${_formatPhone(order.beneficiaryPhone)} · ${_formatMoney(order.amount)}',
      date: activityAt,
      color: _orderStatusColor(order.status),
      softColor: _orderStatusSoftColor(order.status),
      icon: Symbols.receipt_long_rounded,
      searchable: <String>[
        order.reference,
        order.clientName,
        order.clientWhatsappPhone,
        order.beneficiaryPhone,
        order.offerLabel,
        _networkLabel(order.network),
        status,
      ].join(' ').toLowerCase(),
    );
  }

  factory _JournalEntry.fromRequest(SupportRequest request) {
    return _JournalEntry(
      kind: _JournalEntryKind.request,
      title: request.type.label,
      reference: request.orderReference,
      subtitle: request.status.label,
      date: request.updatedAt,
      color: _requestColor(request.status),
      softColor: _requestSoftColor(request.status),
      icon: Symbols.support_agent_rounded,
      searchable: <String>[
        request.orderReference,
        request.type.label,
        request.description,
        request.status.label,
      ].join(' ').toLowerCase(),
    );
  }

  final _JournalEntryKind kind;
  final String title;
  final String reference;
  final String subtitle;
  final DateTime date;
  final Color color;
  final Color softColor;
  final IconData icon;
  final String searchable;
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry});

  final _JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entry.softColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: entry.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: IzyTelColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _relativeTime(entry.date),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IzyTelColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  entry.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onLongPress: () async {
                    await Clipboard.setData(
                      ClipboardData(text: entry.reference),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('Référence copiée.')),
                      );
                  },
                  child: Text(
                    entry.reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: IzyTelColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
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

String _relativeTime(DateTime value) {
  final Duration delta = DateTime.now().difference(value);
  if (delta.isNegative || delta.inMinutes <= 0) return 'À l’instant';
  if (delta.inMinutes < 60) return 'Il y a ${delta.inMinutes} min';
  if (delta.inHours < 24) return 'Il y a ${delta.inHours} h';
  if (delta.inDays < 7) return 'Il y a ${delta.inDays} j';
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatPhone(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  String local = digits;
  if (digits.startsWith('225') && digits.length >= 13) {
    local = digits.substring(3);
  }
  if (local.length == 10) {
    final List<String> groups = <String>[];
    for (int i = 0; i < 10; i += 2) {
      groups.add(local.substring(i, i + 2));
    }
    return '+225 ${groups.join(' ')}';
  }
  return raw;
}

String _formatMoney(int amount) {
  final String value = amount.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    if (i > 0 && (value.length - i) % 3 == 0) out.write(' ');
    out.write(value[i]);
  }
  return '${out.toString()} F';
}

String _networkLabel(MobileNetwork network) => switch (network) {
  MobileNetwork.orange => 'Orange',
  MobileNetwork.mtn => 'MTN',
  MobileNetwork.moov => 'Moov',
};

String _orderStatusLabel(QueueOrderStatus status) => switch (status) {
  QueueOrderStatus.awaitingPayment => 'Paiement attendu',
  QueueOrderStatus.paymentToVerify => 'Paiement à vérifier',
  QueueOrderStatus.paidReady => 'Prête à traiter',
  QueueOrderStatus.inProgress => 'En traitement',
  QueueOrderStatus.onHold => 'En attente',
  QueueOrderStatus.awaitingCustomerConfirmation => 'Confirmation client',
  QueueOrderStatus.completed => 'Terminée',
  QueueOrderStatus.failed => 'Échec',
  QueueOrderStatus.expired => 'Expirée',
  QueueOrderStatus.cancelled => 'Annulée',
  QueueOrderStatus.refundPending => 'Remboursement en cours',
  QueueOrderStatus.refunded => 'Remboursée',
};

Color _orderStatusColor(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.completed:
    case QueueOrderStatus.refunded:
      return IzyTelColors.success;
    case QueueOrderStatus.failed:
    case QueueOrderStatus.cancelled:
      return IzyTelColors.error;
    case QueueOrderStatus.paymentToVerify:
    case QueueOrderStatus.onHold:
    case QueueOrderStatus.expired:
    case QueueOrderStatus.refundPending:
      return IzyTelColors.warning;
    default:
      return IzyTelColors.primary;
  }
}

Color _orderStatusSoftColor(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.completed:
    case QueueOrderStatus.refunded:
      return IzyTelColors.successSoft;
    case QueueOrderStatus.failed:
    case QueueOrderStatus.cancelled:
      return IzyTelColors.errorSoft;
    case QueueOrderStatus.paymentToVerify:
    case QueueOrderStatus.onHold:
    case QueueOrderStatus.expired:
    case QueueOrderStatus.refundPending:
      return IzyTelColors.warningSoft;
    default:
      return IzyTelColors.primarySoft;
  }
}

Color _requestColor(SupportRequestStatus status) => switch (status) {
  SupportRequestStatus.newRequest => IzyTelColors.warning,
  SupportRequestStatus.inProgress => IzyTelColors.primary,
  SupportRequestStatus.resolved => IzyTelColors.success,
  SupportRequestStatus.closed => IzyTelColors.textSecondary,
};

Color _requestSoftColor(SupportRequestStatus status) => switch (status) {
  SupportRequestStatus.newRequest => IzyTelColors.warningSoft,
  SupportRequestStatus.inProgress => IzyTelColors.primarySoft,
  SupportRequestStatus.resolved => IzyTelColors.successSoft,
  SupportRequestStatus.closed => IzyTelColors.surfaceMuted,
};
