import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

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

  String get initial {
    final String name = user.name.trim();

    if (name.isEmpty) {
      return '?';
    }

    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(40),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 1.5),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Commandes',
                style: TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle?.trim().isNotEmpty == true)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
        if (onSearchPressed != null)
          IconButton(
            tooltip: 'Historique et recherche',
            onPressed: onSearchPressed,
            color: AppColors.onBackground,
            icon: const Icon(Icons.search_rounded),
          ),
        if (onFiltersPressed != null)
          IconButton(
            tooltip: 'Historique filtré',
            onPressed: onFiltersPressed,
            color: AppColors.onBackground,
            icon: const Icon(Icons.tune_rounded),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(0),
              behavior: HitTestBehavior.opaque,
              child: _TabItem(
                label: 'À traiter',
                count: todoCount,
                isActive: activeTabIndex == 0,
                activeColor: const Color(0xFFFF7900),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(1),
              behavior: HitTestBehavior.opaque,
              child: _TabItem(
                label: 'En cours',
                count: inProgressCount,
                isActive: activeTabIndex == 1,
                activeColor: const Color(0xFF1677FF),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(2),
              behavior: HitTestBehavior.opaque,
              child: _TabItem(
                label: 'Terminées',
                count: completedCount,
                isActive: activeTabIndex == 2,
                activeColor: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.count,
    required this.isActive,
    required this.activeColor,
  });

  final String label;
  final int count;
  final bool isActive;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isActive
            ? Border(bottom: BorderSide(color: activeColor, width: 3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? activeColor : AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? activeColor : AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: isActive ? AppColors.onPrimary : AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrdersSortBar extends StatelessWidget {
  const OrdersSortBar({super.key, required this.oldestWaitMinutes});

  final int oldestWaitMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
                children: [
                  const TextSpan(text: 'La plus ancienne attend depuis '),
                  TextSpan(
                    text: '$oldestWaitMinutes min',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Par ancienneté',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
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
    return Container(
      height: 100,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                  color: valueColor,
                  fontSize: 30,
                  height: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.outlineVariant.withAlpha(50);
    Color foregroundColor = AppColors.onSurface;
    Color badgeColor = AppColors.surfaceContainerHighest;
    Color badgeTextColor = AppColors.onSurfaceVariant;

    if (isSelected) {
      // Simulate the orange color if selected, or default based on label
      borderColor = const Color(0xFFFF7900);
      foregroundColor = AppColors.onBackground;
      badgeColor = const Color(0xFFFF7900);
      badgeTextColor = AppColors.onPrimary;
    } else if (label == 'Orange') {
      badgeColor = const Color(0xFFFF7900).withAlpha(50);
      badgeTextColor = const Color(0xFFFF7900);
    } else if (label == 'MTN') {
      badgeColor = const Color(0xFFFFCC00).withAlpha(50);
      badgeTextColor = const Color(0xFFFFCC00);
    } else if (label == 'Moov') {
      badgeColor = const Color(0xFF0055A5).withAlpha(50);
      badgeTextColor = const Color(0xFF0055A5);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
        return const Color(0xFF0055A5);
    }
  }

  Widget _buildOperatorLogo() {
    String assetPath;
    switch (order.network) {
      case MobileNetwork.orange:
        assetPath = 'assets/images/orange_logo.png';
        break;
      case MobileNetwork.mtn:
        assetPath = 'assets/images/mtn_logo.png';
        break;
      case MobileNetwork.moov:
        assetPath = 'assets/images/moov_logo.png';
        break;
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(assetPath, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent
              ? AppColors.error
              : AppColors.outlineVariant.withAlpha(50),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: networkColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOperatorLogo(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withAlpha(0),
                                    border: Border.all(
                                      color: AppColors.success,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 11,
                                        color: AppColors.success,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'PAIEMENT CONFIRMÉ',
                                        style: TextStyle(
                                          color: AppColors.success,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: isUrgent
                                      ? AppColors.error
                                      : const Color(0xFFFFCC00),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isUrgent
                                      ? 'URGENTE • $waitingMinutes min'
                                      : '$waitingMinutes min',
                                  style: TextStyle(
                                    color: isUrgent
                                        ? AppColors.error
                                        : const Color(0xFFFFCC00),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              order.reference,
                              style: const TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Bénéficiaire',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.beneficiaryPhone,
                                style: const TextStyle(
                                  color: AppColors.onBackground,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order.offerLabel,
                                style: const TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatCfa(order.amount),
                          style: const TextStyle(
                            color: AppColors.onBackground,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (order.manualAssignmentRequired) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(18),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppColors.warning.withAlpha(80),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.assignment_ind_outlined,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'AFFECTATION MANUELLE REQUISE',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (assignmentLabel != null &&
                        assignmentLabel!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(18),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: AppColors.warning.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_pin_circle_outlined,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'Affectée à $assignmentLabel',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isProcessing || !isActionEnabled
                            ? null
                            : onTakeCharge,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF0F52BA,
                          ), // Deep blue from image
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isProcessing
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Traitement...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                actionLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QueueEmptyState extends StatelessWidget {
  const QueueEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.task_alt_rounded,
            size: 48,
            color: AppColors.success,
          ),
          const SizedBox(height: 14),
          Text(
            'Aucune commande à traiter',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
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
