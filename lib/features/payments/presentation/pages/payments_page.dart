import 'dart:async';

import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/features/payments/presentation/view_models/payments_view_model.dart';
import 'package:cabine_flow/features/payments/presentation/widgets/payments_widgets.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.onPaymentConfirmed,
    required this.onOpenOrders,
    this.onOpenOrder,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final VoidCallback onPaymentConfirmed;
  final VoidCallback onOpenOrders;
  final ValueChanged<QueueOrder>? onOpenOrder;

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  Timer? _clockTimer;
  late final PaymentsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
    _viewModel = PaymentsViewModel(ordersRepository: widget.ordersRepository);
    _viewModel.startRealtime();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _viewModel.dispose();
    super.dispose();
  }

  String _filterLabel(PaymentOrderFilter filter) {
    return switch (filter) {
      PaymentOrderFilter.all => 'Tous',
      PaymentOrderFilter.linkToSend => 'Liens',
      PaymentOrderFilter.awaitingPayment => 'À vérifier',
      PaymentOrderFilter.afterExpiration => 'Expirés',
      PaymentOrderFilter.confirmed => 'Confirmés',
    };
  }

  Color? _filterEmphasis(PaymentOrderFilter filter) {
    return switch (filter) {
      PaymentOrderFilter.awaitingPayment => IzyTelColors.warning,
      PaymentOrderFilter.afterExpiration => IzyTelColors.error,
      PaymentOrderFilter.confirmed => IzyTelColors.success,
      _ => null,
    };
  }

  List<PaymentOrderFilter> get _visibleFilters {
    final List<PaymentOrderFilter> filters = <PaymentOrderFilter>[
      PaymentOrderFilter.all,
      PaymentOrderFilter.awaitingPayment,
      PaymentOrderFilter.afterExpiration,
      PaymentOrderFilter.confirmed,
    ];
    if (_viewModel.countForFilter(PaymentOrderFilter.linkToSend) > 0) {
      filters.insert(1, PaymentOrderFilter.linkToSend);
    }
    return filters;
  }

  bool _requiresManualVerification(QueueOrder order) {
    return order.hasPaymentToReviewAfterExpiration ||
        (order.source == OrderSource.customerWeb &&
            order.paymentStatus == OrderPaymentStatus.declared &&
            (order.status == QueueOrderStatus.paymentToVerify ||
                order.status == QueueOrderStatus.awaitingPayment));
  }

  int get _verificationAmount => _viewModel.allOrders
      .where(_requiresManualVerification)
      .fold<int>(0, (int total, QueueOrder order) => total + order.amount);

  int get _verificationCount =>
      _viewModel.allOrders.where(_requiresManualVerification).length;

  void _showMessage(String message) {
    IzyTelFeedback.show(context, message);
  }

  String _formatIvorianPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final String localDigits = digits.startsWith('225')
        ? digits.substring(3)
        : digits;
    if (localDigits.length != 10) return value;
    return '+225 ${<String>[localDigits.substring(0, 2), localDigits.substring(2, 4), localDigits.substring(4, 6), localDigits.substring(6, 8), localDigits.substring(8, 10)].join(' ')}';
  }

  Future<void> _openPaymentConfirmation(QueueOrder order) async {
    final TextEditingController referenceController = TextEditingController();
    bool paymentWasChecked = false;

    final String? paymentReference = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            final double keyboardHeight = MediaQuery.viewInsetsOf(
              sheetContext,
            ).bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * .90,
                ),
                decoration: const BoxDecoration(
                  color: IzyTelColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(IzyTelRadii.sheet),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: IzyTelColors.outlineStrong,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        order.hasPaymentToReviewAfterExpiration
                            ? 'Examiner le paiement'
                            : 'Vérifier le paiement',
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(
                              color: IzyTelColors.textPrimary,
                              fontSize: IzyTelTypeScale.title2,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.35,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.reference,
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(
                              color: IzyTelColors.textMuted,
                              fontSize: IzyTelTypeScale.micro,
                            ),
                      ),
                      if (order.hasPaymentToReviewAfterExpiration) ...[
                        const SizedBox(height: 14),
                        _PaymentWarning(
                          icon: Symbols.timer_off_rounded,
                          title: 'Paiement déclaré après expiration',
                          message:
                              'Vérifie attentivement la transaction dans Wave avant toute confirmation.',
                        ),
                      ],
                      const SizedBox(height: 16),
                      _PaymentSheetSummary(
                        order: order,
                        formattedPhone: _formatIvorianPhone(
                          order.beneficiaryPhone,
                        ),
                      ),
                      if (_hasDeclaredPaymentDetails(order)) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
                          decoration: BoxDecoration(
                            color: IzyTelColors.warningSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: IzyTelColors.warning.withAlpha(70),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Symbols.receipt_long_rounded,
                                    color: IzyTelColors.warning,
                                    size: IzyTelIconSize.info,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Déclaration du client',
                                    style: TextStyle(
                                      color: IzyTelColors.textPrimary,
                                      fontSize: IzyTelTypeScale.label,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (order.paymentPayerName != null)
                                _PaymentDeclarationCheckRow(
                                  label: 'Nom Wave',
                                  value: order.paymentPayerName!,
                                ),
                              if (order.paymentPayerPhone != null)
                                _PaymentDeclarationCheckRow(
                                  label: 'Numéro payeur',
                                  value: _formatIvorianPhone(
                                    order.paymentPayerPhone!,
                                  ),
                                ),
                              if (order.paymentApproximateTime != null)
                                _PaymentDeclarationCheckRow(
                                  label: 'Heure annoncée',
                                  value: order.paymentApproximateTime!,
                                ),
                              if (order.paymentDeclaredReference != null)
                                _PaymentDeclarationCheckRow(
                                  label: 'Référence déclarée',
                                  value: order.paymentDeclaredReference!,
                                  isLast: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Référence Wave',
                        style: TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.label,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: referenceController,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.text,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Facultatif — Ex. W-8942AB',
                          prefixIcon: const Icon(
                            Symbols.tag_rounded,
                            color: IzyTelColors.textSecondary,
                            size: IzyTelIconSize.info,
                          ),
                          filled: true,
                          fillColor: IzyTelColors.surfaceMuted,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              IzyTelRadii.input,
                            ),
                            borderSide: const BorderSide(
                              color: IzyTelColors.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              IzyTelRadii.input,
                            ),
                            borderSide: const BorderSide(
                              color: IzyTelColors.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              IzyTelRadii.input,
                            ),
                            borderSide: const BorderSide(
                              color: IzyTelColors.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Si elle est vide, une référence MAN-… sera générée automatiquement.',
                        style: TextStyle(
                          color: IzyTelColors.textMuted,
                          fontSize: IzyTelTypeScale.micro,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setSheetState(() {
                            paymentWasChecked = !paymentWasChecked;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: paymentWasChecked,
                                onChanged: (bool? value) {
                                  setSheetState(() {
                                    paymentWasChecked = value ?? false;
                                  });
                                },
                                activeColor: IzyTelColors.primary,
                                checkColor: IzyTelColors.surface,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              const SizedBox(width: 7),
                              const Flexible(
                                fit: FlexFit.loose,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'J’ai vérifié ce paiement dans Wave.',
                                      style: TextStyle(
                                        color: IzyTelColors.textPrimary,
                                        fontSize: IzyTelTypeScale.label,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'La commande sera envoyée dans la file à traiter après confirmation.',
                                      style: TextStyle(
                                        color: IzyTelColors.textSecondary,
                                        fontSize: IzyTelTypeScale.micro,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: paymentWasChecked
                              ? () {
                                  Navigator.of(
                                    sheetContext,
                                  ).pop(referenceController.text.trim());
                                }
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: IzyTelColors.primary,
                            foregroundColor: IzyTelColors.surface,
                            disabledBackgroundColor: IzyTelColors.surfaceMuted,
                            disabledForegroundColor: IzyTelColors.textMuted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                IzyTelRadii.button,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Symbols.verified_rounded,
                            size: IzyTelIconSize.info,
                          ),
                          label: const Text(
                            'Confirmer le paiement',
                            style: TextStyle(
                              fontSize: IzyTelTypeScale.label,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: IzyTelColors.textSecondary,
                        ),
                        child: const Text('Annuler'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    referenceController.dispose();
    if (paymentReference == null || !mounted) return;

    final bool successful = await _viewModel.confirmPayment(
      order: order,
      paymentReference: paymentReference.trim().isEmpty
          ? null
          : paymentReference,
    );

    if (!mounted) return;
    if (!successful) {
      _showMessage(
        _viewModel.errorMessage ?? 'Impossible de confirmer ce paiement.',
      );
      return;
    }

    widget.onPaymentConfirmed();
    _showMessage(
      'Paiement confirmé. La commande ${order.reference} est maintenant prête à traiter.',
    );
  }

  bool _hasDeclaredPaymentDetails(QueueOrder order) {
    return order.paymentPayerName != null ||
        order.paymentPayerPhone != null ||
        order.paymentApproximateTime != null ||
        order.paymentDeclaredReference != null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final List<QueueOrder> visibleOrders = _viewModel.visibleOrders;

        return SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                color: IzyTelColors.background,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: PaymentsTopBar(
                  onRefreshPressed: _viewModel.loadPayments,
                ),
              ),
              const Divider(height: 1, color: IzyTelColors.outline),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _viewModel.loadPayments,
                  color: IzyTelColors.primary,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: PaymentAttentionSummary(
                          count: _verificationCount,
                          amount: _verificationAmount,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _visibleFilters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 7),
                          itemBuilder: (BuildContext context, int index) {
                            final PaymentOrderFilter filter =
                                _visibleFilters[index];
                            return PaymentFilterPill(
                              label: _filterLabel(filter),
                              count: _viewModel.countForFilter(filter),
                              isSelected: _viewModel.selectedFilter == filter,
                              emphasis: _filterEmphasis(filter),
                              onPressed: () => _viewModel.selectFilter(filter),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_viewModel.errorMessage != null &&
                          _viewModel.allOrders.isNotEmpty) ...[
                        _PaymentsInlineError(message: _viewModel.errorMessage!),
                        const SizedBox(height: 12),
                      ],
                      if (_viewModel.isLoading && _viewModel.allOrders.isEmpty)
                        const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: IzyTelColors.primary,
                            ),
                          ),
                        )
                      else if (_viewModel.errorMessage != null &&
                          _viewModel.allOrders.isEmpty)
                        _PaymentsErrorState(
                          message: _viewModel.errorMessage!,
                          onRetry: _viewModel.loadPayments,
                        )
                      else if (visibleOrders.isEmpty)
                        _PaymentsEmptyState(filter: _viewModel.selectedFilter)
                      else
                        ...visibleOrders.map(
                          (QueueOrder order) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: PaymentTrackingCard(
                              order: order,
                              isProcessing: _viewModel.isProcessing(order.id),
                              onConfirmPayment: () {
                                _openPaymentConfirmation(order);
                              },
                              onOpenOrders: () {
                                final ValueChanged<QueueOrder>? openOrder =
                                    widget.onOpenOrder;
                                if (openOrder != null) {
                                  openOrder(order);
                                } else {
                                  widget.onOpenOrders();
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PaymentWarning extends StatelessWidget {
  const _PaymentWarning({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.error.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: IzyTelColors.error, size: IzyTelIconSize.action),
          const SizedBox(width: 9),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: IzyTelColors.error,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: const TextStyle(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.micro,
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

class _PaymentSheetSummary extends StatelessWidget {
  const _PaymentSheetSummary({
    required this.order,
    required this.formattedPhone,
  });

  final QueueOrder order;
  final String formattedPhone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: IzyTelColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: switch (order.network) {
                    MobileNetwork.orange => IzyTelColors.orangeSoft,
                    MobileNetwork.mtn => IzyTelColors.mtnSoft,
                    MobileNetwork.moov => IzyTelColors.moovSoft,
                  },
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Image.asset(
                  networkAsset(order.network),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  order.offerLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.cardTitle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formattedPhone,
                style: const TextStyle(
                  color: IzyTelColors.textPrimary,
                  fontSize: IzyTelTypeScale.transactionNumber,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatCfaFull(order.amount),
                style: const TextStyle(
                  color: IzyTelColors.primaryStrong,
                  fontSize: IzyTelTypeScale.money,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Client · ${order.clientName}',
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDeclarationCheckRow extends StatelessWidget {
  const _PaymentDeclarationCheckRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: IzyTelColors.outline)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 3,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.micro,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsInlineError extends StatelessWidget {
  const _PaymentsInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IzyTelColors.errorSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: IzyTelColors.error.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(
            Symbols.error_rounded,
            color: IzyTelColors.error,
            size: IzyTelIconSize.info,
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              message,
              style: const TextStyle(
                color: IzyTelColors.error,
                fontSize: IzyTelTypeScale.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsErrorState extends StatelessWidget {
  const _PaymentsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Symbols.error_rounded,
            color: IzyTelColors.error,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Symbols.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}

class _PaymentsEmptyState extends StatelessWidget {
  const _PaymentsEmptyState({required this.filter});

  final PaymentOrderFilter filter;

  String get _title => switch (filter) {
    PaymentOrderFilter.awaitingPayment => 'Aucun paiement à vérifier',
    PaymentOrderFilter.afterExpiration => 'Aucun paiement expiré',
    PaymentOrderFilter.confirmed => 'Aucun paiement confirmé',
    PaymentOrderFilter.linkToSend => 'Aucun lien à envoyer',
    PaymentOrderFilter.all => 'Aucun paiement à afficher',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 38),
      decoration: BoxDecoration(
        color: IzyTelColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IzyTelColors.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: IzyTelColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Symbols.wallet_rounded,
              color: IzyTelColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.cardTitle,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'La liste se met à jour automatiquement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.micro,
            ),
          ),
        ],
      ),
    );
  }
}
