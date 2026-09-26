import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_receipt.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/features/support/presentation/widgets/customer_support_request_button.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_copy_button.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:flutter/material.dart';

class CustomerConfirmationPage extends StatelessWidget {
  const CustomerConfirmationPage({
    super.key,
    required this.viewModel,
    required this.onOpenHome,
    required this.onOpenOffers,
    required this.onOpenHistory,
    required this.onOpenHelp,
    required this.supportRequestRepository,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenHelp;
  final SupportRequestRepository supportRequestRepository;

  @override
  Widget build(BuildContext context) {
    final CustomerOrderReceipt receipt = viewModel.receipt!;

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
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
                          const Text(
                            'Suivi de commande',
                            style: TextStyle(
                              color: CustomerAppColors.onSurface,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Consultez l’état réel de votre commande en temps réel.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _TransactionDetailsCard(receipt: receipt),
                          const SizedBox(height: 20),
                          _TrackingCard(
                            receipt: receipt,
                            errorMessage: viewModel.trackingErrorMessage,
                          ),
                          const SizedBox(height: 20),
                          _StatusHeader(receipt: receipt),
                          const SizedBox(height: 20),
                          _SupportCard(
                            receipt: receipt,
                            onOpenHelp: onOpenHelp,
                            supportRequestRepository: supportRequestRepository,
                          ),
                          const SizedBox(height: 20),
                          _ReferenceCard(receipt: receipt),
                        ],
                      ),
                    ),
                  ),
                  _ConfirmationFooter(
                    onNewOrder: viewModel.restart,
                    onOpenHome: onOpenHome,
                    onOpenOffers: onOpenOffers,
                    onOpenHistory: onOpenHistory,
                    onOpenHelp: onOpenHelp,
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
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: CustomerAppColors.outlineSoft),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox.square(
              dimension: 30,
              child: Image.asset(
                'assets/images/izyTel_logo.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'IzyTel',
              style: TextStyle(
                color: CustomerAppColors.primaryDeep,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
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
        return CustomerAppColors.primary;
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
      case QueueOrderStatus.awaitingPayment:
        return Icons.account_balance_wallet_outlined;
      case QueueOrderStatus.paymentToVerify:
        return Icons.shield_outlined;
      case QueueOrderStatus.paidReady:
        return Icons.verified_rounded;
      case QueueOrderStatus.inProgress:
        return Icons.sync_rounded;
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return Icons.task_alt_rounded;
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
        return 'Votre commande est actuellement en cours de traitement par IzyTel.';
      case QueueOrderStatus.onHold:
        return 'Le traitement est temporairement suspendu. Vous serez informé de la suite.';
      case QueueOrderStatus.awaitingCustomerConfirmation:
        return 'La transaction a été effectuée. La confirmation finale est en préparation.';
      case QueueOrderStatus.completed:
        return 'Votre commande a été entièrement traitée.';
      case QueueOrderStatus.failed:
        return receipt.failureMessage ??
            'La transaction n’a pas pu être réalisée. IzyTel examinera la situation.';
      case QueueOrderStatus.expired:
        return receipt.hasPaymentToReviewAfterExpiration
            ? 'Votre paiement a été déclaré après l’expiration. IzyTel doit maintenant l’examiner.'
            : 'Le délai de paiement de six heures est dépassé. Aucun paiement confirmé n’a été retrouvé.';
      case QueueOrderStatus.cancelled:
        return 'Cette commande a été annulée.';
      case QueueOrderStatus.refundPending:
        return 'Le remboursement est en cours de traitement.';
      case QueueOrderStatus.refunded:
        return 'Le remboursement lié à cette commande a été effectué.';
    }
  }

  DateTime get _latestAt =>
      receipt.completedAt ??
      receipt.processingStartedAt ??
      receipt.paymentConfirmedAt ??
      receipt.paymentDeclaredAt ??
      receipt.createdAt;

  String get _latestAtLabel {
    final DateTime local = _latestAt.toLocal();
    const List<String> months = <String>[
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ];
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(_icon, color: color, size: 30),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Dernière mise à jour · $_title',
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _message,
                  style: const TextStyle(
                    color: CustomerAppColors.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _latestAtLabel,
                  style: const TextStyle(
                    color: CustomerAppColors.onSurfaceVariant,
                    fontSize: 11,
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

class _ReferenceCard extends StatelessWidget {
  const _ReferenceCard({required this.receipt});

  final CustomerOrderReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final String? recoveryCode = receipt.recoveryCode?.trim();

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'RÉFÉRENCE DE COMMANDE',
            style: TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: SelectableText(
                  receipt.reference,
                  style: const TextStyle(
                    color: CustomerAppColors.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IzyTelCopyButton(
                value: receipt.reference,
                tooltip: 'Copier la référence',
                successMessage: 'Référence copiée',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: CustomerAppColors.surfaceContainerHigh),
          const SizedBox(height: 14),
          if (recoveryCode != null && recoveryCode.isNotEmpty) ...<Widget>[
            const Text(
              'CODE DE RÉCUPÉRATION',
              style: TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText(
                    recoveryCode,
                    style: const TextStyle(
                      color: CustomerAppColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                IzyTelCopyButton(
                  value: recoveryCode,
                  tooltip: 'Copier le code de récupération',
                  successMessage: 'Code de récupération copié',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Conservez la référence et ce code. Ils permettent de retrouver cette commande depuis un autre appareil.',
              style: TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ] else ...<Widget>[
            const Text(
              'Commande historique',
              style: TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cette commande a été créée avant l’introduction du code de récupération. Elle reste disponible sur les appareils où elle est déjà mémorisée.',
              style: TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
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
          Row(
            children: [
              IzyTelOperatorLogo(
                network: draft.network!,
                size: 42,
                borderRadius: 11,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Détails de la transaction',
                      style: TextStyle(
                        color: CustomerAppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.network!.brandLabel,
                      style: TextStyle(
                        color: draft.network!.brandColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.receipt,
    required this.onOpenHelp,
    required this.supportRequestRepository,
  });

  final CustomerOrderReceipt receipt;
  final VoidCallback onOpenHelp;
  final SupportRequestRepository supportRequestRepository;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.support_agent_rounded,
                color: CustomerAppColors.primary,
                size: 24,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Besoin d’aide ?',
                  style: TextStyle(
                    color: CustomerAppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Si vous rencontrez un problème ou si le service n’est pas encore disponible, IzyTel peut examiner la situation.',
            style: TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpenHelp,
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Contacter IzyTel'),
          ),
          const SizedBox(height: 10),
          CustomerSupportRequestButton(
            orderId: receipt.id,
            orderReference: receipt.reference,
            repository: supportRequestRepository,
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

  bool get _creditAuthorized =>
      receipt.paymentStatus == OrderPaymentStatus.credit;

  bool get _fundingValidated => _paymentConfirmed || _creditAuthorized;

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
    if (_fundingValidated) {
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
            ? 'Analyse IzyTel'
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
            'Suivi de la commande',
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
            title: 'Commande créée',
            subtitle: _formatDate(receipt.createdAt),
            state: _TrackingStepState.done,
          ),
          _TrackingStep(
            title: _creditAuthorized ? 'Crédit validé' : 'Paiement confirmé',
            subtitle: _creditAuthorized
                ? 'Le traitement est autorisé par IzyTel.'
                : (_paymentConfirmed
                      ? _formatDate(receipt.paymentConfirmedAt)
                      : 'En attente de confirmation du paiement.'),
            state: _verificationState,
          ),
          _TrackingStep(
            title: 'En traitement',
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

    final DateTime localDate = date.toLocal();
    final DateTime now = DateTime.now();
    final String hours = localDate.hour.toString().padLeft(2, '0');
    final String minutes = localDate.minute.toString().padLeft(2, '0');
    final bool isToday =
        localDate.year == now.year &&
        localDate.month == now.month &&
        localDate.day == now.day;

    if (isToday) {
      return 'Aujourd’hui, $hours:$minutes';
    }

    final String day = localDate.day.toString().padLeft(2, '0');
    final String month = localDate.month.toString().padLeft(2, '0');
    return '$day/$month/${localDate.year}, $hours:$minutes';
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
        : done
        ? CustomerAppColors.success
        : active
        ? CustomerAppColors.primary
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
                      color: done
                          ? CustomerAppColors.success
                          : CustomerAppColors.surfaceContainerHighest,
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
                          ? CustomerAppColors.primary
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
    return IzyTelCard(padding: const EdgeInsets.all(20), child: child);
  }
}

class _ConfirmationFooter extends StatelessWidget {
  const _ConfirmationFooter({
    required this.onNewOrder,
    required this.onOpenHome,
    required this.onOpenOffers,
    required this.onOpenHistory,
    required this.onOpenHelp,
  });

  final VoidCallback onNewOrder;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: CustomerAppColors.surfaceContainerLowest,
            border: Border(
              top: BorderSide(color: CustomerAppColors.outlineSoft),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: FilledButton.icon(
                onPressed: onNewOrder,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Commander à nouveau'),
              ),
            ),
          ),
        ),
        IzyTelBottomNavigation(
          current: IzyTelCustomerDestination.history,
          onHome: onOpenHome,
          onOffers: onOpenOffers,
          onHistory: onOpenHistory,
          onHelp: onOpenHelp,
        ),
      ],
    );
  }
}
