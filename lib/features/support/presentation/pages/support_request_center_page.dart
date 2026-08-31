import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/refunds/presentation/pages/refund_management_page.dart';
import 'package:cabine_flow/features/refunds/presentation/widgets/refund_creation_sheet.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/features/support/presentation/widgets/support_resolution_note_dialog.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

enum _SupportInboxTab { newRequests, inProgress, history }

class SupportRequestCenterPage extends StatefulWidget {
  const SupportRequestCenterPage({
    super.key,
    required this.user,
    required this.repository,
    required this.refundRepository,
    required this.orderHistoryRepository,
  });

  final AppUser user;
  final SupportRequestRepository repository;
  final RefundRepository refundRepository;
  final OrderHistoryRepository orderHistoryRepository;

  @override
  State<SupportRequestCenterPage> createState() =>
      _SupportRequestCenterPageState();
}

class _SupportRequestCenterPageState extends State<SupportRequestCenterPage> {
  Timer? _clockTimer;
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<SupportRequest>> _requestsStream;
  _SupportInboxTab _selectedTab = _SupportInboxTab.newRequests;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    _requestsStream = widget.repository.watchAllRequests();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IzyTelColors.background,
      appBar: AppBar(
        backgroundColor: IzyTelColors.background,
        title: const Text('Demandes clients'),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<SupportRequest>>(
          stream: _requestsStream,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<SupportRequest>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: 'Impossible de charger les demandes clients.',
                    onRetry: () => setState(() {}),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final List<SupportRequest> all = snapshot.data!;
                final int newCount = all
                    .where(
                      (SupportRequest request) =>
                          request.status == SupportRequestStatus.newRequest,
                    )
                    .length;
                final int inProgressCount = all
                    .where(
                      (SupportRequest request) =>
                          request.status == SupportRequestStatus.inProgress,
                    )
                    .length;
                final int historyCount = all
                    .where((SupportRequest request) => request.isResolved)
                    .length;
                final List<SupportRequest> visible = _filter(all);

                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  color: IzyTelColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                    children: [
                      IzyTelPageHeader(
                        title: 'Centre d’assistance',
                        subtitle: newCount == 0
                            ? 'Aucune nouvelle demande ne nécessite ton attention.'
                            : '$newCount demande${newCount > 1 ? 's' : ''} à traiter maintenant.',
                      ),
                      const SizedBox(height: IzyTelSpacing.lg),
                      _SupportSummary(
                        newCount: newCount,
                        inProgressCount: inProgressCount,
                        resolvedCount: historyCount,
                      ),
                      const SizedBox(height: IzyTelSpacing.md),
                      IzyTelSearchField(
                        controller: _searchController,
                        hintText: 'Référence, motif, description…',
                        onChanged: (String value) {
                          setState(() => _query = value);
                        },
                      ),
                      const SizedBox(height: IzyTelSpacing.sm),
                      _RequestTabs(
                        selected: _selectedTab,
                        newCount: newCount,
                        inProgressCount: inProgressCount,
                        historyCount: historyCount,
                        onChanged: (_SupportInboxTab value) {
                          setState(() => _selectedTab = value);
                        },
                      ),
                      const SizedBox(height: IzyTelSpacing.lg),
                      if (visible.isEmpty)
                        IzyTelSurface(child: _EmptyState(tab: _selectedTab))
                      else
                        ...visible.map(
                          (SupportRequest request) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SupportRequestCard(
                              request: request,
                              onTap: () => _openRequest(request),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
        ),
      ),
    );
  }

  List<SupportRequest> _filter(List<SupportRequest> all) {
    final Iterable<SupportRequest> byTab = switch (_selectedTab) {
      _SupportInboxTab.newRequests => all.where(
        (SupportRequest request) =>
            request.status == SupportRequestStatus.newRequest,
      ),
      _SupportInboxTab.inProgress => all.where(
        (SupportRequest request) =>
            request.status == SupportRequestStatus.inProgress,
      ),
      _SupportInboxTab.history => all.where(
        (SupportRequest request) => request.isResolved,
      ),
    };

    final String query = _query.trim().toLowerCase();
    if (query.isEmpty) return byTab.toList(growable: false);
    return byTab
        .where((SupportRequest request) {
          return <String>[
            request.orderReference,
            request.type.label,
            request.description,
            request.status.label,
            request.assignedToName ?? '',
            request.resolvedByName ?? '',
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openRequest(SupportRequest request) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return SupportRequestDetailPage(
            user: widget.user,
            initialRequest: request,
            repository: widget.repository,
            refundRepository: widget.refundRepository,
            orderHistoryRepository: widget.orderHistoryRepository,
          );
        },
      ),
    );
  }
}

class _SupportSummary extends StatelessWidget {
  const _SupportSummary({
    required this.newCount,
    required this.inProgressCount,
    required this.resolvedCount,
  });

