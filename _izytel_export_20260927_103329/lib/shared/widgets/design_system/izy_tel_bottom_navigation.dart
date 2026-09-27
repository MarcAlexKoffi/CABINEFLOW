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
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;

    final Widget navigation = Row(
      children: <Widget>[
        _NavItem(
          icon: Icons.home_rounded,
          label: 'Accueil',
          selected: current == IzyTelCustomerDestination.home,
          onTap: onHome,
          desktop: desktop,
        ),
        _NavItem(
          icon: Icons.local_offer_outlined,
          label: 'Offres',
          selected: current == IzyTelCustomerDestination.offers,
          onTap: onOffers,
          desktop: desktop,
        ),
        _NavItem(
          icon: Icons.history_rounded,
          label: 'Historique',
          selected: current == IzyTelCustomerDestination.history,
          onTap: onHistory,
          desktop: desktop,
        ),
        _NavItem(
          icon: Icons.support_agent_rounded,
          label: 'Aide',
          selected: current == IzyTelCustomerDestination.help,
          onTap: onHelp,
          desktop: desktop,
        ),
      ],
    );

    if (desktop) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 610),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: CustomerAppColors.outlineSoft),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 26,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: navigation,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CustomerAppColors.outlineSoft)),
        boxShadow: <BoxShadow>[
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
    required this.desktop,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 8 : 2,
                vertical: desktop ? 9 : 7,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? CustomerAppColors.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: desktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          icon,
                          size: 19,
                          color: selected
                              ? CustomerAppColors.primary
                              : CustomerAppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? CustomerAppColors.primaryDeep
                                  : CustomerAppColors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
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
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
