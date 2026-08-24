import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:flutter/material.dart';

class CustomerConfirmationPage extends StatelessWidget {
  const CustomerConfirmationPage({
    super.key,
    required this.viewModel,
    required this.onOpenHistory,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback onOpenHistory;

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
                vertical: BorderSide(color: Color(0x33C2C6D8)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const _ConfirmationTopBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _CompletedProgress(),
                          const SizedBox(height: 30),
                          _StatusHeader(receipt: receipt),
                          const SizedBox(height: 30),
                          _ReferenceCard(receipt: receipt),
                          const SizedBox(height: 24),
                          _TransactionDetailsCard(receipt: receipt),
                          const SizedBox(height: 24),
                          _TrackingCard(
                            receipt: receipt,
                            errorMessage: viewModel.trackingErrorMessage,
                          ),
                        ],
                      ),
                    ),
                  ),
                  _NewOrderAction(
                    onNewOrder: viewModel.restart,
                    onOpenHistory: onOpenHistory,
                  ),
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

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.receipt});

  final CustomerOrderReceipt receipt;

  Color get _color {
    switch (receipt.status) {
      case QueueOrderStatus.failed:
      case QueueOrderStatus.expired:
      case QueueOrderStatus.cancelled:
        return CustomerAppColors.error;
      case QueueOrderStatus.onHold:
      case QueueOrderStatus.refundPending:
        return const Color(0xFFF59E0B);
      case QueueOrderStatus.awaitingPayment:
      case QueueOrderStatus.paymentToVerify:
      case QueueOrderStatus.paidReady:
      case QueueOrderStatus.inProgress:
      case QueueOrderStatus.awaitingCustomerConfirmation:
      case QueueOrderStatus.completed:
      case QueueOrderStatus.refunded:
        return CustomerAppColors.success;
    }
  }

  IconData get _icon {
    switch (receipt.status) {
      case QueueOrderStatus.failed:
      case QueueOrderStatus.expired:
      case QueueOrderStatus.cancelled:
        return Icons.error_rounded;
      case QueueOrderStatus.onHold:
      case QueueOrderStatus.refundPending:
        return Icons.schedule_rounded;
      case QueueOrderStatus.inProgress:
        return Icons.sync_rounded;
      case QueueOrderStatus.awaitingPayment:
      case QueueOrderStatus.paymentToVerify:
      case QueueOrderStatus.paidReady:
      case QueueOrderStatus.awaitingCustomerConfirmation:
      case QueueOrderStatus.completed:
      case QueueOrderStatus.refunded:
        return Icons.check_circle_rounded;
    }
  }

  String get _title {
    switch (receipt.status) {
      case QueueOrderStatus.awaitingPayment:
        return 'Commande enregistrée';
      case QueueOrderStatus.paymentToVerify:
        return 'Commande reçue';
      case QueueOrderStatus.paidReady:
        return 'Paiement confirmé';
      case QueueOrderStatus.inProgress:
        return 'Commande en cours';
      case QueueOrderStatus.onHold:
        return 'Commande en attente';
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return 'Transaction effectuée';
      case QueueOrderStatus.completed:
        return 'Commande terminée';
      case QueueOrderStatus.failed:
        return 'Traitement non abouti';
      case QueueOrderStatus.expired:
        return receipt.hasPaymentToReviewAfterExpiration
            ? 'Paiement à examiner'
            : 'Commande expirée';
      case QueueOrderStatus.cancelled:
        return 'Commande annulée';
      case QueueOrderStatus.refundPending:
        return 'Remboursement en cours';
      case QueueOrderStatus.refunded:
        return 'Remboursement effectué';
    }
  }

  String get _message {
    switch (receipt.status) {
      case QueueOrderStatus.awaitingPayment:
        return 'Votre commande a été créée. Finalisez maintenant le paiement Wave.';
      case QueueOrderStatus.paymentToVerify:
        return 'Votre déclaration de paiement a été enregistrée et sera vérifiée.';
      case QueueOrderStatus.paidReady:
        return 'Votre paiement a été confirmé. La commande attend sa prise en charge.';
      case QueueOrderStatus.inProgress:
        return 'Un opérateur traite actuellement votre commande.';
      case QueueOrderStatus.onHold:
        return 'Le traitement est temporairement suspendu. Vous serez informé de la suite.';
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return 'La transaction a été effectuée. La confirmation finale est en préparation.';
      case QueueOrderStatus.completed:
        return 'Votre commande a été entièrement traitée.';
      case QueueOrderStatus.failed:
        return receipt.failureMessage ??
            'La transaction n’a pas pu être réalisée. Un opérateur examinera la situation.';
      case QueueOrderStatus.expired:
        return receipt.hasPaymentToReviewAfterExpiration
            ? 'Votre paiement a été déclaré après l’expiration. Un opérateur doit maintenant l’examiner manuellement.'
            : 'Le délai de paiement de six heures est dépassé. Aucun paiement confirmé n’a été retrouvé.';
      case QueueOrderStatus.cancelled:
        return 'Cette commande a été annulée.';
      case QueueOrderStatus.refundPending:
        return 'Le remboursement est en cours de traitement.';
      case QueueOrderStatus.refunded:
        return 'Le remboursement lié à cette commande a été effectué.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color;

    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(50),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: SizedBox(
            width: 76,
            height: 76,
            child: Icon(_icon, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CustomerAppColors.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _message,
          textAlign: TextAlign.center,
          style: const TextStyle(
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
          _DetailRow(label: 'Réseau', value: draft.network!.customerLabel),
          _DetailRow(label: 'Offre', value: draft.selectedOfferLabel!),
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
  const _TrackingCard({required this.receipt, this.errorMessage});

  final CustomerOrderReceipt receipt;
  final String? errorMessage;

  bool get _paymentConfirmed =>
      receipt.paymentStatus == OrderPaymentStatus.confirmed;

  bool get _processingStarted {
    return receipt.status == QueueOrderStatus.inProgress ||
        receipt.status == QueueOrderStatus.onHold ||
        receipt.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        receipt.status == QueueOrderStatus.completed ||
        receipt.status == QueueOrderStatus.failed ||
        receipt.status == QueueOrderStatus.refundPending ||
        receipt.status == QueueOrderStatus.refunded;
  }

  bool get _processingFinished {
    return receipt.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        receipt.status == QueueOrderStatus.completed ||
        receipt.status == QueueOrderStatus.failed ||
        receipt.status == QueueOrderStatus.refundPending ||
        receipt.status == QueueOrderStatus.refunded;
  }

  _TrackingStepState get _verificationState {
    if (_paymentConfirmed) {
      return _TrackingStepState.done;
    }

    if (receipt.hasPaymentToReviewAfterExpiration) {
      return _TrackingStepState.active;
    }

    if (receipt.paymentStatus == OrderPaymentStatus.rejected ||
        receipt.paymentStatus == OrderPaymentStatus.expired) {
      return _TrackingStepState.error;
    }

    return receipt.status == QueueOrderStatus.paymentToVerify
        ? _TrackingStepState.active
        : _TrackingStepState.pending;
  }

  _TrackingStepState get _processingState {
    if (receipt.status == QueueOrderStatus.failed) {
      return _TrackingStepState.error;
    }

    if (_processingFinished) {
      return _TrackingStepState.done;
    }

    if (_processingStarted) {
      return _TrackingStepState.active;
    }

    return _TrackingStepState.pending;
  }

  _TrackingStepState get _finalState {
    if (receipt.status == QueueOrderStatus.completed ||
        receipt.status == QueueOrderStatus.refunded) {
      return _TrackingStepState.done;
    }

    if (receipt.status == QueueOrderStatus.awaitingCustomerConfirmation ||
        receipt.status == QueueOrderStatus.refundPending) {
      return _TrackingStepState.active;
    }

    if (receipt.status == QueueOrderStatus.expired &&
        receipt.hasPaymentToReviewAfterExpiration) {
      return _TrackingStepState.pending;
    }

    if (receipt.status == QueueOrderStatus.failed ||
        receipt.status == QueueOrderStatus.expired ||
        receipt.status == QueueOrderStatus.cancelled) {
      return _TrackingStepState.error;
    }

    return _TrackingStepState.pending;
  }

  String get _finalTitle {
    switch (receipt.status) {
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return 'Transaction effectuée';
      case QueueOrderStatus.completed:
        return 'Commande terminée';
      case QueueOrderStatus.failed:
        return 'Traitement non abouti';
      case QueueOrderStatus.expired:
        return receipt.hasPaymentToReviewAfterExpiration
            ? 'Décision de l’opérateur'
            : 'Commande expirée';
      case QueueOrderStatus.cancelled:
        return 'Commande annulée';
      case QueueOrderStatus.refundPending:
        return 'Remboursement en cours';
      case QueueOrderStatus.refunded:
        return 'Remboursement effectué';
      case QueueOrderStatus.awaitingPayment:
      case QueueOrderStatus.paymentToVerify:
      case QueueOrderStatus.paidReady:
      case QueueOrderStatus.inProgress:
      case QueueOrderStatus.onHold:
        return 'Traitement terminé';
    }
  }

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
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: CustomerAppColors.error,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 22),
          _TrackingStep(
            title: 'Paiement déclaré',
            subtitle: _formatDate(receipt.paymentDeclaredAt),
            state: receipt.isPaymentDeclared
                ? _TrackingStepState.done
                : _TrackingStepState.pending,
          ),
          _TrackingStep(
            title: 'Vérification du paiement',
            subtitle: _paymentConfirmed
                ? _formatDate(receipt.paymentConfirmedAt)
                : 'L’opérateur vérifie la transaction dans Wave.',
            state: _verificationState,
          ),
          _TrackingStep(
            title: 'Traitement de la commande',
            subtitle: receipt.status == QueueOrderStatus.onHold
                ? 'Le traitement est temporairement en attente.'
                : _formatDate(receipt.processingStartedAt),
            state: _processingState,
          ),
          _TrackingStep(
            title: _finalTitle,
            subtitle:
                receipt.failureMessage ?? _formatDate(receipt.completedAt),
            state: _finalState,
            isLast: true,
          ),
        ],
      ),
    );
  }

  String? _formatDate(DateTime? date) {
    if (date == null) {
      return null;
    }

    final String hours = date.hour.toString().padLeft(2, '0');
    final String minutes = date.minute.toString().padLeft(2, '0');
    return 'Aujourd’hui, $hours:$minutes';
  }
}

enum _TrackingStepState { done, active, pending, error }

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
    final bool hasError = state == _TrackingStepState.error;
    final Color color = hasError
        ? CustomerAppColors.error
        : done || active
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
                      : hasError
                      ? const Icon(
                          Icons.close_rounded,
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
                      color: CustomerAppColors.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: hasError
                          ? CustomerAppColors.error
                          : active
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
                        color: CustomerAppColors.onSurfaceVariant,
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
  const _NewOrderAction({
    required this.onNewOrder,
    required this.onOpenHistory,
  });

  final VoidCallback onNewOrder;
  final VoidCallback onOpenHistory;

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
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpenHistory,
                icon: const Icon(Icons.history_rounded),
                label: const Text('Historique'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onNewOrder,
                child: const Text('Nouvelle commande'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