  final int newCount;
  final int inProgressCount;
  final int resolvedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SupportMetric(
            value: '$newCount',
            label: 'À traiter',
            color: IzyTelColors.warning,
            softColor: IzyTelColors.warningSoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SupportMetric(
            value: '$inProgressCount',
            label: 'En cours',
            color: IzyTelColors.primary,
            softColor: IzyTelColors.primarySoft,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SupportMetric(
            value: '$resolvedCount',
            label: 'Traitées',
            color: IzyTelColors.success,
            softColor: IzyTelColors.successSoft,
          ),
        ),
      ],
    );
  }
}

class _SupportMetric extends StatelessWidget {
  const _SupportMetric({
    required this.value,
    required this.label,
    required this.color,
    required this.softColor,
  });

  final String value;
  final String label;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(36)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: IzyTelColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SupportRequestDetailPage extends StatefulWidget {
  const SupportRequestDetailPage({
    super.key,
    required this.user,
    required this.initialRequest,
    required this.repository,
    required this.refundRepository,
    required this.orderHistoryRepository,
  });

  final AppUser user;
  final SupportRequest initialRequest;
  final SupportRequestRepository repository;
  final RefundRepository refundRepository;
  final OrderHistoryRepository orderHistoryRepository;

  @override
  State<SupportRequestDetailPage> createState() =>
      _SupportRequestDetailPageState();
}

class _SupportRequestDetailPageState extends State<SupportRequestDetailPage> {
  late Future<QueueOrder> _orderFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _orderFuture = widget.orderHistoryRepository.fetchOrderById(
      orderId: widget.initialRequest.orderId,
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
          'Détail de la demande',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<SupportRequest>>(
          stream: widget.repository.watchAllRequests(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<SupportRequest>> snapshot,
              ) {
                final SupportRequest request = _currentRequest(snapshot.data);
                return StreamBuilder<RefundCase?>(
                  stream: widget.refundRepository.watchForOrder(
                    orderId: request.orderId,
                  ),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<RefundCase?> refundSnapshot,
                      ) {
                        final RefundCase? refund = refundSnapshot.data;
                        return FutureBuilder<QueueOrder>(
                          future: _orderFuture,
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<QueueOrder> orderSnapshot,
                              ) {
                                final QueueOrder? order = orderSnapshot.data;
                                return ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    32,
                                  ),
                                  children: [
                                    _RequestStatusHeader(request: request),
                                    const SizedBox(height: 14),
                                    _SectionCard(
                                      title: 'Demande client',
                                      icon: Symbols.support_agent_rounded,
                                      child: Column(
                                        children: [
                                          _InfoRow(
                                            label: 'Référence',
                                            value: request.orderReference,
                                          ),
                                          _InfoRow(
                                            label: 'Motif',
                                            value: request.type.label,
                                          ),
                                          _InfoRow(
                                            label: 'Créée le',
                                            value: _formatDateTime(
                                              request.createdAt,
                                            ),
                                          ),
                                          if (request.description
                                              .trim()
                                              .isNotEmpty)
                                            _InfoRow(
                                              label: 'Description',
                                              value: request.description,
                                              multiline: true,
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _SectionCard(
                                      title: 'Commande associée',
                                      icon: Symbols.receipt_long_rounded,
                                      child:
                                          orderSnapshot.connectionState ==
                                              ConnectionState.waiting
                                          ? const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            )
                                          : order == null
                                          ? const Text(
                                              'Impossible de charger les informations de la commande.',
                                              style: TextStyle(
                                                color: IzyTelColors.error,
                                              ),
                                            )
                                          : Column(
                                              children: [
                                                _InfoRow(
                                                  label: 'Client',
                                                  value: order.clientName,
                                                ),
                                                _InfoRow(
                                                  label: 'WhatsApp',
                                                  value: _formatSupportPhone(
                                                    order.clientWhatsappPhone,
                                                  ),
                                                ),
                                                _InfoRow(
                                                  label: 'Bénéficiaire',
                                                  value: _formatSupportPhone(
                                                    order.beneficiaryPhone,
                                                  ),
                                                ),
                                                _InfoRow(
                                                  label: 'Offre',
                                                  value: order.offerLabel,
                                                ),
                                                _InfoRow(
                                                  label: 'Montant',
                                                  value:
                                                      '${_formatAmount(order.amount)} F',
                                                ),
                                              ],
                                            ),
                                    ),
                                    if (refund != null) ...[
                                      const SizedBox(height: 12),
                                      _SupportRefundCard(
                                        refund: refund,
                                        onTap: () => _openRefund(refund),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    _TraceabilityCard(request: request),
                                    const SizedBox(height: 18),
                                    ..._buildActions(
                                      request: request,
                                      order: order,
                                      refund: refund,
                                    ),
                                  ],
                                );
                              },
                        );
                      },
                );
              },
        ),
      ),
    );
  }

