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

    _viewModel = PaymentsViewModel(
      ordersRepository: widget.ordersRepository,
    );

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
        return 'En attente';

      case PaymentOrderFilter.confirmed:
        return 'Confirmés';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
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

  Future<void> _openPaymentConfirmation(QueueOrder order) async {
    final TextEditingController referenceController = TextEditingController();
    bool paymentWasChecked = false;

    final String? paymentReference = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
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
                        decoration: const InputDecoration(
                          hintText: 'Facultatif — Ex. W-8942AB',
                          prefixIcon: Icon(Icons.tag_rounded),
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
                        title: const Text(
                          'J’ai vérifié ce paiement dans mon compte Wave.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Cette action enverra la commande dans la file à traiter.',
                          style: TextStyle(fontSize: 10),
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
                                Navigator.of(sheetContext).pop(
                                  referenceController.text.trim(),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Confirmer le paiement'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
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

    if (paymentReference == null || !mounted) {
      return;
    }

    final bool successful = await _viewModel.confirmPayment(
      order: order,
      paymentReference:
          paymentReference.trim().isEmpty ? null : paymentReference,
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
              Divider(
                height: 1,
                color: AppColors.outlineVariant.withAlpha(70),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _viewModel.loadPayments,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [
                      Text(
                        'Suivi des paiements',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Vérification manuelle des paiements Wave',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PaymentOrderFilter.values.map(
                            (PaymentOrderFilter filter) {
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
                            },
                          ).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_viewModel.isLoading && _viewModel.allOrders.isEmpty)
                        const SizedBox(
                          height: 300,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
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
  const _PaymentsErrorState({
    required this.message,
    required this.onRetry,
  });

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
          const Icon(
            Icons.cloud_off_rounded,
            size: 46,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
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
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(70),
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.payments_outlined,
            size: 46,
            color: AppColors.primary,
          ),
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