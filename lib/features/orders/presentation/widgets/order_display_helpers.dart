import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/orders/domain/models/order_history_filters.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

String orderStatusLabel(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.awaitingPayment:
      return 'En attente paiement';
    case QueueOrderStatus.paymentToVerify:
      return 'Paiement à vérifier';
    case QueueOrderStatus.paidReady:
      return 'Prête à traiter';
    case QueueOrderStatus.inProgress:
      return 'En cours';
    case QueueOrderStatus.onHold:
      return 'En attente';
    case QueueOrderStatus.awaitingCustomerConfirmation:
      return 'Transaction effectuée';
    case QueueOrderStatus.completed:
      return 'Terminée';
    case QueueOrderStatus.failed:
      return 'Échouée';
    case QueueOrderStatus.expired:
      return 'Expirée';
    case QueueOrderStatus.cancelled:
      return 'Annulée';
    case QueueOrderStatus.refundPending:
      return 'Remboursement en cours';
    case QueueOrderStatus.refunded:
      return 'Remboursée';
  }
}

Color orderStatusColor(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.completed:
    case QueueOrderStatus.refunded:
      return AppColors.success;
    case QueueOrderStatus.failed:
    case QueueOrderStatus.cancelled:
      return AppColors.error;
    case QueueOrderStatus.expired:
    case QueueOrderStatus.refundPending:
      return AppColors.warning;
    case QueueOrderStatus.paidReady:
    case QueueOrderStatus.inProgress:
    case QueueOrderStatus.awaitingCustomerConfirmation:
      return AppColors.primary;
    case QueueOrderStatus.awaitingPayment:
    case QueueOrderStatus.paymentToVerify:
    case QueueOrderStatus.onHold:
      return const Color(0xFFFFB020);
  }
}

IconData orderStatusIcon(QueueOrderStatus status) {
  switch (status) {
    case QueueOrderStatus.completed:
    case QueueOrderStatus.refunded:
      return Icons.check_circle_outline_rounded;
    case QueueOrderStatus.failed:
    case QueueOrderStatus.cancelled:
      return Icons.cancel_outlined;
    case QueueOrderStatus.expired:
      return Icons.timer_off_outlined;
    case QueueOrderStatus.refundPending:
      return Icons.replay_circle_filled_outlined;
    case QueueOrderStatus.paidReady:
      return Icons.inventory_2_outlined;
    case QueueOrderStatus.inProgress:
      return Icons.autorenew_rounded;
    case QueueOrderStatus.awaitingCustomerConfirmation:
      return Icons.mark_chat_read_outlined;
    case QueueOrderStatus.awaitingPayment:
      return Icons.account_balance_wallet_outlined;
    case QueueOrderStatus.paymentToVerify:
      return Icons.fact_check_outlined;
    case QueueOrderStatus.onHold:
      return Icons.pause_circle_outline_rounded;
  }
}

String paymentStatusLabel(OrderPaymentStatus status) {
  switch (status) {
    case OrderPaymentStatus.notDeclared:
      return 'Non déclaré';
    case OrderPaymentStatus.pending:
      return 'En attente';
    case OrderPaymentStatus.declared:
      return 'Déclaré';
    case OrderPaymentStatus.confirmed:
      return 'Confirmé';
    case OrderPaymentStatus.rejected:
      return 'Rejeté';
    case OrderPaymentStatus.expired:
      return 'Expiré';
  }
}

String networkLabel(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'Orange';
    case MobileNetwork.mtn:
      return 'MTN';
    case MobileNetwork.moov:
      return 'Moov Africa';
  }
}

Color networkColor(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return AppColors.orange;
    case MobileNetwork.mtn:
      return AppColors.mtn;
    case MobileNetwork.moov:
      return AppColors.moov;
  }
}

String networkAsset(MobileNetwork network) {
  switch (network) {
    case MobileNetwork.orange:
      return 'assets/images/orange_logo.png';
    case MobileNetwork.mtn:
      return 'assets/images/mtn_logo.png';
    case MobileNetwork.moov:
      return 'assets/images/moov_logo.png';
  }
}

String operationTypeLabel(OrderOperationType type) {
  switch (type) {
    case OrderOperationType.internetSubscription:
      return 'Souscription Internet';
    case OrderOperationType.unitTransfer:
      return 'Transfert d’unités';
    case OrderOperationType.callBundle:
      return 'Forfait d’appels';
    case OrderOperationType.mixedBundle:
      return 'Forfait mixte';
    case OrderOperationType.other:
      return 'Autre service';
  }
}