  SupportRequest _currentRequest(List<SupportRequest>? requests) {
    if (requests == null) {
      return widget.initialRequest;
    }
    for (final SupportRequest request in requests) {
      if (request.id == widget.initialRequest.id) {
        return request;
      }
    }
    return widget.initialRequest;
  }

  List<Widget> _buildActions({
    required SupportRequest request,
    required QueueOrder? order,
    required RefundCase? refund,
  }) {
    if (_isSubmitting) {
      return const <Widget>[Center(child: CircularProgressIndicator())];
    }

    switch (request.status) {
      case SupportRequestStatus.newRequest:
        return <Widget>[
          FilledButton.icon(
            onPressed: () => _takeInCharge(request),
            icon: const Icon(Symbols.playlist_add_check_circle_rounded),
            label: const Text('Prendre en charge'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ];
      case SupportRequestStatus.inProgress:
        if (refund != null && refund.isActive) {
          return <Widget>[
            _RefundPendingInfo(refund: refund),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openRefund(refund),
              icon: const Icon(Symbols.currency_exchange_rounded),
              label: const Text('Voir le remboursement'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ];
        }
        return <Widget>[
          FilledButton.icon(
            onPressed: () => _resolve(request),
            icon: const Icon(Symbols.check_circle_rounded),
            label: const Text('Marquer comme résolue'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          if (refund != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openRefund(refund),
              icon: const Icon(Symbols.currency_exchange_rounded),
              label: const Text('Voir le remboursement'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ] else if (order != null &&
              order.paymentStatus == OrderPaymentStatus.confirmed) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _createRefund(request, order),
              icon: const Icon(Symbols.currency_exchange_rounded),
              label: const Text('Créer un remboursement'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: IzyTelColors.warning,
              ),
            ),
          ] else if (order != null && order.isCreditSale) ...[
            const SizedBox(height: 10),
            const _CreditRefundInfo(),
          ],
        ];
      case SupportRequestStatus.resolved:
        return <Widget>[
          if (refund != null) ...[
            OutlinedButton.icon(
              onPressed: () => _openRefund(refund),
              icon: const Icon(Symbols.currency_exchange_rounded),
              label: const Text('Voir le remboursement'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: IzyTelColors.warning,
              ),
            ),
            const SizedBox(height: 10),
          ] else if (order != null &&
              order.paymentStatus == OrderPaymentStatus.confirmed) ...[
            OutlinedButton.icon(
              onPressed: () => _createRefund(request, order),
              icon: const Icon(Symbols.currency_exchange_rounded),
              label: const Text('Créer un remboursement'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: IzyTelColors.warning,
              ),
            ),
            const SizedBox(height: 10),
          ] else if (order != null && order.isCreditSale) ...[
            const _CreditRefundInfo(),
            const SizedBox(height: 10),
          ],
          if (!request.customerWasNotified)
            FilledButton.icon(
              onPressed: order == null
                  ? null
                  : () => _notifyCustomer(request, order),
              icon: const Icon(Symbols.chat_rounded),
              label: const Text('Notifier le client sur WhatsApp'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          if (!request.customerWasNotified) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _close(request),
            icon: const Icon(Symbols.archive_rounded),
            label: const Text('Fermer le dossier'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ];
      case SupportRequestStatus.closed:
        return const <Widget>[_ClosedInfo()];
    }
  }

  Future<void> _takeInCharge(SupportRequest request) async {
    await _runAction(() {
      return widget.repository.takeInCharge(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
      );
    }, successMessage: 'La demande est maintenant en cours de traitement.');
  }

  Future<void> _resolve(SupportRequest request) async {
    final String? note = await _askResolutionNote();
    if (note == null) {
      return;
    }
    await _runAction(() {
      return widget.repository.resolve(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
        resolutionNote: note,
      );
    }, successMessage: 'La demande a été marquée comme résolue.');
  }

  Future<void> _createRefund(SupportRequest request, QueueOrder order) async {
    if (order.paymentStatus != OrderPaymentStatus.confirmed) {
      _showMessage(
        'Le paiement doit être confirmé avant de créer un remboursement.',
      );
      return;
    }

    final RefundCreationDraft? draft =
        await showModalBottomSheet<RefundCreationDraft>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black.withAlpha(170),
          builder: (BuildContext sheetContext) {
            return RefundCreationSheet(order: order, supportRequest: request);
          },
        );
    if (draft == null || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final RefundCase refund = await widget.refundRepository.create(
        request: RefundCreationRequest(
          orderId: order.id,
          orderReference: order.reference,
          supportRequestId: request.id,
          supportRequestType: request.type.storageValue,
          supportRequestDescription: request.description,
          customerAuthUid: request.customerAuthUid,
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
      if (!mounted) {
        return;
      }
      _showMessage(
        'Le remboursement a été créé et attend maintenant une validation.',
      );
      await _openRefund(refund);
    } on Object catch (error, stackTrace) {
      debugPrint('[Refund][create-from-support] ERROR $error');
      debugPrint('[Refund][create-from-support] STACK\n$stackTrace');
      if (!mounted) {
        return;
      }
      final String message = error.toString().contains('existe déjà')
          ? 'Un remboursement existe déjà pour cette commande.'
          : 'Impossible de créer le remboursement pour le moment.';
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openRefund(RefundCase refund) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext routeContext) {
          return RefundDetailPage(
            user: widget.user,
            initialRefund: refund,
            repository: widget.refundRepository,
            orderHistoryRepository: widget.orderHistoryRepository,
          );
        },
      ),
    );
  }

  String? _initialPaymentReference(QueueOrder order) {
    final String paymentReference = order.paymentReference?.trim() ?? '';
    if (paymentReference.isNotEmpty) {
      return paymentReference;
    }
    final String declaredReference =
        order.paymentDeclaredReference?.trim() ?? '';
    return declaredReference.isEmpty ? null : declaredReference;
  }

  Future<void> _close(SupportRequest request) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Fermer le dossier ?'),
          content: const Text(
            'La demande restera visible dans l’historique et ne sera jamais supprimée.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(
      () => widget.repository.close(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'Le dossier est fermé et conservé dans l’historique.',
    );
  }

  Future<void> _notifyCustomer(SupportRequest request, QueueOrder order) async {
    final String phone = _normalizeWhatsappPhone(order.clientWhatsappPhone);
    if (phone.isEmpty) {
      _showMessage('Aucun numéro WhatsApp client n’est disponible.');
      return;
    }

    final String resolution = request.resolutionNote?.trim() ?? '';
    final String message = resolution.isEmpty
        ? 'Bonjour ${order.clientName}, votre demande concernant la commande ${request.orderReference} a été traitée par IzyTel.'
        : 'Bonjour ${order.clientName}, votre demande concernant la commande ${request.orderReference} a été traitée par IzyTel. Réponse : $resolution';
    final Uri uri = Uri.https('wa.me', '/$phone', <String, String>{
      'text': message,
    });

    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) {
      return;
    }
    if (!opened) {
      _showMessage('Impossible d’ouvrir WhatsApp.');
      return;
    }

    final bool? sent = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Client notifié ?'),
          content: const Text(
            'Confirmez uniquement si le message a réellement été envoyé au client sur WhatsApp.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Pas encore'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Oui, envoyé'),
            ),
          ],
        );
      },
    );
    if (sent != true) {
      return;
    }

    await _runAction(
      () => widget.repository.markCustomerNotified(
        requestId: request.id,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      successMessage: 'La notification WhatsApp est tracée dans le dossier.',
    );
  }

  Future<String?> _askResolutionNote() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(170),
      builder: (BuildContext sheetContext) {
        return const SupportResolutionNoteDialog();
      },
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isSubmitting) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      _showMessage(successMessage);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      debugPrint('[SupportRequest][admin] ERROR $error');
      _showMessage('Impossible d’enregistrer cette action pour le moment.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    IzyTelFeedback.show(context, message);
  }

  String _normalizeWhatsappPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('225')) {
      return digits;
    }
    if (digits.startsWith('0')) {
      return '225$digits';
    }
    return digits;
  }
}

