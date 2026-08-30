import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PaymentsTopBar extends StatelessWidget {
  const PaymentsTopBar({
    super.key,
    required this.onRefreshPressed,
  });

  final VoidCallback onRefreshPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Paiements',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.title2,
              height: 1.08,
              fontWeight: FontWeight.w700,
              letterSpacing: -.35,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Actualiser',
          onPressed: onRefreshPressed,
          visualDensity: VisualDensity.compact,
          color: IzyTelColors.textPrimary,
          icon: const Icon(
            Symbols.refresh_rounded,
            size: IzyTelIconSize.action,
          ),
        ),
      ],
    );
  }
}

class PaymentAttentionSummary extends StatelessWidget {
  const PaymentAttentionSummary({
    super.key,
    required this.count,
    required this.amount,
  });

  final int count;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final bool hasPending = count > 0;
    final Color accent = hasPending ? IzyTelColors.warning : IzyTelColors.success;
    final Color soft = hasPending
        ? IzyTelColors.warningSoft
        : IzyTelColors.successSoft;

    return IzyTelSurface(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      backgroundColor: IzyTelColors.surface,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              hasPending
                  ? Symbols.fact_check_rounded
                  : Symbols.check_circle_rounded,
              color: accent,
              size: IzyTelIconSize.action,
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPending
                      ? '$count paiement${count > 1 ? 's' : ''} à vérifier'
                      : 'Aucun paiement à vérifier',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.cardTitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPending
                      ? '${formatCfaFull(amount)} à contrôler'
                      : 'La file de vérification est à jour.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w500,
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

class PaymentFilterPill extends StatelessWidget {
  const PaymentFilterPill({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onPressed,
    this.emphasis,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onPressed;
  final Color? emphasis;

  @override
  Widget build(BuildContext context) {
    final Color accent = emphasis ?? IzyTelColors.primary;
    final Color foreground = isSelected
        ? IzyTelColors.surface
        : emphasis ?? IzyTelColors.textPrimary;
    final Color background = isSelected
        ? accent
        : emphasis == null
            ? IzyTelColors.surfaceMuted
            : accent.withAlpha(20);

    return Material(
      color: background,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected
              ? accent
              : emphasis == null
                  ? IzyTelColors.outline
                  : accent.withAlpha(50),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? IzyTelColors.surface.withAlpha(34)
                        : IzyTelColors.surface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? IzyTelColors.surface : accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
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

  String get _networkName => networkLabel(order.network);

  Color get _statusColor {
    if (isConfirmed) return IzyTelColors.success;
    if (isPaymentToReviewAfterExpiration) return IzyTelColors.error;
    if (isCustomerPaymentDeclared) return IzyTelColors.warning;
    return IzyTelColors.primary;
  }

  String get _statusLabel {
    if (isConfirmed) return 'Paiement confirmé';
    if (isPaymentToReviewAfterExpiration) return 'Après expiration';
    if (isCustomerPaymentDeclared) return 'À vérifier';
    return 'En attente';
  }

  IconData get _statusIcon {
    if (isConfirmed) return Symbols.check_circle_rounded;
    if (isPaymentToReviewAfterExpiration) return Symbols.timer_off_rounded;
    if (isCustomerPaymentDeclared) return Symbols.fact_check_rounded;
    return Symbols.schedule_rounded;
  }

  DateTime get _referenceDate {
    return order.paymentDeclaredAt ??
        order.paidAt ??
        order.paymentRequestSentAt ??
        order.createdAt;
  }

  String get _relativeTime {
    final Duration difference = DateTime.now().difference(_referenceDate);
    if (difference.isNegative || difference.inMinutes <= 0) return 'À l’instant';
    if (difference.inMinutes < 60) return 'Il y a ${difference.inMinutes} min';
    if (difference.inHours < 24) {
      final int minutes = difference.inMinutes.remainder(60);
      return minutes == 0
          ? 'Il y a ${difference.inHours} h'
          : 'Il y a ${difference.inHours} h $minutes min';
    }
    return 'Il y a ${difference.inDays} j';
  }

  String _formatIvorianPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final String localDigits = digits.startsWith('225')
        ? digits.substring(3)
        : digits;
    if (localDigits.length != 10) return value;
    return '+225 ${<String>[
      localDigits.substring(0, 2),
      localDigits.substring(2, 4),
      localDigits.substring(4, 6),
      localDigits.substring(6, 8),
      localDigits.substring(8, 10),
    ].join(' ')}';
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor;

    return IzyTelSurface(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _NetworkLogo(network: order.network),
              const SizedBox(width: 9),
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  _networkName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _relativeTime,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isPaymentToReviewAfterExpiration
                      ? IzyTelColors.error
                      : IzyTelColors.textMuted,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: isPaymentToReviewAfterExpiration
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            order.offerLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: IzyTelColors.textPrimary,
              fontSize: IzyTelTypeScale.cardTitle,
              height: 1.22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  _formatIvorianPhone(order.beneficiaryPhone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.transactionNumber,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .05,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatCfa(order.amount),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: IzyTelColors.primaryStrong,
                  fontSize: IzyTelTypeScale.money,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: Text(
                  'Client · ${order.clientName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.micro,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                order.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: IzyTelColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IzyTelStatusPill(
                label: _statusLabel,
                color: statusColor,
                icon: _statusIcon,
              ),
              if (isCustomerPaymentDeclared && order.paymentPayerName != null)
                Text(
                  'Payeur · ${order.paymentPayerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (isCustomerPaymentDeclared) {
      return SizedBox(
        height: 44,
        child: FilledButton.icon(
          onPressed: isProcessing ? null : onConfirmPayment,
          style: FilledButton.styleFrom(
            backgroundColor: IzyTelColors.primary,
            foregroundColor: IzyTelColors.surface,
            disabledBackgroundColor: IzyTelColors.surfaceMuted,
            disabledForegroundColor: IzyTelColors.textMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(IzyTelRadii.button),
            ),
          ),
          icon: isProcessing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: IzyTelColors.surface,
                  ),
                )
              : Icon(
                  isPaymentToReviewAfterExpiration
                      ? Symbols.search_rounded
                      : Symbols.verified_rounded,
                  size: IzyTelIconSize.info,
                ),
          label: Text(
            isPaymentToReviewAfterExpiration
                ? 'Examiner le paiement'
                : 'Vérifier le paiement',
            style: const TextStyle(
              fontSize: IzyTelTypeScale.label,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onOpenOrders,
        style: OutlinedButton.styleFrom(
          foregroundColor: IzyTelColors.primary,
          side: const BorderSide(color: IzyTelColors.outlineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IzyTelRadii.button),
          ),
        ),
        icon: const Icon(
          Symbols.receipt_long_rounded,
          size: IzyTelIconSize.info,
        ),
        label: Text(
          isConfirmed ? 'Voir la commande' : 'Ouvrir la commande',
          style: const TextStyle(
            fontSize: IzyTelTypeScale.label,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network});

  final MobileNetwork network;

  @override
  Widget build(BuildContext context) {
    final Color soft = switch (network) {
      MobileNetwork.orange => IzyTelColors.orangeSoft,
      MobileNetwork.mtn => IzyTelColors.mtnSoft,
      MobileNetwork.moov => IzyTelColors.moovSoft,
    };

    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Image.asset(
        networkAsset(network),
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return Icon(
            Symbols.sim_card_rounded,
            size: 18,
            color: _fallbackColor,
          );
        },
      ),
    );
  }

  Color get _fallbackColor => switch (network) {
    MobileNetwork.orange => IzyTelColors.orange,
    MobileNetwork.mtn => IzyTelColors.mtnText,
    MobileNetwork.moov => IzyTelColors.moov,
  };
}
