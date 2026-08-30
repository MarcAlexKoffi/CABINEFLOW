import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/audit/data/repositories/fake_order_audit_repository.dart';
import 'package:cabine_flow/features/audit/data/repositories/firestore_order_audit_repository.dart';
import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';
import 'package:cabine_flow/features/audit/domain/repositories/order_audit_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/order_proof.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
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
    this.auditRepository,
  });

  final AppUser user;
  final QueueOrder initialOrder;
  final OrderHistoryRepository ordersRepository;
  final VoidCallback onBack;
  final ValueChanged<String> onOpenCustomerHistory;
  final SupportRequestRepository? supportRequestRepository;
  final OrderAuditRepository? auditRepository;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late QueueOrder _order;
  OrderProof? _proof;
  bool _isRefreshing = false;
  bool _isProofLoading = false;
  String? _errorMessage;
  late final SupportRequestRepository _supportRequestRepository;
  late final OrderAuditRepository _auditRepository;

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _supportRequestRepository =
        widget.supportRequestRepository ??
        (Firebase.apps.isNotEmpty
            ? FirestoreSupportRequestRepository()
            : FakeSupportRequestRepository());
    _auditRepository =
        widget.auditRepository ??
        (Firebase.apps.isNotEmpty
            ? FirestoreOrderAuditRepository(
                includeRefundEvents: widget.user.role == UserRole.administrator,
              )
            : FakeOrderAuditRepository());
    _refreshAll(showLoader: false);
  }

  Future<void> _refreshAll({bool showLoader = true}) async {
    await Future.wait(<Future<void>>[
      _refreshOrder(showLoader: showLoader),
      _loadProof(),
    ]);
  }

  Future<void> _loadProof() async {
    final OrdersRepository? repository = widget.ordersRepository is OrdersRepository
        ? widget.ordersRepository as OrdersRepository
        : null;
    if (repository == null) {
      return;
    }

    if (mounted) {
      setState(() => _isProofLoading = true);
    }

    try {
      final OrderProof? proof = await repository.fetchOrderProof(
        orderId: _order.id,
      );
      if (!mounted) return;
      setState(() => _proof = proof);
    } catch (_) {
      // Une preuve absente ou momentanément indisponible ne doit pas bloquer
      // l'affichage du détail de commande.
    } finally {
      if (mounted) {
        setState(() => _isProofLoading = false);
      }
    }
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
        'Bonjour ${_order.clientName}, je vous contacte au sujet de votre commande IzyTel ${_order.reference}.';
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

  String get _refundLabel {
    switch (_order.status) {
      case QueueOrderStatus.refundPending:
        return 'En attente';
      case QueueOrderStatus.refunded:
        return 'Remboursée';
      default:
        return 'Aucun';
    }
  }

  Color get _refundColor {
    switch (_order.status) {
      case QueueOrderStatus.refundPending:
        return IzyTelColors.warning;
      case QueueOrderStatus.refunded:
        return IzyTelColors.success;
      default:
        return IzyTelColors.textMuted;
    }
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

  @override
  Widget build(BuildContext context) {
    final Color statusColor = orderStatusColor(_order.status);

    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DetailTopBar(
              onBack: widget.onBack,
              onRefresh: () => _refreshAll(),
              onCopyReference: () => _copyValue(_order.reference, 'Référence'),
              isRefreshing: _isRefreshing,
            ),
            const Divider(height: 1, color: IzyTelColors.outline),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshAll,
                color: IzyTelColors.primary,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                  children: [
                    _OrderSummaryCard(order: _order, onCopy: _copyValue),
                    const SizedBox(height: 18),
                    _OrderProgressTimeline(order: _order),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: IzyTelColors.errorSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Symbols.error_rounded,
                              color: IzyTelColors.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: IzyTelColors.error,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _DetailGroup(
                      children: [
                        _DetailSection(
                          icon: Symbols.person_rounded,
                          title: 'Client',
                          child: Column(
                            children: [
                              _ClientIdentityCard(order: _order),
                              if (_order.customerAuthUid?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: IzyTelSpacing.sm),
                                _DetailRow(
                                  label: 'Identifiant technique',
                                  value: _order.customerAuthUid!,
                                  canCopy: true,
                                  onCopy: () => _copyValue(
                                    _order.customerAuthUid!,
                                    'Identifiant technique',
                                  ),
                                  showDivider: false,
                                ),
                              ],
                              const SizedBox(height: IzyTelSpacing.md),
                              Row(
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: OutlinedButton.icon(
                                      onPressed: _openWhatsapp,
                                      icon: Image.asset(
                                        'assets/images/whatsapp_logo.png',
                                        width: 20,
                                        height: 20,
                                      ),
                                      label: const Text('WhatsApp'),
                                    ),
                                  ),
                                  const SizedBox(width: IzyTelSpacing.sm),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          widget.onOpenCustomerHistory(
                                        _order.clientWhatsappPhone,
                                      ),
                                      icon: const Icon(
                                        Symbols.history_rounded,
                                        size: IzyTelIconSize.info,
                                      ),
                                      label: const Text('Historique'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _DetailSection(
                          icon: Symbols.wallet_rounded,
                          title: 'Paiement',
                          trailing: _SmallStatusBadge(
                            label: paymentStatusLabel(_order.paymentStatus),
                            color:
                                _order.paymentStatus ==
                                    OrderPaymentStatus.confirmed
                                ? IzyTelColors.success
                                : IzyTelColors.warning,
                          ),
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Payeur',
                                value:
                                    _order.paymentPayerName ?? _order.clientName,
                              ),
                              _DetailRow(
                                label: 'Numéro payeur',
                                value: _order.paymentPayerPhone == null
                                    ? 'Non renseigné'
                                    : formatIvorianPhone(
                                        _order.paymentPayerPhone!,
                                      ),
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
                                    ? IzyTelColors.success
                                    : IzyTelColors.textPrimary,
                              ),
                              _DetailRow(
                                label: 'Référence confirmée',
                                value:
                                    _order.paymentReference ?? 'Non renseignée',
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
                                    : formatOrderDateTime(
                                        _order.paymentConfirmedAt!,
                                      ),
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                        _DetailSection(
                          icon: Symbols.receipt_long_rounded,
                          title: 'Détails de l’offre',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Service',
                                value: operationTypeLabel(_order.operationType),
                              ),
                              _DetailRow(
                                label: 'Offre',
                                value: _order.offerLabel,
                              ),
                              _DetailRow(
                                label: 'Réseau',
                                value: networkLabel(_order.network),
                              ),
                              _DetailRow(
                                label: 'Bénéficiaire',
                                value: formatIvorianPhone(
                                  _order.beneficiaryPhone,
                                ),
                                valueColor: IzyTelColors.primaryStrong,
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                        _DetailSection(
                          icon: Symbols.image_rounded,
                          title: 'Preuve',
                          trailing: _proof == null
                              ? null
                              : const _SmallStatusBadge(
                                  label: 'Ajoutée',
                                  color: IzyTelColors.success,
                                ),
                          child: _ProofSectionContent(
                            proof: _proof,
                            isLoading: _isProofLoading,
                          ),
                        ),
                        _DetailSection(
                          icon: Symbols.autorenew_rounded,
                          title: 'Traitement',
                          child: Column(
                            children: [
                              _DetailRow(
                                label: 'Agent affecté',
                                value:
                                    _order.assignedAgentName ?? 'Non affectée',
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
                                label: 'Prise en charge',
                                value: _order.takenAt == null
                                    ? 'Non prise en charge'
                                    : formatOrderDateTime(_order.takenAt!),
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
                                  value: failureReasonLabel(
                                    _order.failureReason,
                                  ),
                                ),
                              _DetailRow(
                                label: 'Observation',
                                value:
                                    _order.observation ?? 'Aucune observation',
                                showDivider: false,
                              ),
                            ],
                          ),
                        ),
                        _DetailSection(
                          icon: Symbols.history_rounded,
                          title: 'Journal d’activité',
                          trailing: const _SmallStatusBadge(
                            label: 'Temps réel',
                            color: IzyTelColors.primary,
                          ),
                          child: _OrderAuditTimeline(
                            orderId: _order.id,
                            repository: _auditRepository,
                            includesRefunds:
                                widget.user.role == UserRole.administrator,
                          ),
                        ),
                        _DetailSection(
                          icon: Symbols.chat_bubble_rounded,
                          title: 'Demandes client',
                          child: _OrderSupportRequests(
                            orderId: _order.id,
                            repository: _supportRequestRepository,
                          ),
                        ),
                        if (widget.user.role == UserRole.administrator)
                          _DetailSection(
                            icon: Symbols.payments_rounded,
                            title: 'Remboursement',
                            trailing: _SmallStatusBadge(
                              label: _refundLabel,
                              color: _refundColor,
                            ),
                            child: _RefundSectionContent(order: _order),
                          ),
                      ],
                    ),
                    if (_order.internalNotes?.trim().isNotEmpty == true ||
                        _order.originalWhatsappMessage?.trim().isNotEmpty ==
                            true) ...[
                      const SizedBox(height: 10),
                      _DetailGroup(
                        children: [
                          _DetailSection(
                            icon: Symbols.receipt_long_rounded,
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
                                  if (_order.internalNotes?.trim().isNotEmpty ==
                                      true)
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
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderProgressTimeline extends StatelessWidget {
  const _OrderProgressTimeline({required this.order});

  final QueueOrder order;

  bool get _paid => order.paymentStatus == OrderPaymentStatus.confirmed;
  bool get _assigned => order.assignedAgentId?.trim().isNotEmpty == true;
  bool get _processing => const <QueueOrderStatus>{
    QueueOrderStatus.inProgress,
    QueueOrderStatus.onHold,
    QueueOrderStatus.awaitingCustomerConfirmation,
    QueueOrderStatus.completed,
    QueueOrderStatus.failed,
    QueueOrderStatus.refundPending,
    QueueOrderStatus.refunded,
  }.contains(order.status);
  bool get _done => const <QueueOrderStatus>{
    QueueOrderStatus.completed,
    QueueOrderStatus.failed,
    QueueOrderStatus.refunded,
  }.contains(order.status);

  @override
  Widget build(BuildContext context) {
    final bool currentProcessing = _processing && !_done;
    final List<_ProgressStepData> steps = <_ProgressStepData>[
      _ProgressStepData(
        label: 'Payée',
        state: _paid ? _ProgressState.done : _ProgressState.pending,
        date: order.paymentConfirmedAt,
      ),
      _ProgressStepData(
        label: 'Affectée',
        state: _assigned ? _ProgressState.done : _ProgressState.pending,
        date: order.assignedAt,
      ),
      _ProgressStepData(
        label: order.status == QueueOrderStatus.onHold
            ? 'En attente'
            : 'En traitement',
        state: currentProcessing
            ? _ProgressState.current
            : (_done ? _ProgressState.done : _ProgressState.pending),
        date: order.takenAt,
      ),
      _ProgressStepData(
        label: order.status == QueueOrderStatus.failed ? 'Échouée' : 'Terminée',
        state: _done ? _ProgressState.done : _ProgressState.pending,
        date: order.completedAt,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemWidth = constraints.maxWidth / steps.length;
        return SizedBox(
          height: 82,
          child: Stack(
            children: [
              Positioned(
                left: itemWidth / 2,
                right: itemWidth / 2,
                top: 15,
                child: Row(
                  children: List<Widget>.generate(steps.length - 1, (int index) {
                    final _ProgressState left = steps[index].state;
                    final _ProgressState right = steps[index + 1].state;
                    final bool completed =
                        left == _ProgressState.done &&
                        right != _ProgressState.pending;
                    return Flexible(
                      fit: FlexFit.tight,
                      child: Container(
                        height: 2,
                        color: completed
                            ? IzyTelColors.success
                            : IzyTelColors.outlineStrong,
                      ),
                    );
                  }),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps
                    .map(
                      (_ProgressStepData step) => Flexible(
                        fit: FlexFit.tight,
                        child: _ProgressStep(step: step),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _ProgressState { done, current, pending }

class _ProgressStepData {
  const _ProgressStepData({
    required this.label,
    required this.state,
    this.date,
  });

  final String label;
  final _ProgressState state;
  final DateTime? date;
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.step});
  final _ProgressStepData step;

  String _dateTime(DateTime? value) {
    if (value == null) return '';
    final DateTime d = value.toLocal();
    final String day = d.day.toString().padLeft(2, '0');
    final String month = d.month.toString().padLeft(2, '0');
    final String hour = d.hour.toString().padLeft(2, '0');
    final String minute = d.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final bool done = step.state == _ProgressState.done;
    final bool current = step.state == _ProgressState.current;
    final Color accent = done
        ? IzyTelColors.success
        : (current ? IzyTelColors.primary : IzyTelColors.textMuted);
    final Color fill = done
        ? IzyTelColors.success
        : (current ? IzyTelColors.primarySoft : IzyTelColors.surface);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: done || current ? accent : IzyTelColors.outlineStrong,
              width: 1.2,
            ),
          ),
          child: Icon(
            done
                ? Symbols.check_rounded
                : (current ? Symbols.hourglass_top_rounded : Symbols.check_rounded),
            size: 17,
            color: done ? Colors.white : accent,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              step.label,
              maxLines: 1,
              style: TextStyle(
                color: step.state == _ProgressState.pending
                    ? IzyTelColors.textSecondary
                    : IzyTelColors.textPrimary,
                fontSize: 11,
                fontWeight: current ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
        if (step.date != null) ...[
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _dateTime(step.date),
              maxLines: 1,
              style: const TextStyle(
                color: IzyTelColors.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
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
                icon: Symbols.error_rounded,
                message: 'Impossible de charger les demandes client.',
                color: IzyTelColors.error,
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
                color: IzyTelColors.success,
              );
            }

            return Column(
              children: [
                for (int index = 0; index < requests.length; index++) ...[
                  _SupportRequestTile(request: requests[index]),
                  if (index != requests.length - 1)
                    Divider(
                      height: 18,
                      color: IzyTelColors.outline.withAlpha(70),
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
        return IzyTelColors.warning;
      case SupportRequestStatus.inProgress:
        return IzyTelColors.primary;
      case SupportRequestStatus.resolved:
        return IzyTelColors.success;
      case SupportRequestStatus.closed:
        return IzyTelColors.textSecondary;
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
                  color: IzyTelColors.textPrimary,
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
            color: IzyTelColors.textSecondary,
            fontSize: 10,
          ),
        ),
        if (request.description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: IzyTelColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              request.description,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
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
              color: IzyTelColors.textSecondary,
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
    required this.onCopyReference,
    required this.isRefreshing,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onCopyReference;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: IzyTelColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: const Icon(
              Symbols.arrow_back_rounded,
              size: IzyTelIconSize.action,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              'Détail commande',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: IzyTelColors.textPrimary,
                fontSize: IzyTelTypeScale.title3,
                fontWeight: FontWeight.w700,
                letterSpacing: -.25,
              ),
            ),
          ),
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_DetailMenuAction>(
              tooltip: 'Plus d’actions',
              icon: const Icon(
                Symbols.more_vert_rounded,
                size: IzyTelIconSize.action,
              ),
              onSelected: (_DetailMenuAction action) {
                switch (action) {
                  case _DetailMenuAction.refresh:
                    onRefresh();
                    return;
                  case _DetailMenuAction.copyReference:
                    onCopyReference();
                    return;
                }
              },
              itemBuilder: (BuildContext context) => const [
                PopupMenuItem<_DetailMenuAction>(
                  value: _DetailMenuAction.refresh,
                  child: Row(
                    children: [
                      Icon(Symbols.refresh_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Actualiser'),
                    ],
                  ),
                ),
                PopupMenuItem<_DetailMenuAction>(
                  value: _DetailMenuAction.copyReference,
                  child: Row(
                    children: [
                      Icon(Symbols.receipt_long_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Copier la référence'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

enum _DetailMenuAction { refresh, copyReference }

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order, required this.onCopy});

  final QueueOrder order;
  final Future<void> Function(String value, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    final Color color = networkColor(order.network);
    final Color status = orderStatusColor(order.status);

    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  networkAsset(order.network),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: IzyTelSpacing.sm),
              Flexible(
                child: Text(
                  networkLabel(order.network),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: IzyTelSpacing.sm),
              _SmallStatusBadge(
                label: orderStatusLabel(order.status),
                color: status,
              ),
            ],
          ),
          const SizedBox(height: IzyTelSpacing.sm),
          Text(
            order.offerLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.cardTitle,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: IzyTelSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
                  const Icon(
                    Symbols.phone_iphone_rounded,
                    size: IzyTelIconSize.info,
                    color: IzyTelColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => onCopy(
                        order.beneficiaryPhone,
                        'Numéro bénéficiaire',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatIvorianPhone(order.beneficiaryPhone),
                            maxLines: 1,
                            style: const TextStyle(
                              color: IzyTelColors.textPrimary,
                              fontSize: IzyTelTypeScale.transactionNumber,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .05,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: IzyTelSpacing.sm),
                  Text(
                    formatCfa(order.amount),
                    maxLines: 1,
                    style: const TextStyle(
                      color: IzyTelColors.primaryStrong,
                      fontSize: IzyTelTypeScale.money,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
            ],
          ),
          const SizedBox(height: IzyTelSpacing.sm),
          Row(
            children: [
              Flexible(
                child: Text(
                  'Créée ${formatOrderDateTime(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: IzyTelColors.textMuted,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: IzyTelSpacing.sm),
              Flexible(
                child: InkWell(
                  onTap: () => onCopy(order.reference, 'Référence'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            order.reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: IzyTelColors.textSecondary,
                              fontSize: IzyTelTypeScale.micro,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Symbols.receipt_long_rounded,
                          size: 15,
                          color: IzyTelColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailGroup extends StatelessWidget {
  const _DetailGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(IzyTelRadii.card),
        border: Border.all(color: IzyTelColors.outline),
        boxShadow: const [
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, color: IzyTelColors.outline),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatefulWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  State<_DetailSection> createState() => _DetailSectionState();
}

class _DetailSectionState extends State<_DetailSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IzyTelSpacing.md,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: IzyTelColors.textPrimary,
                  size: IzyTelIconSize.info,
                ),
                const SizedBox(width: IzyTelSpacing.sm),
                Flexible(
                  fit: FlexFit.tight,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: IzyTelColors.textPrimary,
                      fontSize: IzyTelTypeScale.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: IzyTelSpacing.sm),
                  widget.trailing!,
                ],
                const SizedBox(width: 6),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: _expanded ? .25 : 0,
                  child: const Icon(
                    Symbols.chevron_right_rounded,
                    color: IzyTelColors.textMuted,
                    size: IzyTelIconSize.info,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: _expanded
              ? Container(
                  color: IzyTelColors.surface,
                  padding: const EdgeInsets.fromLTRB(
                    IzyTelSpacing.md,
                    0,
                    IzyTelSpacing.md,
                    IzyTelSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1, color: IzyTelColors.outline),
                      const SizedBox(height: IzyTelSpacing.sm),
                      widget.child,
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ProofSectionContent extends StatelessWidget {
  const _ProofSectionContent({required this.proof, required this.isLoading});

  final OrderProof? proof;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: IzyTelSpacing.sm),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (proof == null) {
      return const _InlineInfo(
        icon: Symbols.image_rounded,
        text: 'Aucune preuve de transfert n’a encore été ajoutée.',
        color: IzyTelColors.textSecondary,
      );
    }

    final bool isImage = proof!.mimeType.startsWith('image/');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: IzyTelColors.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: IzyTelColors.outline),
          ),
          child: isImage
              ? Image.memory(proof!.bytes, fit: BoxFit.cover)
              : const Icon(
                  Symbols.receipt_long_rounded,
                  color: IzyTelColors.primary,
                ),
        ),
        const SizedBox(width: IzyTelSpacing.sm),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proof!.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontSize: IzyTelTypeScale.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ajoutée ${formatOrderDateTime(proof!.updatedAt)}',
                style: const TextStyle(
                  color: IzyTelColors.textMuted,
                  fontSize: IzyTelTypeScale.micro,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RefundSectionContent extends StatelessWidget {
  const _RefundSectionContent({required this.order});

  final QueueOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.status == QueueOrderStatus.refundPending) {
      return const _InlineInfo(
        icon: Symbols.hourglass_top_rounded,
        text: 'Un remboursement est en attente de traitement.',
        color: IzyTelColors.warning,
      );
    }
    if (order.status == QueueOrderStatus.refunded) {
      return const _InlineInfo(
        icon: Symbols.check_circle_rounded,
        text: 'Cette commande a été remboursée.',
        color: IzyTelColors.success,
      );
    }
    return const _InlineInfo(
      icon: Symbols.payments_rounded,
      text: 'Aucun remboursement enregistré pour cette commande.',
      color: IzyTelColors.textSecondary,
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: IzyTelIconSize.info),
        const SizedBox(width: IzyTelSpacing.sm),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
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
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(IzyTelSpacing.sm),
      decoration: BoxDecoration(
        color: IzyTelColors.primarySoft.withAlpha(125),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: IzyTelColors.primary.withAlpha(42),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                color: IzyTelColors.primaryStrong,
                fontSize: IzyTelTypeScale.title3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: IzyTelSpacing.sm),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatIvorianPhone(order.clientWhatsappPhone),
                  maxLines: 1,
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  orderSourceLabel(order.source),
                  style: const TextStyle(
                    color: IzyTelColors.primaryStrong,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w500,
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
    this.valueColor = IzyTelColors.textPrimary,
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stack = constraints.maxWidth < 320 || value.length > 28;
        final Widget copyButton = canCopy
            ? IconButton(
                tooltip: 'Copier',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: onCopy,
                icon: const Icon(
                  Symbols.receipt_long_rounded,
                  size: 16,
                  color: IzyTelColors.primary,
                ),
              )
            : const SizedBox.shrink();

        final Widget content = stack
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: IzyTelColors.textSecondary,
                      fontSize: IzyTelTypeScale.micro,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: valueColor,
                            fontSize: IzyTelTypeScale.label,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                      if (canCopy) ...[
                        const SizedBox(width: 5),
                        copyButton,
                      ],
                    ],
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.micro,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.tight,
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: valueColor,
                        fontSize: IzyTelTypeScale.label,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                  if (canCopy) ...[
                    const SizedBox(width: 5),
                    copyButton,
                  ],
                ],
              );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: content,
            ),
            if (showDivider)
              Divider(height: 1, color: IzyTelColors.outline.withAlpha(90)),
          ],
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: IzyTelTypeScale.micro,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OrderAuditTimeline extends StatelessWidget {
  const _OrderAuditTimeline({
    required this.orderId,
    required this.repository,
    required this.includesRefunds,
  });

  final String orderId;
  final OrderAuditRepository repository;
  final bool includesRefunds;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderAuditEntry>>(
      stream: repository.watchForOrder(orderId: orderId),
      builder: (BuildContext context, AsyncSnapshot<List<OrderAuditEntry>> snapshot) {
        if (snapshot.hasError) {
          return const _SupportRequestInfo(
            icon: Symbols.error_rounded,
            message: 'Impossible de charger le journal d’activité.',
            color: IzyTelColors.error,
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final List<OrderAuditEntry> entries = snapshot.data!;
        if (entries.isEmpty) {
          return const _SupportRequestInfo(
            icon: Icons.history_toggle_off_rounded,
            message:
                'Aucun événement audité n’est disponible pour cette commande.',
            color: IzyTelColors.textSecondary,
          );
        }

        final List<Widget> children = <Widget>[];
        DateTime? previousDay;
        for (int index = 0; index < entries.length; index++) {
          final OrderAuditEntry entry = entries[index];
          final DateTime day = DateTime(
            entry.occurredAt.year,
            entry.occurredAt.month,
            entry.occurredAt.day,
          );
          if (previousDay == null || day != previousDay) {
            if (children.isNotEmpty) {
              children.add(const SizedBox(height: 12));
            }
            children.add(_AuditDayHeader(label: _auditDayLabel(day)));
            children.add(const SizedBox(height: 10));
            previousDay = day;
          }

          children.add(
            _AuditEntryTile(entry: entry, isLast: index == entries.length - 1),
          );
        }

        if (!includesRefunds) {
          children.add(const SizedBox(height: 10));
          children.add(
            const _SupportRequestInfo(
              icon: Icons.lock_outline_rounded,
              message:
                  'Les événements financiers de remboursement sont réservés aux administrateurs.',
              color: IzyTelColors.textSecondary,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      },
    );
  }
}

class _AuditDayHeader extends StatelessWidget {
  const _AuditDayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: IzyTelColors.primary,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({required this.entry, required this.isLast});

  final OrderAuditEntry entry;
  final bool isLast;

  Color get _sourceColor {
    switch (entry.source) {
      case OrderAuditSource.orderEvent:
        return IzyTelColors.primary;
      case OrderAuditSource.supportRequest:
        return IzyTelColors.warning;
      case OrderAuditSource.refund:
        return IzyTelColors.success;
    }
  }

  IconData get _sourceIcon {
    switch (entry.source) {
      case OrderAuditSource.orderEvent:
        return Icons.receipt_long_outlined;
      case OrderAuditSource.supportRequest:
        return Icons.support_agent_rounded;
      case OrderAuditSource.refund:
        return Icons.currency_exchange_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _sourceColor;
    final String? actorId = entry.actorId?.trim().isEmpty == false
        ? entry.actorId!.trim()
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(130)),
                ),
                child: Icon(_sourceIcon, size: 13, color: color),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: (74 + (entry.details.length * 17)).toDouble(),
                  constraints: const BoxConstraints(maxHeight: 150),
                  color: IzyTelColors.outline.withAlpha(90),
                ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 15),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: IzyTelColors.background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: IzyTelColors.outline.withAlpha(65)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                            color: IzyTelColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: color.withAlpha(22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withAlpha(90)),
                        ),
                        child: Text(
                          entry.source.label,
                          style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatOrderDateTime(entry.occurredAt),
                    style: const TextStyle(
                      color: IzyTelColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 3,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 13,
                        color: IzyTelColors.textSecondary,
                      ),
                      Text(
                        entry.actorDisplayName,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (entry.actorDisplayName != entry.actorRoleLabel)
                        Text(
                          '· ${entry.actorRoleLabel}',
                          style: const TextStyle(
                            color: IzyTelColors.textSecondary,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                  if (actorId != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'ID acteur : $actorId',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: IzyTelColors.textSecondary,
                        fontSize: 8,
                      ),
                    ),
                  ],
                  if (entry.details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final String detail in entry.details) ...[
                      Text(
                        '• $detail',
                        style: const TextStyle(
                          color: IzyTelColors.textSecondary,
                          fontSize: 9,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ],
                  if (entry.technicalType?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Type audit : ${entry.technicalType}',
                      style: const TextStyle(
                        color: IzyTelColors.textSecondary,
                        fontSize: 8,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _auditDayLabel(DateTime day) {
  final DateTime now = DateTime.now();
  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime yesterday = today.subtract(const Duration(days: 1));

  if (day == today) {
    return 'Aujourd’hui';
  }
  if (day == yesterday) {
    return 'Hier';
  }

  const List<String> months = <String>[
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  return '${day.day} ${months[day.month - 1]} ${day.year}';
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
        color: IzyTelColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: IzyTelColors.outline.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: IzyTelColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
