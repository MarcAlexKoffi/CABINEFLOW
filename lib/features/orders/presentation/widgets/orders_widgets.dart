import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/presentation/widgets/order_display_helpers.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class OrdersTopBar extends StatelessWidget {
  const OrdersTopBar({
    super.key,
    required this.user,
    required this.onNotificationsPressed,
    this.onSearchPressed,
    this.onFiltersPressed,
    this.subtitle,
  });

  final String? subtitle;
  final AppUser user;
  final VoidCallback onNotificationsPressed;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onFiltersPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            'Commandes',
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
        const SizedBox(width: 12),
        if (onSearchPressed != null)
          IconButton(
            tooltip: 'Rechercher',
            onPressed: onSearchPressed,
            visualDensity: VisualDensity.compact,
            color: IzyTelColors.textPrimary,
            icon: const Icon(
              Symbols.search_rounded,
              size: IzyTelIconSize.action,
            ),
          ),
        if (onFiltersPressed != null)
          IconButton(
            tooltip: 'Filtres',
            onPressed: onFiltersPressed,
            visualDensity: VisualDensity.compact,
            color: IzyTelColors.textPrimary,
            icon: const Icon(Symbols.tune_rounded, size: IzyTelIconSize.action),
          ),
      ],
    );
  }
}

class OrdersTabs extends StatelessWidget {
  const OrdersTabs({
    super.key,
    required this.todoCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.activeTabIndex,
    required this.onTabChanged,
  });

