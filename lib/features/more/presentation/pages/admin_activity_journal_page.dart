import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/order_detail_page.dart';
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
    required this.user,
    required this.orderHistoryRepository,
    required this.supportRequestRepository,
  });

  final AppUser user;
  final OrderHistoryRepository orderHistoryRepository;
  final SupportRequestRepository supportRequestRepository;

  @override
  State<AdminActivityJournalPage> createState() =>
      _AdminActivityJournalPageState();
}

class _AdminActivityJournalPageState extends State<AdminActivityJournalPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<QueueOrder>> _ordersStream;
  late final Stream<List<SupportRequest>> _requestsStream;
  _JournalFilter _filter = _JournalFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _ordersStream = widget.orderHistoryRepository.watchOrderHistory();
    _requestsStream = widget.supportRequestRepository.watchAllRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEntry(_JournalEntry entry) async {
    if (entry.order != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) {
            return OrderDetailPage(
              user: widget.user,
              initialOrder: entry.order!,
              ordersRepository: widget.orderHistoryRepository,
              supportRequestRepository: widget.supportRequestRepository,
              onBack: () => Navigator.of(context).pop(),
              onOpenCustomerHistory: (_) {},
            );
          },
        ),
      );
      return;
    }

    if (entry.request != null) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          return _SupportRequestActivitySheet(request: entry.request!);
        },
      );
    }
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
          stream: _ordersStream,
          builder: (BuildContext context, AsyncSnapshot<List<QueueOrder>> ordersSnapshot) {
            return StreamBuilder<List<SupportRequest>>(
              stream: _requestsStream,
              builder:
                  (
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
                        ordersSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        requestSnapshot.connectionState ==
                            ConnectionState.waiting;
                    if (loading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<_JournalEntry> entries =
                        <_JournalEntry>[
                          ...?ordersSnapshot.data?.map(_JournalEntry.fromOrder),
                          ...?requestSnapshot.data?.map(
                            _JournalEntry.fromRequest,
                          ),
                        ]..sort(
                          (_JournalEntry a, _JournalEntry b) =>
                              b.date.compareTo(a.date),
                        );

                    final List<_JournalEntry> visible = entries
                        .where((entry) {
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
                        })
                        .toList(growable: false);

                    final int orderCount = entries
                        .where((entry) => entry.kind == _JournalEntryKind.order)
                        .length;
                    final int requestCount = entries
                        .where(
                          (entry) => entry.kind == _JournalEntryKind.request,
                        )
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
                            ...visible
                                .take(80)
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _JournalEntryCard(
                                      entry: entry,
                                      onTap: () => _openEntry(entry),
                                    ),
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
    required this.actionLabel,
    this.order,
    this.request,
  });

  factory _JournalEntry.fromOrder(QueueOrder order) {
    final DateTime activityAt =
        <DateTime?>[
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
      actionLabel: 'Ouvrir',
      order: order,
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
      actionLabel: 'Voir',
      request: request,
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
  final String actionLabel;
  final QueueOrder? order;
  final SupportRequest? request;
}

class _JournalEntryCard extends StatelessWidget {
  const _JournalEntryCard({required this.entry, required this.onTap});

  final _JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
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
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onLongPress: () async {
                          await Clipboard.setData(
                            ClipboardData(text: entry.reference),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              const SnackBar(
                                content: Text('Référence copiée.'),
                              ),
                            );
                        },
                        child: Text(
                          entry.reference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: IzyTelColors.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.actionLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: entry.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportRequestActivitySheet extends StatelessWidget {
  const _SupportRequestActivitySheet({required this.request});

  final SupportRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(IzyTelSpacing.lg),
      decoration: const BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.all(Radius.circular(IzyTelRadii.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Détail de la demande',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: IzyTelColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Symbols.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              IzyTelStatusPill(
                label: request.type.label,
                color: _requestColor(request.status),
              ),
              IzyTelStatusPill(
                label: request.status.label,
                color: _requestColor(request.status),
              ),
            ],
          ),
          const SizedBox(height: IzyTelSpacing.lg),
          _RequestDetailLine(
            label: 'Référence commande',
            value: request.orderReference,
          ),
          const SizedBox(height: IzyTelSpacing.md),
          _RequestDetailLine(label: 'Description', value: request.description),
          if (request.assignedToName != null) ...[
            const SizedBox(height: IzyTelSpacing.md),
            _RequestDetailLine(
              label: 'Prise en charge',
              value: request.assignedToName!,
            ),
          ],
          if (request.resolvedByName != null) ...[
            const SizedBox(height: IzyTelSpacing.md),
            _RequestDetailLine(
              label: 'Résolution',
              value: request.resolvedByName!,
            ),
          ],
          const SizedBox(height: IzyTelSpacing.md),
          _RequestDetailLine(
            label: 'Dernière mise à jour',
            value: _relativeTime(request.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _RequestDetailLine extends StatelessWidget {
  const _RequestDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: IzyTelColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: IzyTelColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
