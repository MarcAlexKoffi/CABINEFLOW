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
    required this.onConfirmPayment,
    required this.onOpenOrders,
  });

  final QueueOrder order;
  final bool isProcessing;

  final VoidCallback onConfirmPayment;
  final VoidCallback onOpenOrders;

  static const Color _successColor = Color(0xFF22C55E);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _waitingColor = Color(0xFF60A5FA);

  bool get isConfirmed {
    return order.paymentStatus == OrderPaymentStatus.confirmed &&
        order.paidAt != null &&
        order.paymentReference != null &&
        order.paymentReference!.trim().isNotEmpty;
  }

  bool get isCustomerPaymentDeclared {
    return order.source == OrderSource.customerWeb &&
        order.paymentStatus == OrderPaymentStatus.declared;
  }

  bool get isPaymentToReviewAfterExpiration {
    return order.hasPaymentToReviewAfterExpiration;
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
        border: Border.all(color: AppColors.outlineVariant.withAlpha(90)),
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
          if (isCustomerPaymentDeclared && _hasDeclaredPaymentDetails) ...[
            const SizedBox(height: 10),
            _buildDeclaredPaymentDetails(),
          ],
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
          '${formatCfa(order.amount)} CFA',
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
      subtitle =
          'Réf. ${order.paymentReference} • ${_formatDate(order.paidAt!)}';
    } else if (isPaymentToReviewAfterExpiration) {
      color = const Color(0xFFDC2626);
      icon = Icons.timer_off_outlined;
      title = 'Paiement déclaré après expiration';
      subtitle = order.paymentDeclaredAt == null
          ? 'Examen manuel obligatoire.'
          : 'Déclaré ${_formatDate(order.paymentDeclaredAt!)}';
    } else if (isCustomerPaymentDeclared) {
      color = _warningColor;
      icon = Icons.manage_search_rounded;
      title = 'Paiement déclaré — à vérifier';
      subtitle = order.paymentDeclaredAt == null
          ? 'Déclaration reçue depuis l’espace client.'
          : 'Déclaré ${_formatDate(order.paymentDeclaredAt!)}';
    } else {
      color = _waitingColor;
      icon = Icons.hourglass_top_rounded;
      title = 'Paiement en attente';
      subtitle = 'Aucune déclaration de paiement à vérifier.';
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

  bool get _hasDeclaredPaymentDetails {
    return order.paymentPayerName != null ||
        order.paymentPayerPhone != null ||
        order.paymentApproximateTime != null ||
        order.paymentDeclaredReference != null;
  }

  Widget _buildDeclaredPaymentDetails() {
    final List<Widget> rows = <Widget>[
      if (order.paymentPayerName != null)
        _DeclaredPaymentRow(label: 'Nom Wave', value: order.paymentPayerName!),
      if (order.paymentPayerPhone != null)
        _DeclaredPaymentRow(
          label: 'Numéro payeur',
          value: _formatIvorianPhone(order.paymentPayerPhone!),
        ),
      if (order.paymentApproximateTime != null)
        _DeclaredPaymentRow(
          label: 'Heure annoncée',
          value: order.paymentApproximateTime!,
        ),
      if (order.paymentDeclaredReference != null)
        _DeclaredPaymentRow(
          label: 'Référence déclarée',
          value: order.paymentDeclaredReference!,
          isLast: true,
        ),
    ];

    if (rows.isNotEmpty && rows.last is _DeclaredPaymentRow) {
      final _DeclaredPaymentRow last = rows.removeLast() as _DeclaredPaymentRow;
      rows.add(
        _DeclaredPaymentRow(label: last.label, value: last.value, isLast: true),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 17,
              ),
              SizedBox(width: 7),
              Text(
                'Informations déclarées par le client',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ...rows,
        ],
      ),
    );
  }

  String _formatIvorianPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final String localDigits = digits.startsWith('225')
        ? digits.substring(3)
        : digits;

    if (localDigits.length != 10) {
      return value;
    }

    final List<String> groups = <String>[
      localDigits.substring(0, 2),
      localDigits.substring(2, 4),
      localDigits.substring(4, 6),
      localDigits.substring(6, 8),
      localDigits.substring(8, 10),
    ];

    return '+225 ${groups.join(' ')}';
  }

  Widget _buildActions() {
    if (isConfirmed) {
      return OutlinedButton.icon(
        onPressed: onOpenOrders,
        icon: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text('Voir dans les commandes'),
      );
    }

    if (isCustomerPaymentDeclared) {
      return FilledButton.icon(
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
            : const Icon(Icons.verified_rounded, size: 19),
        label: Text(
          isPaymentToReviewAfterExpiration
              ? 'Examiner et confirmer'
              : 'Vérifier et confirmer',
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onOpenOrders,
      icon: const Icon(Icons.receipt_long_outlined, size: 18),
      label: const Text('Voir la commande'),
    );
  }
}

class _DeclaredPaymentRow extends StatelessWidget {
  const _DeclaredPaymentRow({
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.outlineVariant.withAlpha(45),
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
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
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
