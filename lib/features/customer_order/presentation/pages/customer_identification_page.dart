import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_support_button.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerIdentificationPage extends StatefulWidget {
  const CustomerIdentificationPage({
    super.key,
    required this.viewModel,
    required this.onOpenHistory,
    required this.onOpenRecovery,
    required this.onResumeOrder,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenRecovery;
  final ValueChanged<CustomerOrderReceipt> onResumeOrder;

  @override
  State<CustomerIdentificationPage> createState() {
    return _CustomerIdentificationPageState();
  }
}

class _CustomerIdentificationPageState
    extends State<CustomerIdentificationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _whatsappController;

  @override
  void initState() {
    super.initState();

    final CustomerIdentity? identity = widget.viewModel.draft.identity;

    _nameController = TextEditingController(text: identity?.name ?? '');

    _whatsappController = TextEditingController(
      text: identity?.whatsappNumber.displayValue ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Saisissez votre nom ou surnom.';
    }

    if (name.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères.';
    }

    if (name.length > 50) {
      return 'Le nom ne doit pas dépasser 50 caractères.';
    }

    return null;
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    widget.viewModel.saveIdentity(
      name: _nameController.text,
      whatsappInput: _whatsappController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrderReceipt? activeOrder = widget.viewModel.activeOrder;

    return CustomerFlowScaffold(
      currentStep: 1,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Passez votre commande',
      subtitle: 'Indiquez simplement votre nom et votre numéro WhatsApp.',
      onTopBack: () {
        Navigator.of(context).maybePop();
      },
      onBottomBack: null,
      onContinue: _continue,
      footer: _IdentificationFooter(
        onOpenHistory: widget.onOpenHistory,
        onOpenRecovery: widget.onOpenRecovery,
        hasHistory: widget.viewModel.customerOrders.isNotEmpty,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.viewModel.isLoadingHistory) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 18),
          ],
          if (activeOrder != null) ...[
            _ActiveOrderCard(
              order: activeOrder,
              onResume: () => widget.onResumeOrder(activeOrder),
            ),
            const SizedBox(height: 20),
          ],
          Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CustomerAppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: CustomerAppColors.surfaceContainerHighest,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FieldLabel(text: 'Nom ou surnom'),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      hintText: 'Ex. Jean Dupont',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 22),
                  const _FieldLabel(text: 'Numéro WhatsApp'),
                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
                      LengthLimitingTextInputFormatter(24),
                    ],
                    decoration: const InputDecoration(
                      hintText: '+225 07 00 00 00 00',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: WhatsappPhoneNumber.validate,
                    onFieldSubmitted: (_) {
                      _continue();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order, required this.onResume});

  final CustomerOrderReceipt order;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final (String statusLabel, IconData statusIcon) = _activeStatus(order);
    final bool isExpired = order.status == QueueOrderStatus.expired;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFD3FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: CustomerAppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isExpired
                          ? 'Cette commande nécessite votre attention'
                          : 'Vous avez une commande en cours',
                      style: const TextStyle(
                        color: CustomerAppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isExpired
                          ? 'Consultez son état ou déclarez un paiement déjà effectué.'
                          : 'Reprenez exactement là où vous vous êtes arrêté.',
                      style: const TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: CustomerAppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.reference,
                        style: const TextStyle(
                          color: CustomerAppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$statusLabel · ${formatCfa(order.draft.amount!)} CFA',
                        style: const TextStyle(
                          color: CustomerAppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: CustomerAppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Reprendre le suivi'),
          ),
        ],
      ),
    );
  }

  (String, IconData) _activeStatus(CustomerOrderReceipt order) {
    switch (order.status) {
      case QueueOrderStatus.awaitingPayment:
        return ('Paiement à effectuer', Icons.account_balance_wallet_outlined);
      case QueueOrderStatus.paymentToVerify:
        return ('Paiement à vérifier', Icons.schedule_rounded);
      case QueueOrderStatus.paidReady:
        return ('Paiement confirmé', Icons.verified_rounded);
      case QueueOrderStatus.inProgress:
        return ('En cours de traitement', Icons.sync_rounded);
      case QueueOrderStatus.onHold:
        return (
          'Temporairement en attente',
          Icons.pause_circle_outline_rounded,
        );
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return ('Transaction effectuée', Icons.task_alt_rounded);
      case QueueOrderStatus.refundPending:
        return ('Remboursement en cours', Icons.currency_exchange_rounded);
      case QueueOrderStatus.expired:
        return order.hasPaymentToReviewAfterExpiration
            ? (
                'Paiement après expiration à examiner',
                Icons.manage_search_rounded,
              )
            : ('Commande expirée', Icons.timer_off_outlined);
      case QueueOrderStatus.completed:
      case QueueOrderStatus.failed:
      case QueueOrderStatus.cancelled:
      case QueueOrderStatus.refunded:
        return ('Commande mise à jour', Icons.receipt_long_outlined);
    }
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _IdentificationFooter extends StatelessWidget {
  const _IdentificationFooter({
    required this.onOpenHistory,
    required this.onOpenRecovery,
    required this.hasHistory,
  });

  final VoidCallback onOpenHistory;
  final VoidCallback onOpenRecovery;
  final bool hasHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: onOpenHistory,
          icon: const Icon(Icons.history_rounded),
          label: Text(hasHistory ? 'Voir mes commandes' : 'Historique'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: onOpenRecovery,
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Retrouver une commande'),
        ),
        const SizedBox(height: 2),
        const CustomerSupportButton(
          label: 'Besoin d’aide ? Contacter le service client',
        ),
        const SizedBox(height: 10),
        const _NoAccountMessage(),
      ],
    );
  }
}

class _NoAccountMessage extends StatelessWidget {
  const _NoAccountMessage();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: CustomerAppColors.onSurfaceVariant,
        ),
        SizedBox(width: 7),
        Text(
          'Aucun compte à créer.',
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
