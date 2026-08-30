import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/finances/presentation/widgets/financial_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/refunds/presentation/widgets/refund_text_input_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

enum _RefundFilter { all, pending, approved, refunded, reconciled, rejected }

class RefundManagementPage extends StatefulWidget {
  const RefundManagementPage({
    super.key,
    required this.user,
    required this.repository,
    required this.orderHistoryRepository,
  });

  final AppUser user;
  final RefundRepository repository;
  final OrderHistoryRepository orderHistoryRepository;

  @override
  State<RefundManagementPage> createState() => _RefundManagementPageState();
}

class _RefundManagementPageState extends State<RefundManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  _RefundFilter _filter = _RefundFilter.all;

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
        backgroundColor: IzyTelColors.background,
        foregroundColor: IzyTelColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Remboursements',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<RefundCase>>(
          stream: widget.repository.watchAll(),
          builder: (BuildContext context, AsyncSnapshot<List<RefundCase>> snapshot) {
            if (snapshot.hasError) {
              return const SingleChildScrollView(
                child: FinanceEmptyState(
                  icon: Symbols.cloud_off_rounded,
                  title: 'Impossible de charger les remboursements',
                  message: 'Vérifie la connexion puis réessaie.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<RefundCase> all = snapshot.data!;
            final List<RefundCase> visible = _filtered(all);
            final List<RefundCase> pending = all
                .where((RefundCase value) => value.status == RefundStatus.pendingApproval)
                .toList(growable: false);
            final List<RefundCase> approved = all
                .where((RefundCase value) => value.status == RefundStatus.approved)
                .toList(growable: false);
            final int pendingAmount = pending.fold<int>(
              0,
              (int total, RefundCase value) => total + value.amount,
            );
            final int approvedAmount = approved.fold<int>(
              0,
              (int total, RefundCase value) => total + value.amount,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: FinancialMetricCard(
                              label: 'À valider',
                              value: _formatAmount(pendingAmount) + ' F',
                              caption: '${pending.length} dossier${pending.length > 1 ? 's' : ''}',
                              icon: Symbols.fact_check_rounded,
                              accent: IzyTelColors.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FinancialMetricCard(
                              label: 'À effectuer',
                              value: _formatAmount(approvedAmount) + ' F',
                              caption: '${approved.length} dossier${approved.length > 1 ? 's' : ''}',
                              icon: Symbols.currency_exchange_rounded,
                              accent: IzyTelColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Référence, client, numéro ou motif…',
                          hintStyle: const TextStyle(
                            color: IzyTelColors.textMuted,
                            fontSize: IzyTelTypeScale.label,
                          ),
                          prefixIcon: const Icon(
                            Symbols.search_rounded,
                            size: IzyTelIconSize.action,
                            color: IzyTelColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: IzyTelColors.surface,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(IzyTelRadii.card),
                            borderSide: const BorderSide(color: IzyTelColors.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(IzyTelRadii.card),
                            borderSide: const BorderSide(color: IzyTelColors.outline),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            FinanceFilterPill(
                              label: 'Tous',
                              count: all.length,
                              selected: _filter == _RefundFilter.all,
                              onTap: () => _setFilter(_RefundFilter.all),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'À valider',
                              count: pending.length,
                              accent: IzyTelColors.warning,
                              selected: _filter == _RefundFilter.pending,
                              onTap: () => _setFilter(_RefundFilter.pending),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'À effectuer',
                              count: approved.length,
                              selected: _filter == _RefundFilter.approved,
                              onTap: () => _setFilter(_RefundFilter.approved),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'Remboursés',
                              accent: IzyTelColors.success,
                              selected: _filter == _RefundFilter.refunded,
                              onTap: () => _setFilter(_RefundFilter.refunded),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'Rapprochés',
                              accent: IzyTelColors.moov,
                              selected: _filter == _RefundFilter.reconciled,
                              onTap: () => _setFilter(_RefundFilter.reconciled),
                            ),
                            const SizedBox(width: 7),
                            FinanceFilterPill(
                              label: 'Rejetés',
                              accent: IzyTelColors.error,
                              selected: _filter == _RefundFilter.rejected,
                              onTap: () => _setFilter(_RefundFilter.rejected),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const SingleChildScrollView(
                          child: FinanceEmptyState(
                            icon: Symbols.currency_exchange_rounded,
                            title: 'Aucun remboursement',
                            message: 'Les dossiers correspondant à ce filtre apparaîtront ici.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final RefundCase refund = visible[index];
                            return _RefundCard(
                              refund: refund,
                              onTap: () => _openDetail(refund),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _setFilter(_RefundFilter value) {
    setState(() => _filter = value);
  }

  List<RefundCase> _filtered(List<RefundCase> all) {
    final String query = _searchController.text.trim().toLowerCase();
    return all
        .where((RefundCase value) {
          if (!_matchesFilter(value)) return false;
          if (query.isEmpty) return true;
          return value.orderReference.toLowerCase().contains(query) ||
              value.clientName.toLowerCase().contains(query) ||
              value.clientWhatsappPhone.toLowerCase().contains(query) ||
              value.reason.label.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  bool _matchesFilter(RefundCase value) {
    switch (_filter) {
      case _RefundFilter.all:
        return true;
      case _RefundFilter.pending:
        return value.status == RefundStatus.pendingApproval;
      case _RefundFilter.approved:
        return value.status == RefundStatus.approved;
      case _RefundFilter.refunded:
        return value.status == RefundStatus.refunded;
      case _RefundFilter.reconciled:
        return value.status == RefundStatus.reconciled;
      case _RefundFilter.rejected:
        return value.status == RefundStatus.rejected;
    }
  }

  Future<void> _openDetail(RefundCase refund) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RefundDetailPage(
          user: widget.user,
          initialRefund: refund,
          repository: widget.repository,
          orderHistoryRepository: widget.orderHistoryRepository,
        ),
      ),
    );
  }
}

class RefundDetailPage extends StatefulWidget {
  const RefundDetailPage({
    super.key,
    required this.user,
    required this.initialRefund,
    required this.repository,
    required this.orderHistoryRepository,
  });

  final AppUser user;
  final RefundCase initialRefund;
  final RefundRepository repository;
  final OrderHistoryRepository orderHistoryRepository;

  @override
  State<RefundDetailPage> createState() => _RefundDetailPageState();
}

class _RefundDetailPageState extends State<RefundDetailPage> {
  late Future<QueueOrder> _orderFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _orderFuture = widget.orderHistoryRepository.fetchOrderById(
      orderId: widget.initialRefund.orderId,
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
          'Détail du remboursement',
          style: TextStyle(
            fontSize: IzyTelTypeScale.title3,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<RefundCase?>(
          stream: widget.repository.watchForOrder(
            orderId: widget.initialRefund.orderId,
          ),
          builder: (BuildContext context, AsyncSnapshot<RefundCase?> refundSnapshot) {
            final RefundCase refund =
                refundSnapshot.data ?? widget.initialRefund;
            return FutureBuilder<QueueOrder>(
              future: _orderFuture,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QueueOrder> orderSnapshot,
                  ) {
                    final QueueOrder? order = orderSnapshot.data;
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        _RefundHeader(refund: refund),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Demande client',
                          icon: Symbols.support_agent_rounded,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _InfoRow(
                                label: 'Type',
                                value: _supportTypeLabel(
                                  refund.supportRequestType,
                                ),
                              ),
                              if (refund.supportRequestDescription
                                  .trim()
                                  .isNotEmpty)
                                _InfoRow(
                                  label: 'Description',
                                  value: refund.supportRequestDescription,
                                  multiline: true,
                                ),
                              _InfoRow(
                                label: 'Demande liée',
                                value: refund.supportRequestId,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Commande liée',
                          icon: Symbols.receipt_long_rounded,
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Référence',
                                value: refund.orderReference,
                              ),
                              _InfoRow(
                                label: 'Client',
                                value: refund.clientName,
                              ),
                              _InfoRow(
                                label: 'WhatsApp',
                                value: formatIvorianPhone(refund.clientWhatsappPhone),
                              ),
                              _InfoRow(
                                label: 'Montant initial',
                                value:
                                    '${_formatAmount(refund.originalAmount)} F',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Paiement initial',
                          icon: Symbols.account_balance_wallet_rounded,
                          child:
                              orderSnapshot.connectionState ==
                                  ConnectionState.waiting
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : order == null
                              ? const Text(
                                  'Impossible de charger le paiement initial.',
                                  style: TextStyle(color: IzyTelColors.error),
                                )
                              : Column(
                                  children: [
                                    const _InfoRow(
                                      label: 'Moyen',
                                      value: 'Wave',
                                    ),
                                    _InfoRow(
                                      label: 'Référence paiement',
                                      value: _paymentReference(order),
                                    ),
                                    _InfoRow(
                                      label: 'Payeur',
                                      value:
                                          order.paymentPayerName ??
                                          'Non renseigné',
                                    ),
                                    _InfoRow(
                                      label: 'Paiement confirmé',
                                      value: order.paymentConfirmedAt == null
                                          ? 'Non disponible'
                                          : _formatDateTime(
                                              order.paymentConfirmedAt!,
                                            ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        _RefundAmountCard(refund: refund),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Traitement',
                          icon: Symbols.gavel_rounded,
                          child: Column(
                            children: [
                              _InfoRow(
                                label: 'Raison',
                                value: refund.reason.label,
                              ),
                              if (refund.reasonNote.trim().isNotEmpty)
                                _InfoRow(
                                  label: 'Note',
                                  value: refund.reasonNote,
                                  multiline: true,
                                ),
                              if (refund.refundReference?.trim().isNotEmpty ==
                                  true)
                                _CopyInfoRow(
                                  label: 'Réf. remboursement',
                                  value: refund.refundReference!,
                                  onCopy: () => _copy(
                                    refund.refundReference!,
                                    'Référence de remboursement copiée.',
                                  ),
                                ),
                              if (refund.rejectionReason?.trim().isNotEmpty ==
                                  true)
                                _InfoRow(
                                  label: 'Motif du rejet',
                                  value: refund.rejectionReason!,
                                  multiline: true,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _RefundTimeline(refund: refund),
                        const SizedBox(height: 18),
                        ..._actions(refund, order),
                      ],
                    );
                  },
            );
          },
        ),
      ),
    );
  }

  List<Widget> _actions(RefundCase refund, QueueOrder? order) {
    if (_isSubmitting) {
      return const <Widget>[Center(child: CircularProgressIndicator())];
    }
    switch (refund.status) {
      case RefundStatus.pendingApproval:
        return <Widget>[
          FilledButton.icon(
            onPressed: () => _approve(refund),
            icon: const Icon(Symbols.check_circle_rounded),
            label: const Text('Approuver le remboursement'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _reject(refund),
            icon: const Icon(Symbols.cancel_rounded),
            label: const Text('Rejeter'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: IzyTelColors.error,
            ),
          ),
        ];
      case RefundStatus.approved:
        return <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: IzyTelColors.warning.withAlpha(22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IzyTelColors.warning.withAlpha(70)),
            ),
            child: const Text(
              'Effectuez maintenant le remboursement réel dans Wave, puis revenez enregistrer sa référence. IzyTel ne déclenche pas automatiquement la transaction.',
              style: TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _markRefunded(refund),
            icon: const Icon(Symbols.payments_rounded),
            label: const Text('Marquer comme remboursé'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ];
      case RefundStatus.refunded:
        return <Widget>[
          if (!refund.customerWasNotified)
            FilledButton.icon(
              onPressed: order == null ? null : () => _notify(refund, order),
              icon: const Icon(Symbols.chat_rounded),
              label: const Text('Notifier le client sur WhatsApp'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          if (!refund.customerWasNotified) const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _reconcile(refund),
            icon: const Icon(Symbols.account_balance_rounded),
            label: const Text('Rapprocher le remboursement'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ];
      case RefundStatus.reconciled:
        return <Widget>[
          if (!refund.customerWasNotified)
            FilledButton.icon(
              onPressed: order == null ? null : () => _notify(refund, order),
              icon: const Icon(Symbols.chat_rounded),
              label: const Text('Notifier le client sur WhatsApp'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            )
          else
            const _ReadOnlyResult(
              icon: Symbols.verified_rounded,
              message:
                  'Remboursement effectué, rapproché et conservé dans l’historique.',
            ),
        ];
      case RefundStatus.rejected:
        return const <Widget>[
          _ReadOnlyResult(
            icon: Symbols.cancel_rounded,
            message:
                'Cette demande de remboursement a été rejetée et reste conservée pour audit.',
          ),
        ];
    }
  }

  Future<void> _approve(RefundCase refund) async {
    final bool confirmed = await _confirm(
      title: 'Approuver le remboursement ?',
      message:
          'Le dossier passera dans « À effectuer ». Aucune transaction Wave ne sera lancée automatiquement.',
      confirmLabel: 'Approuver',
    );
    if (!confirmed) return;
    await _runAction(
      () => widget.repository.approve(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      'Remboursement approuvé. Il reste à l’effectuer dans Wave.',
    );
  }

  Future<void> _reject(RefundCase refund) async {
    final String? reason = await _askText(
      title: 'Rejeter le remboursement',
      label: 'Motif du rejet',
      hint: 'Expliquez pourquoi le remboursement n’est pas retenu.',
      confirmLabel: 'Rejeter',
      maxLength: 500,
      maxLines: 4,
    );
    if (reason == null) return;
    await _runAction(
      () => widget.repository.reject(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
        reason: reason,
      ),
      'Remboursement rejeté et conservé dans l’historique.',
    );
  }

  Future<void> _markRefunded(RefundCase refund) async {
    final String? reference = await _askText(
      title: 'Remboursement effectué',
      label: 'Référence du remboursement Wave',
      hint: 'Ex. référence ou identifiant de la transaction Wave',
      confirmLabel: 'Enregistrer',
      maxLength: 120,
      maxLines: 1,
    );
    if (reference == null) return;
    await _runAction(
      () => widget.repository.markRefunded(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
        refundReference: reference,
      ),
      'Le remboursement a été enregistré comme effectué.',
    );
  }

  Future<void> _reconcile(RefundCase refund) async {
    final bool confirmed = await _confirm(
      title: 'Rapprocher le remboursement ?',
      message:
          'Confirmez que la sortie Wave, le montant et la référence correspondent bien à ce dossier.',
      confirmLabel: 'Rapprocher',
    );
    if (!confirmed) return;
    await _runAction(
      () => widget.repository.reconcile(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      'Remboursement rapproché.',
    );
  }

  Future<void> _notify(RefundCase refund, QueueOrder order) async {
    final String phone = _normalizeWhatsappPhone(order.clientWhatsappPhone);
    if (phone.isEmpty) {
      _showMessage('Aucun numéro WhatsApp client n’est disponible.');
      return;
    }
    final String ref = refund.refundReference?.trim() ?? '';
    final String referenceSentence = ref.isEmpty
        ? ''
        : ' Référence du remboursement : $ref.';
    final String message =
        'Bonjour ${order.clientName}, le remboursement de ${_formatAmount(refund.amount)} F concernant votre commande ${refund.orderReference} a été effectué par IzyTel.$referenceSentence';
    final Uri uri = Uri.https('wa.me', '/$phone', <String, String>{
      'text': message,
    });
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!opened) {
      _showMessage('Impossible d’ouvrir WhatsApp.');
      return;
    }
    final bool confirmed = await _confirm(
      title: 'Client notifié ?',
      message:
          'Confirmez uniquement si le message a réellement été envoyé au client.',
      confirmLabel: 'Oui, envoyé',
    );
    if (!confirmed) return;
    await _runAction(
      () => widget.repository.markCustomerNotified(
        orderId: refund.orderId,
        staffId: widget.user.id,
        staffName: widget.user.name,
      ),
      'Notification WhatsApp enregistrée dans l’historique.',
    );
  }

  Future<String?> _askText({
    required String title,
    required String label,
    required String hint,
    required String confirmLabel,
    required int maxLength,
    required int maxLines,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withAlpha(170),
      builder: (BuildContext context) => RefundTextInputSheet(
        title: title,
        label: label,
        hint: hint,
        confirmLabel: confirmLabel,
        maxLength: maxLength,
        maxLines: maxLines,
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await action();
      if (!mounted) return;
      _showMessage(successMessage);
    } on Object catch (error, stackTrace) {
      debugPrint('[Refund][admin] ERROR $error');
      debugPrint('[Refund][admin] STACK\n$stackTrace');
      if (!mounted) return;
      _showMessage('Impossible d’enregistrer cette action pour le moment.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showMessage(message);
  }

  void _showMessage(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _normalizeWhatsappPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('225')) return digits;
    if (digits.startsWith('0')) return '225$digits';
    return digits;
  }
}

class _RefundCard extends StatelessWidget {
  const _RefundCard({required this.refund, required this.onTap});

  final RefundCase refund;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _refundStatusColor(refund.status);
    return IzyTelSurface(
      radius: IzyTelRadii.card,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Symbols.currency_exchange_rounded,
                  color: statusColor,
                  size: IzyTelIconSize.action,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refund.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontSize: IzyTelTypeScale.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatIvorianPhone(refund.clientWhatsappPhone),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                        fontSize: IzyTelTypeScale.micro,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RefundStatusChip(status: refund.status),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      refund.reason.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IzyTelColors.textPrimary,
                        fontSize: IzyTelTypeScale.cardTitle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      refund.orderReference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_formatAmount(refund.amount)} F',
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: IzyTelColors.primaryStrong,
                  fontSize: IzyTelTypeScale.cardTitle,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _actionIcon(refund.status),
                size: IzyTelIconSize.info,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _actionLabel(refund.status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                financeRelativeTime(refund.updatedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: IzyTelColors.textMuted,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(
                Symbols.chevron_right_rounded,
                color: IzyTelColors.textMuted,
                size: IzyTelIconSize.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RefundHeader extends StatelessWidget {
  const _RefundHeader({required this.refund});

  final RefundCase refund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _refundStatusColor(refund.status).withAlpha(100),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _refundStatusColor(refund.status).withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Symbols.currency_exchange_rounded,
              color: _refundStatusColor(refund.status),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Remboursement',
                  style: TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  refund.orderReference,
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _RefundStatusChip(status: refund.status),
        ],
      ),
    );
  }
}

class _RefundAmountCard extends StatelessWidget {
  const _RefundAmountCard({required this.refund});

  final RefundCase refund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IzyTelColors.primary.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONTANT À REMBOURSER',
            style: TextStyle(
              color: IzyTelColors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatAmount(refund.amount)} F CFA',
            style: const TextStyle(
              color: IzyTelColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Montant commande',
            value: '${_formatAmount(refund.originalAmount)} F',
          ),
          const _InfoRow(label: 'Moyen prévu', value: 'Wave (manuel)'),
        ],
      ),
    );
  }
}

class _RefundTimeline extends StatelessWidget {
  const _RefundTimeline({required this.refund});

  final RefundCase refund;

  @override
  Widget build(BuildContext context) {
    final List<_TimelineItem> items = <_TimelineItem>[
      _TimelineItem(
        label: 'Demande de remboursement créée',
        date: refund.requestedAt,
        actor: refund.requestedByName,
        done: true,
      ),
      if (refund.approvedAt != null)
        _TimelineItem(
          label: 'Remboursement approuvé',
          date: refund.approvedAt!,
          actor: refund.approvedByName ?? 'Administrateur',
          done: true,
        ),
      if (refund.rejectedAt != null)
        _TimelineItem(
          label: 'Remboursement rejeté',
          date: refund.rejectedAt!,
          actor: refund.rejectedByName ?? 'Administrateur',
          done: true,
        ),
      if (refund.refundedAt != null)
        _TimelineItem(
          label: 'Remboursement effectué',
          date: refund.refundedAt!,
          actor: refund.refundedByName ?? 'Administrateur',
          done: true,
        ),
      if (refund.customerNotifiedAt != null)
        _TimelineItem(
          label: 'Client notifié sur WhatsApp',
          date: refund.customerNotifiedAt!,
          actor: refund.customerNotifiedByName ?? 'Administrateur',
          done: true,
        ),
      if (refund.reconciledAt != null)
        _TimelineItem(
          label: 'Remboursement rapproché',
          date: refund.reconciledAt!,
          actor: refund.reconciledByName ?? 'Administrateur',
          done: true,
        ),
    ];

    return _SectionCard(
      title: 'Historique',
      icon: Symbols.history_rounded,
      child: Column(
        children: List<Widget>.generate(items.length, (int index) {
          final _TimelineItem item = items[index];
          return _TimelineRow(item: item, showLine: index < items.length - 1);
        }),
      ),
    );
  }
}

class _TimelineItem {
  const _TimelineItem({
    required this.label,
    required this.date,
    required this.actor,
    required this.done,
  });

  final String label;
  final DateTime date;
  final String actor;
  final bool done;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.showLine});

  final _TimelineItem item;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: IzyTelColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (showLine)
                Container(
                  width: 1,
                  height: 48,
                  color: IzyTelColors.outline,
                ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.actor} · ${_formatDateTime(item.date)}',
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RefundStatusChip extends StatelessWidget {
  const _RefundStatusChip({required this.status});

  final RefundStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = _refundStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
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
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: multiline ? TextAlign.left : TextAlign.right,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyInfoRow extends StatelessWidget {
  const _CopyInfoRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: IzyTelColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copier',
            onPressed: onCopy,
            icon: const Icon(
              Symbols.content_copy_rounded,
              size: 17,
              color: IzyTelColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyResult extends StatelessWidget {
  const _ReadOnlyResult({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Row(
        children: [
          Icon(icon, color: IzyTelColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: IzyTelColors.textSecondary,
                fontSize: 12,
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
      return IzyTelColors.moov;
    case RefundStatus.rejected:
      return IzyTelColors.error;
  }
}

String _actionLabel(RefundStatus status) {
  switch (status) {
    case RefundStatus.pendingApproval:
      return 'Traiter';
    case RefundStatus.approved:
      return 'Finaliser';
    case RefundStatus.refunded:
      return 'Rapprocher';
    case RefundStatus.reconciled:
      return 'Consulter';
    case RefundStatus.rejected:
      return 'Consulter';
  }
}

IconData _actionIcon(RefundStatus status) {
  switch (status) {
    case RefundStatus.pendingApproval:
      return Symbols.gavel_rounded;
    case RefundStatus.approved:
      return Symbols.payments_rounded;
    case RefundStatus.refunded:
      return Symbols.account_balance_rounded;
    case RefundStatus.reconciled:
      return Symbols.visibility_rounded;
    case RefundStatus.rejected:
      return Symbols.visibility_rounded;
  }
}

String _formatAmount(int amount) {
  final String value = amount.toString();
  final StringBuffer buffer = StringBuffer();
  for (int index = 0; index < value.length; index += 1) {
    if (index > 0 && (value.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(value[index]);
  }
  return buffer.toString();
}

String _formatDate(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatDateTime(DateTime value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '${_formatDate(value)} à $hour:$minute';
}

String _paymentReference(QueueOrder order) {
  final String reference = order.paymentReference?.trim() ?? '';
  if (reference.isNotEmpty) return reference;
  final String declared = order.paymentDeclaredReference?.trim() ?? '';
  return declared.isEmpty ? 'Non renseignée' : declared;
}

String _supportTypeLabel(String value) {
  switch (value) {
    case 'paymentNotRecognized':
      return 'Paiement effectué mais non reconnu';
    case 'completedButNotReceived':
      return 'Commande terminée mais rien reçu';
    case 'wrongAmount':
      return 'Mauvais montant';
    case 'wrongNumber':
      return 'Mauvais numéro';
    case 'transactionFailed':
      return 'Transaction échouée';
    case 'other':
    default:
      return 'Autre';
  }
}
