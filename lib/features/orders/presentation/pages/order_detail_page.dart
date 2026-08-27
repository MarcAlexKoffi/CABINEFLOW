import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    super.key,
    required this.user,
    required this.initialOrder,
    required this.ordersRepository,
    required this.onBack,
    required this.onOpenCustomerHistory,
    this.supportRequestRepository,
  });

  final AppUser user;
  final QueueOrder initialOrder;
  final OrderHistoryRepository ordersRepository;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenCustomerHistory;
  final SupportRequestRepository? supportRequestRepository;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late QueueOrder _order;
  bool _isRefreshing = false;
  String? _errorMessage;
  late final SupportRequestRepository _supportRequestRepository;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _supportRequestRepository =
        widget.supportRequestRepository ??
        (Firebase.apps.isNotEmpty
            ? FirestoreSupportRequestRepository()
            : FakeSupportRequestRepository());
    _refreshOrder(showLoader: false);
  }

  Future<void> _refreshOrder({bool showLoader = true}) async {
    if (_isRefreshing) {
      return;
    }

    if (showLoader) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final QueueOrder updatedOrder = await widget.ordersRepository
          .fetchOrderById(orderId: _order.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _order = updatedOrder;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Impossible d’actualiser cette commande.';
      });
    } finally {
      if (mounted && showLoader) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _copyValue(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copié.')));
  }

  String get _normalizedWhatsappPhone {
    final String digits = _order.clientWhatsappPhone.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.startsWith('225')) {
      return digits;
    }

    if (digits.startsWith('0')) {
      return '225$digits';
    }

    return digits;
  }

  Future<void> _openWhatsapp() async {
    final String phone = _normalizedWhatsappPhone;
    if (phone.isEmpty) {
      _showMessage('Aucun numéro WhatsApp n’est enregistré.');
      return;
    }

    final String message =
        'Bonjour ${_order.clientName}, je vous contacte au sujet de votre commande CabineFlow ${_order.reference}.';
    final Uri uri = Uri.https('wa.me', '/$phone', <String, String>{
      'text': message,
    });

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && mounted) {
      _showMessage('Impossible d’ouvrir WhatsApp.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _operatorLabel(String? operatorId) {
    final String cleaned = operatorId?.trim() ?? '';
    if (cleaned.isEmpty) {
      return 'Non attribué';
    }
    return cleaned == widget.user.id
        ? widget.user.name
        : compactOperatorLabel(cleaned);
  }

  String _processingDurationLabel() {
    final DateTime? startedAt = _order.takenAt;
    if (startedAt == null) {
      return 'Non démarré';
    }

    final DateTime endingAt = _order.completedAt ?? DateTime.now();
    final Duration duration = endingAt.difference(startedAt);
    if (duration.isNegative) {
      return 'Non disponible';
    }

    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }

    if (minutes > 0) {
      return '${minutes}min ${seconds}s';
    }

    return '${seconds}s';
  }

  List<_TimelineEntry> _timelineEntries() {
    final List<_TimelineEntry> entries = <_TimelineEntry>[
      _TimelineEntry(
        label: 'Commande créée',
        date: _order.createdAt,
        note: orderSourceLabel(_order.source),
      ),
    ];

    void add(String label, DateTime? date, String note) {
      if (date != null) {
        entries.add(_TimelineEntry(label: label, date: date, note: note));
      }
    }

    add(
      'Lien de paiement préparé',
      _order.paymentRequestSentAt,
      'Paiement Wave demandé',
    );
    add(
      'Paiement déclaré',
      _order.paymentDeclaredAt,
      _order.paymentPayerName ?? 'Déclaration client',
    );
    add(
      'Paiement confirmé',
      _order.paymentConfirmedAt ?? _order.paidAt,
      _order.paymentReference ?? 'Confirmation manuelle',
    );
    add(
      'Commande affectée',
      _order.assignedAt,
      _order.assignedAgentName ?? 'Agent affecté',
    );
    add(
      'Commande prise en charge',
      _order.takenAt,
      _operatorLabel(_order.takenByUserId),
    );
    add(
      orderStatusLabel(_order.status),
      _order.completedAt,
      _order.observation ?? 'Traitement enregistré',
    );
    add(
      'Retour client clôturé',
      _order.customerConfirmationCompletedAt,
      confirmationStatusLabel(_order.customerConfirmationStatus),
    );
    add('Commande expirée', _order.expiredAt, 'Délai de paiement dépassé');

    entries.sort((_TimelineEntry first, _TimelineEntry second) {
      return first.date.compareTo(second.date);
    });
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = orderStatusColor(_order.status);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _DetailTopBar(
            onBack: widget.onBack,
            onRefresh: () => _refreshOrder(),
            isRefreshing: _isRefreshing,
          ),
          Divider(height: 1, color: AppColors.outlineVariant.withAlpha(80)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshOrder,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  const Text(
                    'DÉTAIL DE LA COMMANDE',
                    style: TextStyle(
                      color: AppColors.primaryContainer,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '#${_order.reference}',
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copier la référence',
                        onPressed: () =>
                            _copyValue(_order.reference, 'Référence'),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainerHighest,
                        ),
                        icon: const Icon(
                          Icons.content_copy_rounded,
                          size: 19,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withAlpha(120)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              orderStatusIcon(_order.status),
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              orderStatusLabel(_order.status),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatOrderDateTime(_order.createdAt),
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withAlpha(90),
                        ),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _OrderSummaryCard(order: _order, onCopy: _copyValue),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.person_outline_rounded,
                    title: 'Client',
                    child: Column(
                      children: [
                        _ClientIdentityCard(order: _order),
                        if (_order.customerAuthUid?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 10),
                          _DetailRow(
                            label: 'Identifiant client',
                            value: _order.customerAuthUid!,
                            showDivider: false,
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _openWhatsapp,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success.withAlpha(180),
                            minimumSize: const Size.fromHeight(45),
                          ),
                          icon: const Icon(Icons.chat_rounded, size: 19),
                          label: const Text('Ouvrir WhatsApp'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            widget.onOpenCustomerHistory(
                              _order.clientWhatsappPhone,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onBackground,
                            minimumSize: const Size.fromHeight(45),
                            side: BorderSide(
                              color: AppColors.outlineVariant.withAlpha(100),
                            ),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 19),
                          label: const Text('Historique du client'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.report_problem_outlined,
                    title: 'Demandes de vérification',
                    child: _OrderSupportRequests(
                      orderId: _order.id,
                      repository: _supportRequestRepository,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Paiement',
                    trailing: _SmallStatusBadge(
                      label: paymentStatusLabel(_order.paymentStatus),
                      color:
                          _order.paymentStatus == OrderPaymentStatus.confirmed
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Payeur',
                          value: _order.paymentPayerName ?? _order.clientName,
                        ),
                        _DetailRow(
                          label: 'Numéro payeur',
                          value: _order.paymentPayerPhone == null
                              ? 'Non renseigné'
                              : formatIvorianPhone(_order.paymentPayerPhone!),
                        ),
                        _DetailRow(
                          label: 'Montant reçu',
                          value:
                              _order.paymentStatus ==
                                  OrderPaymentStatus.confirmed
                              ? formatCfa(_order.amount)
                              : 'Non confirmé',
                          valueColor:
                              _order.paymentStatus ==
                                  OrderPaymentStatus.confirmed
                              ? AppColors.success
                              : AppColors.onBackground,
                        ),
                        _DetailRow(
                          label: 'Heure déclarée',
                          value:
                              _order.paymentApproximateTime ??
                              formatOrderTime(_order.paymentDeclaredAt),
                        ),
                        _DetailRow(
                          label: 'Référence déclarée',
                          value:
                              _order.paymentDeclaredReference ??
                              'Non renseignée',
                        ),
                        _DetailRow(
                          label: 'Référence confirmée',
                          value: _order.paymentReference ?? 'Non renseignée',
                          canCopy: _order.paymentReference != null,
                          onCopy: _order.paymentReference == null
                              ? null
                              : () => _copyValue(
                                  _order.paymentReference!,
                                  'Référence de paiement',
                                ),
                        ),
                        _DetailRow(
                          label: 'Confirmation',
                          value: _order.paymentConfirmedAt == null
                              ? 'Non confirmée'
                              : formatOrderDateTime(_order.paymentConfirmedAt!),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.settings_suggest_outlined,
                    title: 'Traitement',
                    child: Column(
                      children: [
                        _DetailRow(
                          label: 'Agent affecté',
                          value: _order.assignedAgentName ?? 'Non affectée',
                        ),
                        _DetailRow(
                          label: 'Mode d’affectation',
                          value: _order.assignmentMode == null
                              ? 'Non renseigné'
                              : (_order.assignmentMode ==
                                        OrderAssignmentMode.manual
                                    ? 'Manuelle'
                                    : 'Automatique'),
                        ),
                        _DetailRow(
                          label: 'Date d’affectation',
                          value: _order.assignedAt == null
                              ? 'Non affectée'
                              : formatOrderDateTime(_order.assignedAt!),
                        ),
                        _DetailRow(
                          label: 'Opérateur responsable',
                          value: _operatorLabel(_order.takenByUserId),
                        ),
                        _DetailRow(
                          label: 'Prise en charge',
                          value: _order.takenAt == null
                              ? 'Non prise en charge'
                              : formatOrderDateTime(_order.takenAt!),
                        ),
                        _DetailRow(
                          label: 'Fin du traitement',
                          value: _order.completedAt == null
                              ? 'Non terminée'
                              : formatOrderDateTime(_order.completedAt!),
                        ),
                        _DetailRow(
                          label: 'Durée',
                          value: _processingDurationLabel(),
                        ),
                        _DetailRow(
                          label: 'Résultat',
                          value: orderStatusLabel(_order.status),
                          valueColor: statusColor,
                        ),
                        if (_order.failureReason != null)
                          _DetailRow(
                            label: 'Motif d’échec',
                            value: failureReasonLabel(_order.failureReason),
                          ),
                        _DetailRow(
                          label: 'Observation',
                          value: _order.observation ?? 'Aucune observation',
                        ),
                        _DetailRow(
                          label: 'Retour WhatsApp',
                          value: confirmationStatusLabel(
                            _order.customerConfirmationStatus,
                          ),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.timeline_rounded,
                    title: 'Chronologie',
                    child: _Timeline(entries: _timelineEntries()),
                  ),
                  if (_order.internalNotes?.trim().isNotEmpty == true ||
                      _order.originalWhatsappMessage?.trim().isNotEmpty ==
                          true) ...[
                    const SizedBox(height: 16),
                    _DetailSection(
                      icon: Icons.notes_rounded,
                      title: 'Notes',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_order.internalNotes?.trim().isNotEmpty == true)
                            _TextBlock(
                              label: 'Note interne',
                              value: _order.internalNotes!,
                            ),
                          if (_order.originalWhatsappMessage
                                  ?.trim()
                                  .isNotEmpty ==
                              true) ...[
                            if (_order.internalNotes?.trim().isNotEmpty == true)
                              const SizedBox(height: 12),
                            _TextBlock(
                              label: 'Message WhatsApp original',
                              value: _order.originalWhatsappMessage!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSupportRequests extends StatelessWidget {
  const _OrderSupportRequests({
    required this.orderId,
    required this.repository,
  });

  final String orderId;
  final SupportRequestRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SupportRequest>>(
      stream: repository.watchForOrder(orderId: orderId),
      builder:
          (BuildContext context, AsyncSnapshot<List<SupportRequest>> snapshot) {
            if (snapshot.hasError) {
              return const _SupportRequestInfo(
                icon: Icons.error_outline_rounded,
                message: 'Impossible de charger les demandes client.',
                color: AppColors.error,
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final List<SupportRequest> requests = snapshot.data!;
            if (requests.isEmpty) {
              return const _SupportRequestInfo(
                icon: Icons.check_circle_outline_rounded,
                message: 'Aucune demande de vérification pour cette commande.',
                color: AppColors.success,
              );
            }

            return Column(
              children: [
                for (int index = 0; index < requests.length; index++) ...[
                  _SupportRequestTile(request: requests[index]),
                  if (index != requests.length - 1)
                    Divider(
                      height: 18,
                      color: AppColors.outlineVariant.withAlpha(70),
                    ),
                ],
              ],
            );
          },
    );
  }
}

class _SupportRequestTile extends StatelessWidget {
  const _SupportRequestTile({required this.request});

  final SupportRequest request;

  Color get _statusColor {
    switch (request.status) {
      case SupportRequestStatus.newRequest:
        return AppColors.warning;
      case SupportRequestStatus.inProgress:
        return AppColors.primaryContainer;
      case SupportRequestStatus.resolved:
        return AppColors.success;
      case SupportRequestStatus.closed:
        return AppColors.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                request.type.label,
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _SmallStatusBadge(label: request.status.label, color: _statusColor),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          formatOrderDateTime(request.createdAt),
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        if (request.description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              request.description,
              style: const TextStyle(
                color: AppColors.onBackground,
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SupportRequestInfo extends StatelessWidget {
  const _SupportRequestInfo({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  const _DetailTopBar({
    required this.onBack,
    required this.onRefresh,
    required this.isRefreshing,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour à l’historique',
            onPressed: onBack,
            color: AppColors.primaryContainer,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Icon(
            Icons.receipt_long_outlined,
            color: AppColors.primaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'CabineFlow',
              style: TextStyle(
                color: AppColors.onBackground,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: isRefreshing ? null : onRefresh,
            color: AppColors.onBackground,
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.onCopy});

  final QueueOrder order;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    final Color color = networkColor(order.network);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withAlpha(115)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      operationTypeLabel(order.operationType),
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.offerLabel,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  networkAsset(order.network),
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.outlineVariant.withAlpha(65)),
            ),
            child: Column(
              children: [
                _SummaryLine(
                  label: 'Réseau',
                  value: networkLabel(order.network),
                ),
                _SummaryLine(
                  label: 'Montant',
                  value: formatCfa(order.amount),
                  valueColor: AppColors.primaryContainer,
                ),
                _SummaryLine(
                  label: 'Bénéficiaire',
                  value: formatIvorianPhone(order.beneficiaryPhone),
                  canCopy: true,
                  onCopy: () =>
                      onCopy(order.beneficiaryPhone, 'Numéro bénéficiaire'),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.valueColor = AppColors.onBackground,
    this.canCopy = false,
    this.onCopy,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool canCopy;
  final VoidCallback? onCopy;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 86,
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canCopy)
                IconButton(
                  tooltip: 'Copier',
                  onPressed: onCopy,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.content_copy_rounded,
                    size: 16,
                    color: AppColors.primaryContainer,
                  ),
                ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.outlineVariant.withAlpha(55)),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryContainer, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ClientIdentityCard extends StatelessWidget {
  const _ClientIdentityCard({required this.order});

  final QueueOrder order;

  String get initials {
    final List<String> parts = order.clientName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primaryContainer,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clientName,
                  style: const TextStyle(
                    color: AppColors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatIvorianPhone(order.clientWhatsappPhone),
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  orderSourceLabel(order.source),
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor = AppColors.onBackground,
    this.showDivider = true,
    this.canCopy = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool showDivider;
  final bool canCopy;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              if (canCopy) ...[
                const SizedBox(width: 5),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.content_copy_rounded,
                      size: 14,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: AppColors.outlineVariant.withAlpha(50)),
      ],
    );
  }
}

class _SmallStatusBadge extends StatelessWidget {
  const _SmallStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<_TimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(entries.length, (int index) {
        final _TimelineEntry entry = entries[index];
        final bool isLast = index == entries.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 52,
                      color: AppColors.outlineVariant.withAlpha(120),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: const TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatOrderDateTime(entry.date),
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.note,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.label,
    required this.date,
    required this.note,
  });

  final String label;
  final DateTime date;
  final String note;
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryContainer,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
