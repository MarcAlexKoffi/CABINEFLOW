import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/payments/domain/repositories/payment_link_repository.dart';
import 'package:cabine_flow/features/payments/presentation/pages/send_wave_link_page.dart';
import 'package:cabine_flow/features/payments/presentation/view_models/payments_view_model.dart';
import 'package:cabine_flow/features/payments/presentation/widgets/payments_widgets.dart';
import 'package:flutter/material.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.paymentLinkRepository,
    required this.onPaymentConfirmed,
    required this.onOpenOrders,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final PaymentLinkRepository paymentLinkRepository;

  final VoidCallback onPaymentConfirmed;
  final VoidCallback onOpenOrders;

  @override
  State<PaymentsPage> createState() {
    return _PaymentsPageState();
  }
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final PaymentsViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = PaymentsViewModel(ordersRepository: widget.ordersRepository);

    _viewModel.loadPayments();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  String _filterLabel(PaymentOrderFilter filter) {
    switch (filter) {
      case PaymentOrderFilter.all:
        return 'Tous';

      case PaymentOrderFilter.linkToSend:
        return 'Liens à envoyer';

      case PaymentOrderFilter.awaitingPayment:
        return 'À vérifier';

      case PaymentOrderFilter.afterExpiration:
        return 'Après expiration';

      case PaymentOrderFilter.confirmed:
        return 'Confirmés';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPaymentLinkPage(QueueOrder order) async {
    final bool? wasSent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext routeContext) {
          return SendWaveLinkPage(
            order: order,
            ordersRepository: widget.ordersRepository,
            paymentLinkRepository: widget.paymentLinkRepository,
          );
        },
      ),
    );

    if (!mounted) {
      return;
    }

    if (wasSent == true) {
      await _viewModel.loadPayments();

      if (!mounted) {
        return;
      }

      _showMessage(
        'Le lien Wave de la commande ${order.reference} a été envoyé.',
      );
    }
  }

  String _formatIvorianPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final String localDigits = digits.startsWith('225')
        ? digits.substring(3)
        : digits;

    if (localDigits.length != 10) {
      return value;
    }

    return '+225 ${<String>[
      localDigits.substring(0, 2),
      localDigits.substring(2, 4),
      localDigits.substring(4, 6),
      localDigits.substring(6, 8),
      localDigits.substring(8, 10),
    ].join(' ')}';
  }

  Future<void> _openPaymentConfirmation(QueueOrder order) async {
    final TextEditingController referenceController = TextEditingController();
    bool paymentWasChecked = false;

    final String? paymentReference = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            // Using sheetContext for MediaQuery prevents dependent unmount crashes during pop
            final double keyboardHeight = MediaQuery.viewInsetsOf(sheetContext).bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 46,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.outlineVariant,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Confirmer le paiement',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Commande ${order.reference}',
                            style: const TextStyle(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          if (order.hasPaymentToReviewAfterExpiration) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(20),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: AppColors.error.withAlpha(90),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.timer_off_outlined,
                                    color: AppColors.error,
                                    size: 20,
                                  ),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'Ce paiement a été déclaré après l’expiration de la commande. Vérifiez-le attentivement avant toute confirmation.',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 11,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.payments_outlined,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                order.clientName,
                                style: const TextStyle(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${formatCfa(order.amount)} F CFA',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                          if (order.paymentPayerName != null ||
                              order.paymentPayerPhone != null ||
                              order.paymentApproximateTime != null ||
                              order.paymentDeclaredReference != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withAlpha(20),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: AppColors.warning.withAlpha(100),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Déclaration du client',
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (order.paymentPayerName != null)
                                    _PaymentDeclarationCheckRow(
                                      label: 'Nom Wave',
                                      value: order.paymentPayerName!,
                                    ),
                                  if (order.paymentPayerPhone != null)
                                    _PaymentDeclarationCheckRow(
                                      label: 'Numéro',
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
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          const Text(
                            'Référence Wave',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          TextField(
                            controller: referenceController,
                            textCapitalization: TextCapitalization.characters,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Facultatif — Ex. W-8942AB',
                              hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
                              prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.onSurfaceVariant),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLowest,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.outlineVariant),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Sans référence, CabineFlow générera une référence MAN-...',
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 14),
                          CheckboxListTile(
                            value: paymentWasChecked,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            checkColor: AppColors.onPrimary,
                            activeColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.outlineVariant, width: 2),
                            title: const Text(
                              'J’ai vérifié ce paiement dans mon compte Wave.',
                              style: TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Cette action enverra la commande dans la file à traiter.',
                              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10),
                            ),
                            onChanged: (bool? value) {
                              setSheetState(() {
                                paymentWasChecked = value ?? false;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: paymentWasChecked
                                ? () {
                                    Navigator.of(
                                      sheetContext,
                                    ).pop(referenceController.text.trim());
                                  }
                                : null,
                            icon: const Icon(Icons.verified_rounded),
                            label: const Text('Confirmer le paiement'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              disabledBackgroundColor: AppColors.surfaceContainerLowest,
                              disabledForegroundColor: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.onSurfaceVariant,
                            ),
                            child: const Text('Annuler'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    referenceController.dispose();

    if (paymentReference == null || !mounted) {
      return;
    }

    final bool successful = await _viewModel.confirmPayment(
      order: order,
      paymentReference: paymentReference.trim().isEmpty
          ? null
          : paymentReference,
    );

    if (!mounted) {
      return;
    }

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
                color: AppColors.background,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: PaymentsHeader(
                  userName: widget.user.name,
                  onNotificationsPressed: () {
                    _showMessage(
                      'Les notifications seront ajoutées ultérieurement.',
                    );
                  },
                ),
              ),
              Divider(height: 1, color: AppColors.outlineVariant.withAlpha(70)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _viewModel.loadPayments,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      Text(
                        'Suivi des paiements',
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Vérification manuelle des paiements Wave',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PaymentOrderFilter.values.map((
                            PaymentOrderFilter filter,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: PaymentFilterPill(
                                label: _filterLabel(filter),
                                count: _viewModel.countForFilter(filter),
                                isSelected: _viewModel.selectedFilter == filter,
                                onPressed: () {
                                  _viewModel.selectFilter(filter);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_viewModel.isLoading && _viewModel.allOrders.isEmpty)
                        const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_viewModel.errorMessage != null &&
                          _viewModel.allOrders.isEmpty)
                        _PaymentsErrorState(
                          message: _viewModel.errorMessage!,
                          onRetry: _viewModel.loadPayments,
                        )
                      else if (visibleOrders.isEmpty)
                        const _PaymentsEmptyState()
                      else
                        ...visibleOrders.map((QueueOrder order) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: PaymentTrackingCard(
                              order: order,
                              isProcessing: _viewModel.isProcessing(order.id),
                              onSendPaymentLink: () {
                                _openPaymentLinkPage(order);
                              },
                              onConfirmPayment: () {
                                _openPaymentConfirmation(order);
                              },
                              onOpenOrders: widget.onOpenOrders,
                            ),
                          );
                        }),
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

class _PaymentsErrorState extends StatelessWidget {
  const _PaymentsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 46, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _PaymentsEmptyState extends StatelessWidget {
  const _PaymentsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(70)),
      ),
      child: const Column(
        children: [
          Icon(Icons.payments_outlined, size: 46, color: AppColors.primary),
          SizedBox(height: 12),
          Text(
            'Aucun paiement dans cette catégorie.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
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
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

