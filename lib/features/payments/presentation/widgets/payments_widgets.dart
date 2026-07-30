import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

class PaymentsHeader extends StatelessWidget {
  const PaymentsHeader({
    super.key,
    required this.userName,
    required this.onNotificationsPressed,
  });

  final String userName;
  final VoidCallback onNotificationsPressed;

  String get initial {
    final String trimmedName = userName.trim();

    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: AppColors.surfaceContainerHighest,
          foregroundColor: AppColors.primary,
          child: Text(
            initial,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'CabineFlow',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: onNotificationsPressed,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainerHigh,
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class PaymentFilterPill extends StatelessWidget {
  const PaymentFilterPill({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineVariant,
            ),
          ),
          child: Text(
            count > 0 ? '$label ($count)' : label,
            style: TextStyle(
              color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentTrackingCard extends StatelessWidget {
  const PaymentTrackingCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onSendPaymentLink,
    required this.onConfirmPayment,
    required this.onOpenOrders,
  });

  final QueueOrder order;
  final bool isProcessing;

  final VoidCallback onSendPaymentLink;
  final VoidCallback onConfirmPayment;
  final VoidCallback onOpenOrders;

  static const Color _successColor = Color(0xFF22C55E);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _waitingColor = Color(0xFF60A5FA);

  bool get isConfirmed {
    return order.status == QueueOrderStatus.paidReady &&
        order.paidAt != null &&
        order.paymentReference != null;
  }

  bool get wasPaymentLinkSent {
    return order.paymentRequestSentAt != null;
  }

  String get networkLabel {
    switch (order.network) {
      case MobileNetwork.orange:
        return 'Orange';

      case MobileNetwork.mtn:
        return 'MTN';

      case MobileNetwork.moov:
        return 'Moov';
    }
  }

  Color get networkColor {
    switch (order.network) {
      case MobileNetwork.orange:
        return const Color(0xFFFF7900);

      case MobileNetwork.mtn:
        return const Color(0xFFFFCC00);

      case MobileNetwork.moov:
        return const Color(0xFF0066CC);
    }
  }

  Color get networkTextColor {
    if (order.network == MobileNetwork.mtn) {
      return Colors.black;
    }

    return Colors.white;
  }

  String _formatDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime dateOnly = DateTime(date.year, date.month, date.day);

    final String time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    if (dateOnly == today) {
      return 'Aujourd’hui à $time';
    }

    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Hier à $time';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} à $time';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withAlpha(90),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMainInformation(),
          const SizedBox(height: 13),
          Divider(height: 1, color: AppColors.outlineVariant.withAlpha(70)),
          const SizedBox(height: 13),
          _buildOperationInformation(),
          const SizedBox(height: 14),
          _buildPaymentStatus(),
          const SizedBox(height: 13),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildMainInformation() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.account_circle_outlined,
          color: AppColors.primary,
          size: 21,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.clientName,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '#${order.reference}',
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${formatCfa(order.amount)} F CFA',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationInformation() {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: networkColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            networkLabel.substring(0, 1),
            style: TextStyle(
              color: networkTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$networkLabel • ${order.beneficiaryPhone}',
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                order.offerLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatus() {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;

    if (isConfirmed) {
      color = _successColor;
      icon = Icons.check_circle_rounded;
      title = 'Paiement confirmé';
      subtitle = 'Réf. ${order.paymentReference} • ${_formatDate(order.paidAt!)}';
    } else if (wasPaymentLinkSent) {
      color = _waitingColor;
      icon = Icons.hourglass_top_rounded;
      title = 'En attente de paiement';
      subtitle = 'Lien envoyé ${_formatDate(order.paymentRequestSentAt!)}';
    } else {
      color = _warningColor;
      icon = Icons.link_off_rounded;
      title = 'Lien de paiement non envoyé';
      subtitle = 'Commande créée ${_formatDate(order.createdAt)}';
    }

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(85)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (isConfirmed) {
      return OutlinedButton.icon(
        onPressed: onOpenOrders,
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text('Voir dans les commandes'),
      );
    }

    if (!wasPaymentLinkSent) {
      return FilledButton.icon(
        onPressed: isProcessing ? null : onSendPaymentLink,
        icon: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.onPrimary,
                ),
              )
            : const Icon(
                Icons.link_rounded,
                size: 19,
              ),
        label: const Text('Préparer le lien Wave'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: isProcessing ? null : onConfirmPayment,
          icon: isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onPrimary,
                  ),
                )
              : const Icon(
                  Icons.verified_rounded,
                  size: 19,
                ),
          label: const Text('Confirmer le paiement'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isProcessing ? null : onSendPaymentLink,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Renvoyer le lien'),
        ),
      ],
    );
  }
}