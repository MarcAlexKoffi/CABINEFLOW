import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.user,
    required this.dateLabel,
    required this.onSearchPressed,
    required this.onNotificationsPressed,
  });

  final AppUser user;
  final String dateLabel;
  final VoidCallback onSearchPressed;
  final VoidCallback onNotificationsPressed;

  String get firstName {
    final String trimmedName = user.name.trim();

    if (trimmedName.isEmpty) {
      return 'Utilisateur';
    }

    return trimmedName.split(RegExp(r'\s+')).first;
  }

  String get initial {
    final String trimmedName = user.name.trim();

    if (trimmedName.isEmpty) {
      return '?';
    }

    return trimmedName[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: AppColors.surfaceContainerHigh,
          foregroundColor: AppColors.primary,
          child: Text(
            initial,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour $firstName',
                style: const TextStyle(
                  color: AppColors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _HeaderButton(
          icon: Icons.search_rounded,
          tooltip: 'Rechercher',
          onPressed: onSearchPressed,
        ),
        const SizedBox(width: 8),
        _HeaderButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          showIndicator: true,
          onPressed: onNotificationsPressed,
        ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.showIndicator = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceContainer,
            foregroundColor: AppColors.onSurface,
          ),
          icon: Icon(icon),
        ),
        if (showIndicator)
          const Positioned(
            top: 7,
            right: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: SizedBox(width: 7, height: 7),
            ),
          ),
      ],
    );
  }
}

class QueueOverviewCard extends StatelessWidget {
  const QueueOverviewCard({
    super.key,
    required this.orderCount,
    required this.averageWaitingMinutes,
    required this.onOpenQueue,
  });

  final int orderCount;
  final int averageWaitingMinutes;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(120)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(30),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$orderCount commandes à traiter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Moyenne : $averageWaitingMinutes min',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpenQueue,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Voir la file d’attente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardStatisticCard extends StatelessWidget {
  const DashboardStatisticCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.accentColor,
  });

  final int value;
  final String label;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(45),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const Spacer(),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.balance});

  final AccountBalance balance;

  String get label {
    switch (balance.channel) {
      case ServiceChannel.orange:
        return 'Orange';
      case ServiceChannel.mtn:
        return 'MTN';
      case ServiceChannel.moov:
        return 'Moov';
      case ServiceChannel.wave:
        return 'Wave';
    }
  }

  String get shortCode {
    switch (balance.channel) {
      case ServiceChannel.orange:
        return 'O';
      case ServiceChannel.mtn:
        return 'M';
      case ServiceChannel.moov:
        return 'Mv';
      case ServiceChannel.wave:
        return 'W';
    }
  }

  Color get accentColor {
    switch (balance.channel) {
      case ServiceChannel.orange:
        return AppColors.orange;
      case ServiceChannel.mtn:
        return AppColors.mtn;
      case ServiceChannel.moov:
        return AppColors.moov;
      case ServiceChannel.wave:
        return AppColors.wave;
    }
  }

  Color get codeTextColor {
    switch (balance.channel) {
      case ServiceChannel.mtn:
      case ServiceChannel.wave:
        return Colors.black;
      case ServiceChannel.orange:
      case ServiceChannel.moov:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 158,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(110)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -25,
            right: -25,
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                color: accentColor.withAlpha(25),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 25,
                    height: 25,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      shortCode,
                      style: TextStyle(
                        color: codeTextColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                ],
              ),
              const Spacer(),
              Text(
                formatCfa(balance.amount),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PriorityOrderCard extends StatelessWidget {
  const PriorityOrderCard({
    super.key,
    required this.order,
    required this.onPressed,
  });

  final PriorityOrder order;
  final VoidCallback onPressed;

  String get channelCode {
    switch (order.channel) {
      case ServiceChannel.orange:
        return 'O';
      case ServiceChannel.mtn:
        return 'M';
      case ServiceChannel.moov:
        return 'Mv';
      case ServiceChannel.wave:
        return 'W';
    }
  }

  Color get channelColor {
    switch (order.channel) {
      case ServiceChannel.orange:
        return AppColors.orange;
      case ServiceChannel.mtn:
        return AppColors.mtn;
      case ServiceChannel.moov:
        return AppColors.moov;
      case ServiceChannel.wave:
        return AppColors.wave;
    }
  }

  Color get channelTextColor {
    if (order.channel == ServiceChannel.mtn ||
        order.channel == ServiceChannel.wave) {
      return Colors.black;
    }

    return Colors.white;
  }

  String get statusLabel {
    switch (order.status) {
      case PriorityOrderStatus.urgent:
        return 'Urgent';
      case PriorityOrderStatus.pendingVerification:
        return 'Attente vérif';
      case PriorityOrderStatus.inProgress:
        return 'En cours';
    }
  }

  Color get statusColor {
    switch (order.status) {
      case PriorityOrderStatus.urgent:
        return AppColors.error;
      case PriorityOrderStatus.pendingVerification:
        return AppColors.warning;
      case PriorityOrderStatus.inProgress:
        return AppColors.onSurfaceVariant;
    }
  }

  bool get isDisabled {
    return order.status == PriorityOrderStatus.inProgress;
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outlineVariant.withAlpha(110)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: channelColor.withAlpha(35),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: channelColor,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      channelCode,
                      style: TextStyle(
                        color: channelTextColor,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.phoneNumber,
                        style: const TextStyle(
                          color: AppColors.onBackground,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Réf : #${order.reference}',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: statusColor.withAlpha(65)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Divider(height: 1, color: AppColors.outlineVariant.withAlpha(100)),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.operationLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        formatCfa(order.amount),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                if (order.status == PriorityOrderStatus.pendingVerification)
                  FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(95, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: Text(order.actionLabel),
                  )
                else
                  OutlinedButton(
                    onPressed: isDisabled ? null : onPressed,
                    child: Text(order.actionLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String formatCfa(int amount) {
  final String digits = amount.toString();
  final StringBuffer result = StringBuffer();

  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      result.write(' ');
    }

    result.write(digits[index]);
  }

  return '${result.toString()} F';
}
