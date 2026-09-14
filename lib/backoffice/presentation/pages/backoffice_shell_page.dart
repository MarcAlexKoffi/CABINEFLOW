import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_dashboard_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_users_page.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_brand.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum BackofficeDestination {
  dashboard,
  orders,
  payments,
  assignments,
  failedOrders,
  customerRequests,
  refunds,
  agents,
  zones,
  agentIssues,
  users,
  offers,
  finances,
  waveCash,
  commissions,
  suppliers,
  customerCredits,
  expenses,
  workingCapital,
  reconciliations,
  movements,
  closings,
  activityJournal,
  audit,
  statistics,
}

enum _BackofficeSection {
  overview,
  operations,
  clients,
  team,
  administration,
  catalog,
  finances,
  control,
  pilotage,
}

extension _BackofficeDestinationX on BackofficeDestination {
  String get label {
    switch (this) {
      case BackofficeDestination.dashboard:
        return 'Tableau de bord';
      case BackofficeDestination.orders:
        return 'Commandes';
      case BackofficeDestination.payments:
        return 'Paiements';
      case BackofficeDestination.assignments:
        return 'Affectations';
      case BackofficeDestination.failedOrders:
        return 'Commandes échouées';
      case BackofficeDestination.customerRequests:
        return 'Demandes clients';
      case BackofficeDestination.refunds:
        return 'Remboursements';
      case BackofficeDestination.agents:
        return 'Agents';
      case BackofficeDestination.zones:
        return 'Zones & capacités';
      case BackofficeDestination.agentIssues:
        return 'Signalements agents';
      case BackofficeDestination.users:
        return 'Utilisateurs';
      case BackofficeDestination.offers:
        return 'Offres & tarifs';
      case BackofficeDestination.finances:
        return 'Vue financière';
      case BackofficeDestination.waveCash:
        return 'Caisse Wave';
      case BackofficeDestination.commissions:
        return 'Commissions';
      case BackofficeDestination.suppliers:
        return 'Fournisseurs';
      case BackofficeDestination.customerCredits:
        return 'Crédits clients';
      case BackofficeDestination.expenses:
        return 'Dépenses';
      case BackofficeDestination.workingCapital:
        return 'Fonds de roulement';
      case BackofficeDestination.reconciliations:
        return 'Rapprochements';
      case BackofficeDestination.movements:
        return 'Mouvements';
      case BackofficeDestination.closings:
        return 'Clôtures';
      case BackofficeDestination.activityJournal:
        return 'Journal d’activité';
      case BackofficeDestination.audit:
        return 'Audit / historique';
      case BackofficeDestination.statistics:
        return 'Statistiques';
    }
  }

  IconData get icon {
    switch (this) {
      case BackofficeDestination.dashboard:
        return Symbols.dashboard_rounded;
      case BackofficeDestination.orders:
        return Symbols.receipt_long_rounded;
      case BackofficeDestination.payments:
        return Symbols.payments_rounded;
      case BackofficeDestination.assignments:
        return Symbols.assignment_ind_rounded;
      case BackofficeDestination.failedOrders:
        return Symbols.error_rounded;
      case BackofficeDestination.customerRequests:
        return Symbols.support_agent_rounded;
      case BackofficeDestination.refunds:
        return Symbols.currency_exchange_rounded;
      case BackofficeDestination.agents:
        return Symbols.badge_rounded;
      case BackofficeDestination.zones:
        return Symbols.map_rounded;
      case BackofficeDestination.agentIssues:
        return Symbols.report_problem_rounded;
      case BackofficeDestination.users:
        return Symbols.manage_accounts_rounded;
      case BackofficeDestination.offers:
        return Symbols.local_offer_rounded;
      case BackofficeDestination.finances:
        return Symbols.account_balance_wallet_rounded;
      case BackofficeDestination.waveCash:
        return Symbols.account_balance_rounded;
      case BackofficeDestination.commissions:
        return Symbols.savings_rounded;
      case BackofficeDestination.suppliers:
        return Symbols.storefront_rounded;
      case BackofficeDestination.customerCredits:
        return Symbols.request_quote_rounded;
      case BackofficeDestination.expenses:
        return Symbols.receipt_rounded;
      case BackofficeDestination.workingCapital:
        return Symbols.toll_rounded;
      case BackofficeDestination.reconciliations:
        return Symbols.rule_rounded;
      case BackofficeDestination.movements:
        return Symbols.swap_horiz_rounded;
      case BackofficeDestination.closings:
        return Symbols.event_available_rounded;
      case BackofficeDestination.activityJournal:
        return Symbols.history_rounded;
      case BackofficeDestination.audit:
        return Symbols.fact_check_rounded;
      case BackofficeDestination.statistics:
        return Symbols.monitoring_rounded;
    }
  }

