import 'package:cabine_flow/core/theme/app_colors.dart';

import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
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
    if (trimmedName.isEmpty) return 'Utilisateur';
    return trimmedName.split(RegExp(r'\s+')).first;
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
              firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Color(0xFF1677FF),
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
              Row(
                children: [
                  Text(
                    'Bonjour $firstName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('👋', style: TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
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
          style: IconButton.styleFrom(foregroundColor: Colors.white),
          icon: Icon(icon, size: 26),
        ),
        if (showIndicator)
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFF1677FF),
                shape: BoxShape.circle,
              ),
              child: const Text(
                '1',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class DailyActivityCard extends StatelessWidget {
  const DailyActivityCard({
    super.key,
    required this.revenue,
    required this.percentageIncrease,
  });

  final int revenue;
  final double? percentageIncrease;

  String _formatAmount(int amount) {
    final String str = amount.toString();
    String result = '';
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result += ' ';
      }
      result += str[i];
    }
    return '$result F';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activité du jour',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CA encaissé',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatAmount(revenue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RevenueComparisonLabel(
                      percentageChange: percentageIncrease,
                      revenue: revenue,
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                height: 50,
                child: CustomPaint(painter: _SparklinePainter()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueComparisonLabel extends StatelessWidget {
  const _RevenueComparisonLabel({
    required this.percentageChange,
    required this.revenue,
  });

  final double? percentageChange;
  final int revenue;

  @override
  Widget build(BuildContext context) {
    if (percentageChange == null) {
      return const Text(
        'Premiers encaissements enregistrés',
        style: TextStyle(
          color: AppColors.primaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final double change = percentageChange!;
    final bool isPositive = change > 0;
    final bool isNegative = change < 0;
    final Color color = isPositive
        ? const Color(0xFF22C55E)
        : isNegative
        ? const Color(0xFFFF5A5F)
        : const Color(0xFF9CA3AF);
    final IconData icon = isPositive
        ? Icons.arrow_upward_rounded
        : isNegative
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;
    final String prefix = isPositive ? '+' : '';
    final String label = revenue == 0 && change == 0
        ? 'Aucun encaissement aujourd’hui'
        : '$prefix${change.toStringAsFixed(0)}% vs hier';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 10),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();

    final List<Offset> points = [
      Offset(0, size.height * 0.9),
      Offset(size.width * 0.15, size.height * 0.7),
      Offset(size.width * 0.3, size.height * 0.8),
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.65, size.height * 0.45),
      Offset(size.width * 0.85, size.height * 0.15),
      Offset(size.width, 0),
    ];

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
    }

    final Path fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primaryContainer.withAlpha(80), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final Paint dotPaint = Paint()..color = AppColors.primaryContainer;
    canvas.drawCircle(points.last, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OrderStatusCard extends StatelessWidget {
  const OrderStatusCard({
    super.key,
    required this.paidCount,
    required this.inProgressCount,
    required this.completedCount,
  });

  final int paidCount;
  final int inProgressCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statut des commandes payées',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStep(
                icon: Icons.credit_card_rounded,
                label: 'Payées',
                count: paidCount,
                isActive: true,
              ),
              _buildConnector(),
              _buildStep(
                icon: Icons.access_time_rounded,
                label: 'En cours',
                count: inProgressCount,
                isActive: true,
              ),
              _buildConnector(),
              _buildStep(
                icon: Icons.check_circle_outline_rounded,
                label: 'Terminées',
                count: completedCount,
                isActive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String label,
    required int count,
    required bool isActive,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF132A53) : const Color(0xFF1F2937),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primaryContainer : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: isActive
                ? AppColors.primaryContainer
                : const Color(0xFF9CA3AF),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector() {
    return Expanded(
      child: Stack(
        alignment: Alignment.center,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return CustomPaint(
                size: Size(constraints.maxWidth, 1),
                painter: _DashedLinePainter(),
              );
            },
          ),
          Container(
            padding: const EdgeInsets.only(top: 24),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF4B5563),
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.primaryContainer.withAlpha(100)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const double dashWidth = 4;
    const double dashSpace = 4;
    double startX = 10;
    final double endX = size.width - 10;

    while (startX < endX) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class OperatorBalanceCard extends StatelessWidget {
  const OperatorBalanceCard({
    super.key,
    required this.operatorName,
    required this.balance,
    required this.logoAsset,
    required this.accentColor,
    required this.signalBars,
  });

  final String operatorName;
  final int? balance;
  final String logoAsset;
  final Color accentColor;
  final int signalBars;

  String _formatAmount(int? amount) {
    if (amount == null) {
      return 'À renseigner';
    }

    final String str = amount.toString();
    String result = '';
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result += ' ';
      }
      result += str[i];
    }
    return '$result F';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withAlpha(100), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  logoAsset,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(width: 32, height: 32, color: accentColor);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  operatorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatAmount(balance),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.bottomRight,
                child: _SignalBars(
                  bars: balance == null ? 0 : signalBars,
                  color: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars, required this.color});
  final int bars;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final bool isActive = index < bars;
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: 4,
          height: 6.0 + (index * 3),
          decoration: BoxDecoration(
            color: isActive ? color : const Color(0xFF374151),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class WaveBalanceCard extends StatelessWidget {
  const WaveBalanceCard({super.key, required this.balance});

  final int? balance;

  String _formatAmount(int? amount) {
    if (amount == null) {
      return 'À renseigner';
    }
    final String str = amount.toString();
    String result = '';
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result += ' ';
      }
      result += str[i];
    }
    return '$result F';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/wave_logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF43B5FF),
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Caisse Wave',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Solde disponible',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(balance),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}

class PriorityAlertCard extends StatelessWidget {
  const PriorityAlertCard({
    super.key,
    required this.pendingOrdersCount,
    required this.oldestWaitMinutes,
    required this.onOpenQueue,
  });

  final int pendingOrdersCount;
  final int oldestWaitMinutes;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF1677FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$pendingOrdersCount commandes payées en attente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: 'La plus ancienne attend depuis ',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                    children: [
                      TextSpan(
                        text: '$oldestWaitMinutes min',
                        style: const TextStyle(color: Color(0xFF43B5FF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onOpenQueue,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ouvrir la file',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CabineBottomNavigationBar extends StatelessWidget {
  const CabineBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<_CabineNavigationItem> _items = [
    _CabineNavigationItem(
      label: 'Accueil',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _CabineNavigationItem(
      label: 'Commandes',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _CabineNavigationItem(
      label: 'Paiements',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
    ),
    _CabineNavigationItem(
      label: 'Finances',
      icon: Icons.pie_chart_outline_rounded,
      selectedIcon: Icons.pie_chart_rounded,
    ),
    _CabineNavigationItem(
      label: 'Plus',
      icon: Icons.more_horiz_rounded,
      selectedIcon: Icons.more_horiz_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 74,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: const BoxDecoration(
          color: Color(0xFF020713), // Ultra dark
          border: Border(top: BorderSide(color: Color(0x3343B5FF))),
        ),
        child: Row(
          children: List<Widget>.generate(_items.length, (int index) {
            final _CabineNavigationItem item = _items[index];
            final bool isSelected = index == selectedIndex;

            final Color itemColor = isSelected
                ? AppColors.primary
                : const Color(0xFF9CA3AF);

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    onDestinationSelected(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withAlpha(40)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          size: 23,
                          color: itemColor,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.label,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: itemColor,
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _CabineNavigationItem {
  const _CabineNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class PriorityOrderItemCard extends StatelessWidget {
  const PriorityOrderItemCard({
    super.key,
    required this.reference,
    required this.phoneNumber,
    required this.operationLabel,
    required this.amount,
    required this.channel,
    required this.statusLabel,
    required this.actionLabel,
    required this.onPressed,
  });

  final String reference;
  final String phoneNumber;
  final String operationLabel;
  final int amount;
  final String channel;
  final String statusLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  String _formatAmount(int amount) {
    final String str = amount.toString();
    String result = '';
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        result += ' ';
      }
      result += str[i];
    }
    return '$result F';
  }

  @override
  Widget build(BuildContext context) {
    Color getChannelColor() {
      switch (channel.toLowerCase()) {
        case 'orange':
          return const Color(0xFFFF7900);
        case 'mtn':
          return const Color(0xFFFFCC00);
        case 'moov':
          return const Color(0xFF0055A5);
        case 'wave':
          return AppColors.primaryContainer;
        default:
          return Colors.grey;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                operationLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getChannelColor().withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: getChannelColor()),
                ),
                child: Text(
                  channel.toUpperCase(),
                  style: TextStyle(
                    color: getChannelColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.phone_iphone_rounded,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                phoneNumber,
                style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Réf: $reference',
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatAmount(amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
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
