import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:flutter/material.dart';

class CustomerConfirmationPage extends StatelessWidget {
  const CustomerConfirmationPage({
    super.key,
    required this.viewModel,
  });

  final CustomerOrderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final CustomerOrderReceipt receipt = viewModel.receipt!;

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: CustomerAppColors.surface,
              border: Border.symmetric(
                vertical: BorderSide(
                  color: Color(0x33C2C6D8),
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const _ConfirmationTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        18,
                        20,
                        34,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _CompletedProgress(),
                          const SizedBox(height: 30),
                          const _SuccessHeader(),
                          const SizedBox(height: 30),
                          _ReferenceCard(receipt: receipt),
                          const SizedBox(height: 24),
                          _TransactionDetailsCard(receipt: receipt),
                          const SizedBox(height: 24),
                          _TrackingCard(receipt: receipt),
                        ],
                      ),
                    ),
                  ),
                  _NewOrderAction(onPressed: viewModel.restart),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationTopBar extends StatelessWidget {
  const _ConfirmationTopBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 64,
      child: Center(
        child: Text(
          'CabineFlow',
          style: TextStyle(
            color: CustomerAppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CompletedProgress extends StatelessWidget {
  const _CompletedProgress();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ÉTAPE 8 SUR 8',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: const LinearProgressIndicator(
            minHeight: 4,
            value: 1,
            color: CustomerAppColors.success,
          ),
        ),
      ],
    );
  }
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: CustomerAppColors.success,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x3322C55E),
                blurRadius: 18,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: SizedBox(
            width: 76,
            height: 76,
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
        SizedBox(height: 22),
        Text(
          'Commande reçue',
          style: TextStyle(
            color: CustomerAppColors.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Merci ! Votre déclaration de paiement a été enregistrée.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.receipt});

  final CustomerOrderReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RÉFÉRENCE DE COMMANDE',
            style: TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            receipt.reference,
            style: const TextStyle(
              color: CustomerAppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Conservez cette référence pour toute demande concernant '
            'cette commande.',
            style: TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailsCard extends StatelessWidget {
  const _TransactionDetailsCard({required this.receipt});

  final CustomerOrderReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final draft = receipt.draft;

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Détails de la transaction',
            style: TextStyle(
              color: CustomerAppColors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Réseau',
            value: draft.network!.customerLabel,
          ),
          _DetailRow(
            label: 'Offre',
            value: draft.selectedOfferLabel!,
          ),
          _DetailRow(
            label: 'Numéro bénéficiaire',
            value: draft.beneficiaryNumber!.displayValue,
          ),
          _DetailRow(
            label: 'Montant déclaré',
            value: '${formatCfa(draft.amount!)} CFA',
            isAmount: true,
            isLast: true,
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
    this.isAmount = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isAmount;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: CustomerAppColors.surfaceContainerHigh,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isAmount
                    ? CustomerAppColors.primary
                    : CustomerAppColors.onSurface,
                fontSize: isAmount ? 18 : 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.receipt});

  final CustomerOrderReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Suivi de commande',
            style: TextStyle(
              color: CustomerAppColors.onSurface,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 22),
          _TrackingStep(
            title: 'Paiement déclaré',
            subtitle: _formatDate(receipt.paymentDeclaredAt),
            state: _TrackingStepState.done,
          ),
          const _TrackingStep(
            title: 'Vérification du paiement',
            subtitle:
                'L’opérateur vérifie la transaction dans Wave.',
            state: _TrackingStepState.active,
          ),
          const _TrackingStep(
            title: 'Commande transmise',
            subtitle:
                'La commande sera ajoutée à la file après validation.',
            state: _TrackingStepState.pending,
          ),
          const _TrackingStep(
            title: 'Traitement terminé',
            state: _TrackingStepState.pending,
            isLast: true,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final String hours = date.hour.toString().padLeft(2, '0');
    final String minutes = date.minute.toString().padLeft(2, '0');
    return 'Aujourd’hui, $hours:$minutes';
  }
}

enum _TrackingStepState { done, active, pending }

class _TrackingStep extends StatelessWidget {
  const _TrackingStep({
    required this.title,
    required this.state,
    this.subtitle,
    this.isLast = false,
  });

  final String title;
  final String? subtitle;
  final _TrackingStepState state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool done = state == _TrackingStepState.done;
    final bool active = state == _TrackingStepState.active;
    final Color color = done || active
        ? CustomerAppColors.success
        : CustomerAppColors.surfaceContainerHighest;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 13,
                          color: Colors.white,
                        )
                      : active
                          ? const Center(
                              child: SizedBox(
                                width: 7,
                                height: 7,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            )
                          : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: CustomerAppColors
                          .surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: isLast ? 0 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: active
                          ? CustomerAppColors.success
                          : state == _TrackingStepState.pending
                              ? CustomerAppColors.onSurfaceVariant
                              : CustomerAppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color:
                            CustomerAppColors.onSurfaceVariant,
                        fontSize: 11,
                        height: 1.4,
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

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NewOrderAction extends StatelessWidget {
  const _NewOrderAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: FilledButton(
          onPressed: onPressed,
          child: const Text('Nouvelle commande'),
        ),
      ),
    );
  }
}