  _BackofficeSection get section {
    switch (this) {
      case BackofficeDestination.dashboard:
        return _BackofficeSection.overview;
      case BackofficeDestination.orders:
      case BackofficeDestination.payments:
      case BackofficeDestination.assignments:
      case BackofficeDestination.failedOrders:
        return _BackofficeSection.operations;
      case BackofficeDestination.customerRequests:
      case BackofficeDestination.refunds:
        return _BackofficeSection.clients;
      case BackofficeDestination.agents:
      case BackofficeDestination.zones:
      case BackofficeDestination.agentIssues:
        return _BackofficeSection.team;
      case BackofficeDestination.users:
        return _BackofficeSection.administration;
      case BackofficeDestination.offers:
        return _BackofficeSection.catalog;
      case BackofficeDestination.finances:
      case BackofficeDestination.waveCash:
      case BackofficeDestination.commissions:
      case BackofficeDestination.suppliers:
      case BackofficeDestination.customerCredits:
      case BackofficeDestination.expenses:
      case BackofficeDestination.workingCapital:
      case BackofficeDestination.reconciliations:
      case BackofficeDestination.movements:
      case BackofficeDestination.closings:
        return _BackofficeSection.finances;
      case BackofficeDestination.activityJournal:
      case BackofficeDestination.audit:
        return _BackofficeSection.control;
      case BackofficeDestination.statistics:
        return _BackofficeSection.pilotage;
    }
  }

  bool visibleFor(AppUser user) {
    final UserPermissions permissions = user.permissions;
    switch (this) {
      case BackofficeDestination.dashboard:
        return true;
      case BackofficeDestination.orders:
        return permissions.canAccessStaffShell;
      case BackofficeDestination.payments:
        return permissions.canConfirmPayments;
      case BackofficeDestination.assignments:
        return permissions.canAssignOrders;
      case BackofficeDestination.failedOrders:
        return permissions.canManageFailedOrders;
      case BackofficeDestination.customerRequests:
        return permissions.canViewSupportRequests;
      case BackofficeDestination.refunds:
        return permissions.canManageRefunds;
      case BackofficeDestination.agents:
      case BackofficeDestination.zones:
        return permissions.canViewAgentDirectory;
      case BackofficeDestination.agentIssues:
        return permissions.canResolveAgentIssues;
      case BackofficeDestination.users:
        return user.role == UserRole.administrator;
      case BackofficeDestination.offers:
        return permissions.canManageOffers;
      case BackofficeDestination.finances:
      case BackofficeDestination.waveCash:
      case BackofficeDestination.commissions:
      case BackofficeDestination.suppliers:
      case BackofficeDestination.customerCredits:
      case BackofficeDestination.expenses:
      case BackofficeDestination.workingCapital:
      case BackofficeDestination.reconciliations:
      case BackofficeDestination.movements:
      case BackofficeDestination.closings:
        return permissions.canViewOperationalFinances;
      case BackofficeDestination.activityJournal:
      case BackofficeDestination.audit:
      case BackofficeDestination.statistics:
        return permissions.canAccessStaffShell;
    }
  }

