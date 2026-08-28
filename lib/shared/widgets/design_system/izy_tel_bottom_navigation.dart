import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

enum IzyTelCustomerDestination { home, offers, history, help }

class IzyTelBottomNavigation extends StatelessWidget {
  const IzyTelBottomNavigation({
    super.key,
    required this.current,
    required this.onHome,
    required this.onOffers,
    required this.onHistory,
    required this.onHelp,
  });

  final IzyTelCustomerDestination current;
  final VoidCallback onHome;
  final VoidCallback onOffers;
  final VoidCallback onHistory;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final Widget navigation = Row(
      children: [
        _NavItem(
          icon: Icons.home_rounded,
          label: 'Accueil',
          selected: current == IzyTelCustomerDestination.home,
          onTap: onHome,
        ),
        _NavItem(
          icon: Icons.hub_outlined,
          label: 'Forfaits',
          selected: current == IzyTelCustomerDestination.offers,
          onTap: onOffers,
        ),
        _NavItem(
          icon: Icons.history_rounded,
          label: 'Historique',
          selected: current == IzyTelCustomerDestination.history,
          onTap: onHistory,
        ),
        _NavItem(
          icon: Icons.support_agent_rounded,
          label: 'Aide',
          selected: current == IzyTelCustomerDestination.help,
          onTap: onHelp,
        ),
      ],
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CustomerAppColors.outlineSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: navigation,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? CustomerAppColors.navSelected
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? CustomerAppColors.primary
                      : CustomerAppColors.onSurfaceVariant,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? CustomerAppColors.primary
                        : CustomerAppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