class _CreditRefundInfo extends StatelessWidget {
  const _CreditRefundInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.warningSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IzyTelColors.warning.withAlpha(70)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Symbols.info_rounded, color: IzyTelColors.warning, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Cette commande a été autorisée à crédit : aucun paiement Wave confirmé n’est attaché à la commande, donc aucun remboursement Wave ne peut être créé ici. Si le client a réglé le crédit, vérifie ses encaissements dans Finances.',
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

class _SupportRefundCard extends StatelessWidget {
  const _SupportRefundCard({required this.refund, required this.onTap});

  final RefundCase refund;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _refundStatusColor(refund.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: IzyTelColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(90)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withAlpha(28),
                  shape: BoxShape.circle,
                ),
                child: Icon(Symbols.currency_exchange_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remboursement lié',
                      style: TextStyle(
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${refund.status.label} · ${_formatAmount(refund.amount)} F',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefundPendingInfo extends StatelessWidget {
  const _RefundPendingInfo({required this.refund});

  final RefundCase refund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: IzyTelColors.warning.withAlpha(22),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: IzyTelColors.warning.withAlpha(75)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Symbols.currency_exchange_rounded,
            color: IzyTelColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              refund.status == RefundStatus.pendingApproval
                  ? 'Un remboursement attend une validation. Finalisez ce dossier avant de résoudre la demande client.'
                  : 'Le remboursement est approuvé et doit encore être effectué dans Wave avant de résoudre la demande client.',
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _refundStatusColor(RefundStatus status) {
  switch (status) {
    case RefundStatus.pendingApproval:
      return IzyTelColors.warning;
    case RefundStatus.approved:
      return IzyTelColors.primary;
    case RefundStatus.refunded:
      return IzyTelColors.success;
    case RefundStatus.reconciled:
      return const Color(0xFF5DD6C0);
    case RefundStatus.rejected:
      return IzyTelColors.error;
  }
}

class _RequestTabs extends StatelessWidget {
  const _RequestTabs({
    required this.selected,
    required this.newCount,
    required this.inProgressCount,
    required this.historyCount,
    required this.onChanged,
  });

  final _SupportInboxTab selected;
  final int newCount;
  final int inProgressCount;
  final int historyCount;
  final ValueChanged<_SupportInboxTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IzyTelFilterPill(
            label: 'À traiter',
            count: newCount,
            selected: selected == _SupportInboxTab.newRequests,
            selectedColor: IzyTelColors.warning,
            softColor: IzyTelColors.warningSoft,
            onTap: () => onChanged(_SupportInboxTab.newRequests),
          ),
          const SizedBox(width: 8),
          IzyTelFilterPill(
            label: 'En cours',
            count: inProgressCount,
            selected: selected == _SupportInboxTab.inProgress,
            onTap: () => onChanged(_SupportInboxTab.inProgress),
          ),
          const SizedBox(width: 8),
          IzyTelFilterPill(
            label: 'Historique',
            count: historyCount,
            selected: selected == _SupportInboxTab.history,
            selectedColor: IzyTelColors.success,
            softColor: IzyTelColors.successSoft,
            onTap: () => onChanged(_SupportInboxTab.history),
          ),
        ],
      ),
    );
  }
}