  String get milestone {
    switch (section) {
      case _BackofficeSection.overview:
      case _BackofficeSection.administration:
        return 'BO-1';
      case _BackofficeSection.operations:
        return 'BO-2';
      case _BackofficeSection.clients:
      case _BackofficeSection.team:
        return 'BO-3';
      case _BackofficeSection.catalog:
        return 'BO-4';
      case _BackofficeSection.finances:
        return 'BO-5';
      case _BackofficeSection.control:
      case _BackofficeSection.pilotage:
        return 'BO-6';
    }
  }
}

extension on _BackofficeSection {
  String get label {
    switch (this) {
      case _BackofficeSection.overview:
        return '';
      case _BackofficeSection.operations:
        return 'OPÉRATIONS';
      case _BackofficeSection.clients:
        return 'CLIENTS';
      case _BackofficeSection.team:
        return 'ÉQUIPE';
      case _BackofficeSection.administration:
        return 'ADMINISTRATION';
      case _BackofficeSection.catalog:
        return 'CATALOGUE';
      case _BackofficeSection.finances:
        return 'FINANCES';
      case _BackofficeSection.control:
        return 'CONTRÔLE';
      case _BackofficeSection.pilotage:
        return 'PILOTAGE';
    }
  }
}

class BackofficeShellPage extends StatefulWidget {
  const BackofficeShellPage({
    super.key,
    required this.user,
    required this.userRepository,
    required this.onLogout,
  });

  final AppUser user;
  final BackofficeUserRepository userRepository;
  final Future<void> Function() onLogout;

  @override
  State<BackofficeShellPage> createState() => _BackofficeShellPageState();
}

class _BackofficeShellPageState extends State<BackofficeShellPage> {
  BackofficeDestination _destination = BackofficeDestination.dashboard;

  List<BackofficeDestination> get _visibleDestinations {
    return BackofficeDestination.values
        .where((BackofficeDestination item) => item.visibleFor(widget.user))
        .toList(growable: false);
  }

  void _selectDestination(BackofficeDestination destination) {
    if (!destination.visibleFor(widget.user)) return;
    setState(() => _destination = destination);
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'La session du back-office sera fermée sur ce navigateur.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Symbols.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) await widget.onLogout();
  }