String orderSourceLabel(OrderSource source) {
  switch (source) {
    case OrderSource.customerWeb:
      return 'Espace client Web';
    case OrderSource.operatorApp:
      return 'Application opérateur';
  }
}

String confirmationStatusLabel(CustomerConfirmationStatus? status) {
  switch (status) {
    case CustomerConfirmationStatus.pending:
      return 'En attente d’envoi';
    case CustomerConfirmationStatus.sent:
      return 'Message marqué envoyé';
    case CustomerConfirmationStatus.skipped:
      return 'Clôturée sans message';
    case null:
      return 'Non renseigné';
  }
}

String failureReasonLabel(OrderFailureReason? reason) {
  switch (reason) {
    case OrderFailureReason.incorrectNumber:
      return 'Numéro incorrect';
    case OrderFailureReason.networkUnavailable:
      return 'Réseau indisponible';
    case OrderFailureReason.offerUnavailable:
      return 'Offre indisponible';
    case OrderFailureReason.insufficientBalance:
      return 'Solde insuffisant';
    case OrderFailureReason.technicalError:
      return 'Erreur technique';
    case OrderFailureReason.incorrectPayment:
      return 'Paiement incorrect';
    case OrderFailureReason.other:
      return 'Autre motif';
    case null:
      return 'Non renseigné';
  }
}

String historyPeriodLabel(OrderHistoryPeriod period) {
  switch (period) {
    case OrderHistoryPeriod.today:
      return 'Aujourd’hui';
    case OrderHistoryPeriod.yesterday:
      return 'Hier';
    case OrderHistoryPeriod.last7Days:
      return '7 derniers jours';
    case OrderHistoryPeriod.last30Days:
      return '30 derniers jours';
    case OrderHistoryPeriod.all:
      return 'Toutes les périodes';
  }
}

String historyStateLabel(OrderHistoryStateFilter state) {
  switch (state) {
    case OrderHistoryStateFilter.active:
      return 'En cours';
    case OrderHistoryStateFilter.completed:
      return 'Terminées';
    case OrderHistoryStateFilter.failed:
      return 'Échouées';
    case OrderHistoryStateFilter.expired:
      return 'Expirées';
  }
}

String formatOrderDateTime(DateTime value) {
  final DateTime date = value.toLocal();
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

  final String day = date.day.toString().padLeft(2, '0');
  final String hour = date.hour.toString().padLeft(2, '0');
  final String minute = date.minute.toString().padLeft(2, '0');

  return '$day ${months[date.month - 1]} ${date.year} • $hour:$minute';
}

String formatOrderTime(DateTime? value) {
  if (value == null) {
    return 'Non renseignée';
  }

  final DateTime date = value.toLocal();
  final String hour = date.hour.toString().padLeft(2, '0');
  final String minute = date.minute.toString().padLeft(2, '0');
  final String second = date.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String formatIvorianPhone(String value) {
  final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  final String localDigits = digits.startsWith('225')
      ? digits.substring(3)
      : digits;

  if (localDigits.length != 10) {
    return value;
  }

  return '+225 ${<String>[localDigits.substring(0, 2), localDigits.substring(2, 4), localDigits.substring(4, 6), localDigits.substring(6, 8), localDigits.substring(8, 10)].join(' ')}';
}

String compactOperatorLabel(String? operatorId) {
  final String cleaned = operatorId?.trim() ?? '';
  if (cleaned.isEmpty) {
    return 'Non attribué';
  }

  if (cleaned.length <= 8) {
    return cleaned;
  }

  return '${cleaned.substring(0, 4)}…${cleaned.substring(cleaned.length - 3)}';
}

bool orderMatchesState(QueueOrder order, OrderHistoryStateFilter state) {
  switch (state) {
    case OrderHistoryStateFilter.active:
      return <QueueOrderStatus>{
        QueueOrderStatus.awaitingPayment,
        QueueOrderStatus.paymentToVerify,
        QueueOrderStatus.paidReady,
        QueueOrderStatus.inProgress,
        QueueOrderStatus.onHold,
        QueueOrderStatus.awaitingCustomerConfirmation,
        QueueOrderStatus.refundPending,
      }.contains(order.status);
    case OrderHistoryStateFilter.completed:
      return <QueueOrderStatus>{
        QueueOrderStatus.completed,
        QueueOrderStatus.refunded,
      }.contains(order.status);
    case OrderHistoryStateFilter.failed:
      return <QueueOrderStatus>{
        QueueOrderStatus.failed,
        QueueOrderStatus.cancelled,
      }.contains(order.status);
    case OrderHistoryStateFilter.expired:
      return order.status == QueueOrderStatus.expired;
  }
}