class _SupportRequestCard extends StatelessWidget {
  const _SupportRequestCard({required this.request, required this.onTap});

  final SupportRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _supportStatusColorV2(request.status);
    final Color softColor = _supportStatusSoftColor(request.status);
    return IzyTelSurface(
      onTap: onTap,
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.all(14),
      borderColor: IzyTelColors.outline,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _supportTypeIcon(request.type),
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.type.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      request.orderReference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: IzyTelColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(status: request.status),
            ],
          ),
          if (request.description.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              request.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: IzyTelColors.textSecondary,
                fontSize: IzyTelTypeScale.label,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(
                Symbols.schedule_rounded,
                color: IzyTelColors.textMuted,
                size: IzyTelIconSize.info,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  _relativeSupportTime(request.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: request.status == SupportRequestStatus.newRequest
                        ? IzyTelColors.warning
                        : IzyTelColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (request.assignedToName?.trim().isNotEmpty == true) ...[
                const Icon(
                  Symbols.person_rounded,
                  color: IzyTelColors.textMuted,
                  size: IzyTelIconSize.info,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    request.assignedToName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: IzyTelColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textMuted,
                size: 21,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _supportTypeIcon(SupportRequestType type) => switch (type) {
  SupportRequestType.paymentNotRecognized => Symbols.payments_rounded,
  SupportRequestType.completedButNotReceived => Symbols.inventory_2_rounded,
  SupportRequestType.wrongAmount => Symbols.price_check_rounded,
  SupportRequestType.wrongNumber => Symbols.phone_in_talk_rounded,
  SupportRequestType.transactionFailed => Symbols.error_rounded,
  SupportRequestType.other => Symbols.support_agent_rounded,
};

String _relativeSupportTime(DateTime value) {
  final Duration delta = DateTime.now().difference(value);
  if (delta.isNegative || delta.inMinutes <= 0) return 'À l’instant';
  if (delta.inMinutes < 60) return 'Depuis ${delta.inMinutes} min';
  if (delta.inHours < 24) return 'Depuis ${delta.inHours} h';
  return 'Depuis ${delta.inDays} j';
}

Color _supportStatusColorV2(SupportRequestStatus status) => switch (status) {
  SupportRequestStatus.newRequest => IzyTelColors.warning,
  SupportRequestStatus.inProgress => IzyTelColors.primary,
  SupportRequestStatus.resolved => IzyTelColors.success,
  SupportRequestStatus.closed => IzyTelColors.textSecondary,
};

Color _supportStatusSoftColor(SupportRequestStatus status) => switch (status) {
  SupportRequestStatus.newRequest => IzyTelColors.warningSoft,
  SupportRequestStatus.inProgress => IzyTelColors.primarySoft,
  SupportRequestStatus.resolved => IzyTelColors.successSoft,
  SupportRequestStatus.closed => IzyTelColors.surfaceMuted,
};

class _RequestStatusHeader extends StatelessWidget {
  const _RequestStatusHeader({required this.request});

  final SupportRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _supportStatusColor(request.status).withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _supportStatusColor(request.status).withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.support_agent_rounded,
              color: _supportStatusColor(request.status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demande client',
                  style: TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  request.orderReference,
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _StatusChip(status: request.status),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: IzyTelColors.primary, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TraceabilityCard extends StatelessWidget {
  const _TraceabilityCard({required this.request});

  final SupportRequest request;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Traçabilité',
      icon: Symbols.history_rounded,
      child: Column(
        children: [
          _TraceLine(
            icon: Symbols.add_circle_rounded,
            label: 'Demande créée',
            detail: _formatDateTime(request.createdAt),
          ),
          if (request.inProgressAt != null)
            _TraceLine(
              icon: Symbols.play_circle_rounded,
              label: 'Prise en charge',
              detail:
                  '${request.assignedToName ?? 'Administrateur'} · ${_formatDateTime(request.inProgressAt!)}',
            ),
          if (request.resolvedAt != null)
            _TraceLine(
              icon: Symbols.check_circle_rounded,
              label: 'Résolution',
              detail:
                  '${request.resolvedByName ?? 'Administrateur'} · ${_formatDateTime(request.resolvedAt!)}',
            ),
          if (request.resolutionNote?.trim().isNotEmpty == true)
            _TraceLine(
              icon: Symbols.notes_rounded,
              label: 'Note de résolution',
              detail: request.resolutionNote!,
            ),
          if (request.customerNotifiedAt != null)
            _TraceLine(
              icon: Symbols.chat_rounded,
              label: 'Client notifié',
              detail:
                  '${request.customerNotifiedByName ?? 'Auteur non enregistré'} · WhatsApp · ${_formatDateTime(request.customerNotifiedAt!)}',
            ),
          if (request.closedAt != null)
            _TraceLine(
              icon: Symbols.archive_rounded,
              label: 'Dossier fermé',
              detail:
                  '${request.closedByName ?? 'Auteur non enregistré'} · ${_formatDateTime(request.closedAt!)}',
              isLast: true,
            ),
        ],
      ),
    );
  }
}

class _TraceLine extends StatelessWidget {
  const _TraceLine({
    required this.icon,
    required this.label,
    required this.detail,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: IzyTelColors.outline.withAlpha(60)),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: IzyTelColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 11,
                    height: 1.35,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: multiline ? TextAlign.start : TextAlign.end,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SupportRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = _supportStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});

  final _SupportInboxTab tab;

  @override
  Widget build(BuildContext context) {
    final String message = switch (tab) {
      _SupportInboxTab.newRequests => 'Aucune nouvelle demande à traiter.',
      _SupportInboxTab.inProgress => 'Aucune demande en cours de traitement.',
      _SupportInboxTab.history => 'Aucune demande traitée pour le moment.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Symbols.support_agent_rounded,
              size: 50,
              color: IzyTelColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.error_rounded, color: IzyTelColors.error),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IzyTelColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Symbols.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedInfo extends StatelessWidget {
  const _ClosedInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: const Row(
        children: [
          Icon(Symbols.archive_rounded, color: IzyTelColors.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ce dossier est fermé. Il reste conservé dans l’historique.',
              style: TextStyle(color: IzyTelColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

Color _supportStatusColor(SupportRequestStatus status) {
  switch (status) {
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

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} à ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _formatAmount(int amount) {
  final String value = amount.toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < value.length; index++) {
    if (index > 0 && (value.length - index) % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(value[index]);
  }
  return buffer.toString();
}

String _formatSupportPhone(String raw) {
  final String digits = raw.replaceAll(RegExp(r'\D'), '');
  String local = digits;
  if (digits.startsWith('225') && digits.length >= 13) {
    local = digits.substring(3);
  }
  if (local.length == 10) {
    final List<String> groups = <String>[];
    for (int index = 0; index < local.length; index += 2) {
      groups.add(local.substring(index, index + 2));
    }
    return '+225 ${groups.join(' ')}';
  }
  return raw;
}