  Widget _contentFor(BackofficeDestination destination) {
    switch (destination) {
      case BackofficeDestination.dashboard:
        return BackofficeDashboardPage(
          user: widget.user,
          onOpenUsers: widget.user.role == UserRole.administrator
              ? () => _selectDestination(BackofficeDestination.users)
              : null,
        );
      case BackofficeDestination.users:
        return BackofficeUsersPage(
          currentUser: widget.user,
          repository: widget.userRepository,
        );
      default:
        return _BackofficeModulePlaceholder(destination: destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool desktop = width >= 1080;
    final List<BackofficeDestination> destinations = _visibleDestinations;

    if (!destinations.contains(_destination)) {
      _destination = BackofficeDestination.dashboard;
    }

    final Widget content = _BackofficeContentFrame(
      destination: _destination,
      user: widget.user,
      onLogout: _confirmLogout,
      child: _contentFor(_destination),
    );

    if (desktop) {
      return Scaffold(
        backgroundColor: BackofficePalette.canvas,
        body: Row(
          children: <Widget>[
            SizedBox(
              width: 292,
              child: _BackofficeSidebar(
                user: widget.user,
                destinations: destinations,
                selected: _destination,
                onSelected: _selectDestination,
                onLogout: _confirmLogout,
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: BackofficePalette.canvas,
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: BackofficePalette.surface,
        foregroundColor: BackofficePalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: BackofficePalette.line)),
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: BackofficePalette.primarySoft,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const IzyTelBrandMark(size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: BackofficePalette.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _BackofficeUserMenu(
              user: widget.user,
              onLogout: _confirmLogout,
              compact: true,
            ),
          ),
        ],
      ),
      drawer: Drawer(
        width: 310,
        backgroundColor: BackofficePalette.surface,
        child: _BackofficeSidebar(
          user: widget.user,
          destinations: destinations,
          selected: _destination,
          onSelected: (BackofficeDestination destination) {
            Navigator.of(context).pop();
            _selectDestination(destination);
          },
          onLogout: () {
            Navigator.of(context).pop();
            _confirmLogout();
          },
          drawerMode: true,
        ),
      ),
      body: content,
    );
  }
}

class _BackofficeSidebar extends StatelessWidget {
  const _BackofficeSidebar({
    required this.user,
    required this.destinations,
    required this.selected,
    required this.onSelected,
    required this.onLogout,
    this.drawerMode = false,
  });

  final AppUser user;
  final List<BackofficeDestination> destinations;
  final BackofficeDestination selected;
  final ValueChanged<BackofficeDestination> onSelected;
  final VoidCallback onLogout;
  final bool drawerMode;

  @override
  Widget build(BuildContext context) {
    final List<_BackofficeSection> sections = _BackofficeSection.values
        .where(
          (_BackofficeSection section) => destinations.any(
            (BackofficeDestination item) => item.section == section,
          ),
        )
        .toList(growable: false);

    return Material(
      color: BackofficePalette.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: BackofficePalette.surface,
          border: Border(right: BorderSide(color: BackofficePalette.line)),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(drawerMode ? 18 : 20, 20, 18, 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: BackofficePalette.primarySoft,
                        border: Border.all(color: const Color(0xFFDCE7FF)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const IzyTelBrandMark(size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'IzyTel',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: BackofficePalette.ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.35,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Back-office',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: BackofficePalette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: BackofficePalette.primarySoft,
                    border: Border.all(color: const Color(0xFFDCE7FF)),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Symbols.verified_user_rounded,
                          size: 18,
                          color: BackofficePalette.primary,
                          fill: 1,
                          weight: 600,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              user.role == UserRole.administrator
                                  ? 'Espace Administrateur'
                                  : 'Espace Manager',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: BackofficePalette.primaryStrong,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              user.role == UserRole.administrator
                                  ? 'Accès complet'
                                  : 'Supervision opérationnelle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: BackofficePalette.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                    children: <Widget>[
                      for (final _BackofficeSection section
                          in sections) ...<Widget>[
                        if (section.label.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              section.label,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: BackofficePalette.faint,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .9,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 7),
                        ],
                        for (final BackofficeDestination destination
                            in destinations.where(
                              (BackofficeDestination item) =>
                                  item.section == section,
                            ))
                          _BackofficeNavTile(
                            destination: destination,
                            selected: destination == selected,
                            onTap: () => onSelected(destination),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (drawerMode)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: BackofficePalette.sidebarLine),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: _BackofficeUserMenu(
                    user: user,
                    onLogout: onLogout,
                    fillWidth: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackofficeNavTile extends StatelessWidget {
  const _BackofficeNavTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final BackofficeDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(13),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: selected ? BackofficeGradients.selectedNav : null,
            border: Border.all(
              color: selected ? const Color(0xFFDCE7FF) : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: InkWell(
            onTap: onTap,
            hoverColor: BackofficePalette.surfaceAlt,
            splashColor: BackofficePalette.primarySoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? BackofficePalette.primary
                          : BackofficePalette.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      destination.icon,
                      size: 20,
                      color: selected
                          ? Colors.white
                          : BackofficePalette.primaryStrong,
                      fill: selected ? 1 : 0,
                      weight: selected ? 650 : 520,
                      opticalSize: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? BackofficePalette.primaryStrong
                            : BackofficePalette.ink,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: BackofficePalette.primary,
                        shape: BoxShape.circle,
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

class _BackofficeContentFrame extends StatelessWidget {
  const _BackofficeContentFrame({
    required this.destination,
    required this.user,
    required this.onLogout,
    required this.child,
  });

  final BackofficeDestination destination;
  final AppUser user;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1080;

    return Column(
      children: <Widget>[
        if (desktop)
          Container(
            height: 84,
            padding: const EdgeInsets.symmetric(horizontal: 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: BackofficePalette.line)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          destination.icon,
                          color: BackofficePalette.primary,
                          size: 22,
                          fill: 1,
                          weight: 620,
                          opticalSize: 24,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            destination.label,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'IzyTel / ${_sectionLabel(destination.section)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: BackofficePalette.faint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FBF6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: BackofficePalette.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Espace sécurisé',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: BackofficePalette.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _BackofficeUserMenu(user: user, onLogout: onLogout),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: ColoredBox(color: BackofficePalette.canvas),
              ),
              Positioned(
                top: -140,
                right: -120,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: const BoxDecoration(
                    color: Color(0x0E2F6BFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 30 : 18,
                  desktop ? 28 : 20,
                  desktop ? 30 : 18,
                  42,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _sectionLabel(_BackofficeSection section) {
    final String label = section.label;
    return label.isEmpty ? 'APERÇU' : label;
  }
}

class _BackofficeUserMenu extends StatelessWidget {
  const _BackofficeUserMenu({
    required this.user,
    required this.onLogout,
    this.compact = false,
    this.fillWidth = false,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final bool compact;
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final Widget child = Container(
      width: fillWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: BackofficePalette.surfaceAlt,
        border: Border.all(color: BackofficePalette.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: fillWidth ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 30 : 36,
            height: compact ? 30 : 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: BackofficeGradients.brand,
              shape: BoxShape.circle,
              boxShadow: BackofficeShadows.glow,
            ),
            child: Text(
              _initials(user.name),
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          if (!compact) ...<Widget>[
            const SizedBox(width: 10),
            if (fillWidth)
              Expanded(child: _UserIdentityCopy(user: user))
            else
              _UserIdentityCopy(user: user),
            const SizedBox(width: 7),
            Icon(
              Symbols.expand_more_rounded,
              size: 18,
              color: BackofficePalette.muted,
            ),
          ],
        ],
      ),
    );

    return PopupMenuButton<String>(
      tooltip: 'Compte',
      onSelected: (String value) {
        if (value == 'logout') onLogout();
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(user.roleLabel),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: <Widget>[
              Icon(Symbols.logout_rounded, size: 20),
              SizedBox(width: 10),
              Text('Se déconnecter'),
            ],
          ),
        ),
      ],
      child: child,
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _UserIdentityCopy extends StatelessWidget {
  const _UserIdentityCopy({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 155),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            user.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: BackofficePalette.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            user.roleLabel,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: BackofficePalette.muted),
          ),
        ],
      ),
    );
  }
}

class _BackofficeModulePlaceholder extends StatelessWidget {
  const _BackofficeModulePlaceholder({required this.destination});

  final BackofficeDestination destination;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          destination.section.label.isEmpty
              ? 'ESPACE IZYTEL'
              : destination.section.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: BackofficePalette.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          destination.label,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 7),
        Text(
          'La navigation est prête. Le branchement métier de ce module est prévu dans ${destination.milestone}.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: IzyTelSpacing.xl),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 300),
          decoration: BoxDecoration(
            gradient: BackofficeGradients.soft,
            border: Border.all(color: BackofficePalette.line),
            borderRadius: BorderRadius.circular(24),
            boxShadow: BackofficeShadows.panel,
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -80,
                right: -65,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    color: Color(0x102F6BFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: BackofficeGradients.brand,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: BackofficeShadows.glow,
                      ),
                      child: Icon(
                        destination.icon,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Module en préparation',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 650),
                      child: Text(
                        'L’écran Web sera connecté à la même logique métier et aux mêmes backends que le mobile. Aucun flux validé n’est dupliqué ou remplacé.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