  final int todoCount;
  final int inProgressCount;
  final int completedCount;
  final int activeTabIndex;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TabChip(
              label: 'À traiter',
              count: todoCount,
              selected: activeTabIndex == 0,
              onTap: () => onTabChanged(0),
            ),
            const SizedBox(width: 8),
            _TabChip(
              label: 'En cours',
              count: inProgressCount,
              selected: activeTabIndex == 1,
              onTap: () => onTabChanged(1),
            ),
            const SizedBox(width: 8),
            _TabChip(
              label: 'Terminées',
              count: completedCount,
              showCount: false,
              selected: activeTabIndex == 2,
              onTap: () => onTabChanged(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.showCount = true,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? IzyTelColors.primary : IzyTelColors.surfaceMuted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? IzyTelColors.surface
                      : IzyTelColors.textPrimary,
                  fontSize: IzyTelTypeScale.micro,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showCount) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? IzyTelColors.surface.withAlpha(36)
                        : IzyTelColors.surface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? IzyTelColors.surface
                          : IzyTelColors.textSecondary,
                      fontSize: IzyTelTypeScale.micro,
                      fontWeight: FontWeight.w600,
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

class OrdersSortBar extends StatelessWidget {
  const OrdersSortBar({super.key, required this.oldestWaitMinutes});

  final int oldestWaitMinutes;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class QueueMetricCard extends StatelessWidget {
  const QueueMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final String label;
  final int value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 7),
          Text(
            '$value $unit',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class QueueFilterButton extends StatelessWidget {
  const QueueFilterButton({
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

  Color get _accent {
    switch (label.toLowerCase()) {
      case 'orange':
        return IzyTelColors.orange;
      case 'mtn':
        return IzyTelColors.mtnText;
      case 'moov':
        return IzyTelColors.moov;
      default:
        return IzyTelColors.primary;
    }
  }

  Color get _softBackground {
    switch (label.toLowerCase()) {
      case 'orange':
        return IzyTelColors.orangeSoft;
      case 'mtn':
        return IzyTelColors.mtnSoft;
      case 'moov':
        return IzyTelColors.moovSoft;
      default:
        return IzyTelColors.surfaceMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAll = label.toLowerCase() == 'tous';
    final Color background = isAll && isSelected
        ? IzyTelColors.primary
        : _softBackground;
    final Color foreground = isAll && isSelected
        ? IzyTelColors.surface
        : isAll
        ? IzyTelColors.textPrimary
        : _accent;
    final Color borderColor = isSelected && !isAll
        ? _accent.withAlpha(115)
        : Colors.transparent;

    return Material(
      color: background,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontSize: IzyTelTypeScale.micro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class QueueOrderCard extends StatelessWidget {
  const QueueOrderCard({
    super.key,
    required this.order,
    required this.position,
    required this.waitingMinutes,
    required this.isUrgent,
    required this.isProcessing,
    required this.onTakeCharge,
    this.actionLabel = 'Prendre en charge',
    this.assignmentLabel,
    this.isActionEnabled = true,
  });

  final QueueOrder order;
  final int position;
  final int waitingMinutes;
  final bool isUrgent;
  final bool isProcessing;
  final VoidCallback onTakeCharge;
  final String actionLabel;
  final String? assignmentLabel;
  final bool isActionEnabled;

  String get _stateLabel {
    if (order.manualAssignmentRequired) return 'En attente d’affectation';
    if (order.isCreditSale) return 'Crédit autorisé';
    if (order.paymentStatus == OrderPaymentStatus.confirmed) {
      return 'Paiement confirmé';
    }
    if (order.isAssignedToAgent) return 'Affectée';
    return orderStatusLabel(order.status);
  }

  Color get _stateColor {
    if (order.manualAssignmentRequired) return IzyTelColors.warning;
    if (order.isCreditSale) return IzyTelColors.warning;
    if (order.paymentStatus == OrderPaymentStatus.confirmed) {
      return IzyTelColors.success;
    }
    if (order.isAssignedToAgent) return IzyTelColors.warning;
    return switch (order.status) {
      QueueOrderStatus.completed ||
      QueueOrderStatus.refunded => IzyTelColors.success,
      QueueOrderStatus.failed ||
      QueueOrderStatus.cancelled => IzyTelColors.error,
      QueueOrderStatus.expired ||
      QueueOrderStatus.refundPending => IzyTelColors.warning,
      _ => IzyTelColors.primary,
    };
  }

  Color get _networkColor => switch (order.network) {
    MobileNetwork.orange => IzyTelColors.orange,
    MobileNetwork.mtn => IzyTelColors.mtn,
    MobileNetwork.moov => IzyTelColors.moov,
  };

  Color get _networkSoft => switch (order.network) {
    MobileNetwork.orange => IzyTelColors.orangeSoft,
    MobileNetwork.mtn => IzyTelColors.mtnSoft,
    MobileNetwork.moov => IzyTelColors.moovSoft,
  };

  String get _waitingLabel {
    if (waitingMinutes <= 0) return 'À l’instant';
    if (waitingMinutes >= 60) {
      final int hours = waitingMinutes ~/ 60;
      final int minutes = waitingMinutes.remainder(60);
      return minutes == 0 ? 'Il y a $hours h' : 'Il y a $hours h $minutes min';
    }
    return 'Il y a $waitingMinutes min';
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = isActionEnabled && !isProcessing;
    final Color networkAccent = _networkColor;
    final Color stateAccent = _stateColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTakeCharge : null,
        borderRadius: BorderRadius.circular(13),
        child: CustomPaint(
          foregroundPainter: _QueueOrderAccentPainter(
            networkColor: networkAccent,
            stateColor: stateAccent,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 11, 9),
            decoration: BoxDecoration(
              color: IzyTelColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: IzyTelColors.outline),
              boxShadow: const [
                BoxShadow(
                  color: IzyTelColors.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: _networkSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Image.asset(
                              networkAsset(order.network),
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              networkLabel(order.network),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: IzyTelColors.textPrimary,
                                    fontSize: IzyTelTypeScale.label,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _waitingLabel,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: isUrgent
                            ? IzyTelColors.error
                            : IzyTelColors.warning,
                        fontSize: IzyTelTypeScale.micro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  order.offerLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: IzyTelColors.textPrimary,
                    fontSize: IzyTelTypeScale.text,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        formatIvorianPhone(order.beneficiaryPhone),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: IzyTelColors.textPrimary,
                          fontSize: IzyTelTypeScale.text,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .04,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatCfa(order.amount),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: IzyTelColors.primaryStrong,
                        fontSize: IzyTelTypeScale.money,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 3,
                      child: IzyTelStatusPill(
                        label: _stateLabel,
                        color: stateAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          order.reference,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: IzyTelColors.textMuted,
                                fontSize: IzyTelTypeScale.micro,
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isProcessing)
                      const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.7),
                      )
                    else
                      const Icon(
                        Symbols.chevron_right_rounded,
                        size: IzyTelIconSize.info,
                        color: IzyTelColors.textSecondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QueueOrderAccentPainter extends CustomPainter {
  const _QueueOrderAccentPainter({
    required this.networkColor,
    required this.stateColor,
  });

  final Color networkColor;
  final Color stateColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double x = 1.5;
    const double top = 12;
    final double bottom = size.height - 12;
    if (bottom <= top) return;

    final double split = top + ((bottom - top) * .56);
    final Paint networkPaint = Paint()
      ..color = networkColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final Paint statePaint = Paint()
      ..color = stateColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, top), Offset(x, split - 1), networkPaint);
    canvas.drawLine(Offset(x, split + 1), Offset(x, bottom), statePaint);
  }

  @override
  bool shouldRepaint(covariant _QueueOrderAccentPainter oldDelegate) {
    return oldDelegate.networkColor != networkColor ||
        oldDelegate.stateColor != stateColor;
  }
}

class QueueEmptyState extends StatelessWidget {
  const QueueEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return IzyTelSurface(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: IzyTelColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.check_circle_rounded,
              size: IzyTelIconSize.state,
              color: IzyTelColors.success,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune commande à traiter',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Toutes les commandes payées ont été prises en charge.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
