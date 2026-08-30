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
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Commandes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: IzyTelTypeScale.title2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w500,
                    color: IzyTelColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSearchPressed != null)
          IconButton(
            tooltip: 'Rechercher',
            onPressed: onSearchPressed,
            visualDensity: VisualDensity.compact,
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
    return Row(
      children: [
        Expanded(
          child: _TabChip(
            label: 'À traiter',
            count: todoCount,
            selected: activeTabIndex == 0,
            onTap: () => onTabChanged(0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabChip(
            label: 'En cours',
            count: inProgressCount,
            selected: activeTabIndex == 1,
            onTap: () => onTabChanged(1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TabChip(
            label: 'Terminées',
            count: completedCount,
            showCount: false,
            selected: activeTabIndex == 2,
            onTap: () => onTabChanged(2),
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showCount) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withAlpha(38)
                        : IzyTelColors.surface,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected
                          ? Colors.white
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
        return const Color(0xFFC39400);
      case 'moov':
        return IzyTelColors.moov;
      default:
        return IzyTelColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? IzyTelColors.primary : IzyTelColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? IzyTelColors.primary : IzyTelColors.outline,
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != 'Tous') ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isSelected ? Colors.white : IzyTelColors.textSecondary,
                  fontSize: IzyTelTypeScale.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
    if (order.isAssignedToAgent) return 'Affectée';
    if (order.paymentStatus == OrderPaymentStatus.confirmed) {
      return 'Paiement confirmé';
    }
    return orderStatusLabel(order.status);
  }

  Color get _stateColor {
    if (order.manualAssignmentRequired || order.isAssignedToAgent) {
      return IzyTelColors.warning;
    }
    if (order.paymentStatus == OrderPaymentStatus.confirmed) {
      return IzyTelColors.success;
    }
    return orderStatusColor(order.status);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = networkColor(order.network);
    final bool enabled = isActionEnabled && !isProcessing;

    // La maquette utilise des cartes denses de taille stable. Il ne faut pas
    // agrandir toute la carte en fonction de la largeur de l'écran : c'était
    // la cause principale de l'écart observé sur le téléphone.
    return SizedBox(
      height: 114,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTakeCharge : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: IzyTelColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: IzyTelColors.outline),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: accent.withAlpha(14),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Image.asset(
                              networkAsset(order.network),
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              networkLabel(order.network),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: IzyTelColors.textPrimary,
                                    fontSize: IzyTelTypeScale.label,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            waitingMinutes <= 0
                                ? 'À l’instant'
                                : 'Il y a $waitingMinutes min',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: IzyTelColors.error,
                                  fontSize: IzyTelTypeScale.micro,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order.offerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: IzyTelColors.textPrimary,
                              fontSize: IzyTelTypeScale.cardTitle,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              order.beneficiaryPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: IzyTelColors.textPrimary,
                                    fontSize: IzyTelTypeScale.transactionNumber,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .05,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatCfa(order.amount),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: IzyTelColors.primaryStrong,
                                  fontSize: IzyTelTypeScale.money,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.2,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IzyTelStatusPill(
                            label: _stateLabel,
                            color: _stateColor,
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              order.reference,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: IzyTelColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          if (isProcessing)
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.7,
                              ),
                            )
                          else
                            const Icon(
                              Symbols.chevron_right_rounded,
                              size: 17,
                              color: IzyTelColors.textMuted,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
