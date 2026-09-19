import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/services/session_preferences.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_issue_center_page.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_management_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/auth/presentation/pages/staff_personal_profile_page.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/manager_profile_avatar.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_repository.dart';
import 'package:cabine_flow/features/control/data/repositories/supabase_control_repository.dart';
import 'package:cabine_flow/features/control/presentation/pages/manager_pilotage_page.dart';
import 'package:cabine_flow/features/finances/data/repositories/manager_read_only_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/presentation/pages/cabiniste_finance_supervision_page.dart';
import 'package:cabine_flow/features/finances/presentation/pages/supplier_finance_page.dart';
import 'package:cabine_flow/features/managers/presentation/pages/manager_accounts_page.dart';
import 'package:cabine_flow/features/team/presentation/pages/team_performance_page.dart';
import 'package:cabine_flow/features/more/presentation/pages/admin_activity_journal_page.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/presentation/pages/offer_management_page.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/failed_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/pages/orders_page.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/operational_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/operational_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/features/support/presentation/pages/support_request_center_page.dart';
import 'package:cabine_flow/shared/widgets/feature_placeholder_page.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.user,
    required this.authRepository,
    required this.adminOfferRepository,
    required this.agentRepository,
    required this.ordersRepository,
    this.commissionRepository,
    this.onOpenPayments,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final AdminOfferRepository adminOfferRepository;
  final AgentRepository agentRepository;
  final OrdersRepository ordersRepository;
  final CommissionRepository? commissionRepository;
  final VoidCallback? onOpenPayments;

  Future<void> _logout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Se déconnecter ?'),
          content: Text(
            user.isManager
              ? 'Tu devras te reconnecter pour accéder de nouveau à ton espace Manager.'
              : 'Tu devras te reconnecter pour accéder de nouveau à l’espace Administration.',
          ),
          actions: [
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

    if (confirmed != true || !context.mounted) return;
    try {
      await authRepository.logout();
      await SessionPreferences.clear();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      IzyTelFeedback.error(
        context,
        'Impossible de se déconnecter pour le moment.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.isManager) {
      return _buildManager(context);
    }
    if (user.role != UserRole.administrator) {
      return const FeaturePlaceholderPage(
        title: 'Plus',
        description: 'Accède aux autres fonctions de IzyTel.',
        message:
            'Le profil, les paramètres et les fonctions autorisées pour ton rôle seront placés ici.',
        icon: Symbols.apps_rounded,
      );
    }

    final SupportRequestRepository supportRepository =
        createOperationalSupportRequestRepository();
    final RefundRepository refundRepository = createOperationalRefundRepository();
    final OrderHistoryRepository? historyRepository =
        ordersRepository is OrderHistoryRepository
        ? ordersRepository as OrderHistoryRepository
        : null;

    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<SupportRequest>>(
          stream: supportRepository.watchAllRequests(),
          builder: (BuildContext context, AsyncSnapshot<List<SupportRequest>> snapshot) {
            final List<SupportRequest> requests =
                snapshot.data ?? const <SupportRequest>[];
            final int activeRequests = requests
                .where((SupportRequest request) => request.isActive)
                .length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                IzyTelPageHeader(
                  title: 'Administration',
                  subtitle: 'Paramètres, catalogue, équipe et contrôle.',
                  actions: [
                    IzyTelAvatar(
                      name: user.name,
                      size: 42,
                      onTap: () {
                        showIzyTelAccountSheet(
                          context: context,
                          name: user.name,
                          role: user.roleLabel,
                          actions: <IzyTelAccountAction>[
                            IzyTelAccountAction(
                              icon: Symbols.support_agent_rounded,
                              label: 'Demandes clients',
                              onTap: historyRepository == null
                                  ? () => _historyUnavailable(context)
                                  : () {
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (BuildContext context) {
                                            return SupportRequestCenterPage(
                                              user: user,
                                              repository: supportRepository,
                                              refundRepository:
                                                  refundRepository,
                                              orderHistoryRepository:
                                                  historyRepository,
                                            );
                                          },
                                        ),
                                      );
                                    },
                            ),
                            IzyTelAccountAction(
                              icon: Symbols.groups_rounded,
                              label: 'Agents',
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) {
                                      return AgentManagementPage(
                                        user: user,
                                        repository: agentRepository,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            IzyTelAccountAction(
                              icon: Symbols.storefront_rounded,
                              label: 'Cabinistes',
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        CabinisteFinanceSupervisionPage(viewer: user),
                                  ),
                                );
                              },
                            ),
                            IzyTelAccountAction(
                              icon: Symbols.supervisor_account_rounded,
                              label: 'Managers',
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ManagerAccountsPage(viewer: user),
                                  ),
                                );
                              },
                            ),
                            IzyTelAccountAction(
                              icon: Symbols.report_problem_rounded,
                              label: 'Signalements agents',
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) {
                                      return AgentIssueCenterPage(
                                        user: user,
                                        repository: agentRepository,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            IzyTelAccountAction(
                              icon: Symbols.local_offer_rounded,
                              label: 'Offres',
                              onTap: () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) {
                                      return OfferManagementPage(
                                        user: user,
                                        repository: adminOfferRepository,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            IzyTelAccountAction(
                              icon: Symbols.logout_rounded,
                              label: 'Se déconnecter',
                              destructive: true,
                              onTap: () => _logout(context),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                _StaffIdentityCard(user: user),
                const SizedBox(height: IzyTelSpacing.xl),
                const _SectionLabel('Clients & assistance'),
                const SizedBox(height: 6),
                IzyTelSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IzyTelMenuRow(
                        icon: Symbols.support_agent_rounded,
                        title: 'Demandes clients',
                        subtitle:
                            'Vérifications, incidents, suivi et résolution des demandes.',
                        badge: activeRequests > 0 ? '$activeRequests' : null,
                        iconColor: IzyTelColors.warning,
                        onTap: historyRepository == null
                            ? () => _historyUnavailable(context)
                            : () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) {
                                      return SupportRequestCenterPage(
                                        user: user,
                                        repository: supportRepository,
                                        refundRepository: refundRepository,
                                        orderHistoryRepository:
                                            historyRepository,
                                      );
                                    },
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                const _SectionLabel('Catalogue'),
                const SizedBox(height: 6),
                IzyTelSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: IzyTelMenuRow(
                    icon: Symbols.local_offer_rounded,
                    title: 'Offres',
                    subtitle:
                        'Créer, tarifer, suspendre et organiser le catalogue IzyTel.',
                    iconColor: IzyTelColors.primary,
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) {
                            return OfferManagementPage(
                              user: user,
                              repository: adminOfferRepository,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                const _SectionLabel('Équipe'),
                const SizedBox(height: 6),
                IzyTelSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IzyTelMenuRow(
                        icon: Symbols.groups_rounded,
                        title: 'Agents',
                        subtitle:
                            'Disponibilité, capacités, réseaux, zones et profils Agents.',
                        iconColor: IzyTelColors.moov,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) {
                                return AgentManagementPage(
                                  user: user,
                                  repository: agentRepository,
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      IzyTelMenuRow(
                        icon: Symbols.storefront_rounded,
                        title: 'Cabinistes',
                        subtitle:
                            'Comptes Cabinistes, activité, gain IzyTel et montants à reverser.',
                        iconColor: IzyTelColors.orange,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  CabinisteFinanceSupervisionPage(viewer: user),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      IzyTelMenuRow(
                        icon: Symbols.supervisor_account_rounded,
                        title: 'Managers',
                        subtitle:
                            'Consulter les comptes Managers et leurs informations.',
                        iconColor: IzyTelColors.primary,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => ManagerAccountsPage(viewer: user),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      IzyTelMenuRow(
                        icon: Symbols.analytics_rounded,
                        title: 'Performance équipe',
                        subtitle:
                            'Vue globale des volumes, gains IzyTel, commissions Agents et règlements Cabinistes.',
                        iconColor: IzyTelColors.success,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => TeamPerformancePage(user: user),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      IzyTelMenuRow(
                        icon: Symbols.report_problem_rounded,
                        title: 'Signalements agents',
                        subtitle:
                            'Consulter, filtrer et traiter les incidents remontés par les agents.',
                        iconColor: IzyTelColors.warning,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) {
                                return AgentIssueCenterPage(
                                  user: user,
                                  repository: agentRepository,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                const _SectionLabel('Contrôle'),
                const SizedBox(height: 6),
                IzyTelSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IzyTelMenuRow(
                        icon: Symbols.assignment_rounded,
                        title: 'Affectations & réaffectations',
                        subtitle:
                            'Suivre les commandes affectées, réaffectées après refus ou à affecter manuellement.',
                        iconColor: IzyTelColors.primary,
                        onTap: () {
                          Navigator.of(context).push<void>(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) {
                                return OrdersPage(
                                  user: user,
                                  ordersRepository: ordersRepository,
                                  agentRepository: agentRepository,
                                );
                              },
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      IzyTelMenuRow(
                        icon: Symbols.error_rounded,
                        title: 'Commandes échouées',
                        subtitle:
                            'Traiter officiellement les échecs : réaffectation ou remboursement.',
                        iconColor: IzyTelColors.error,
                        onTap: historyRepository == null
                            ? () => _historyUnavailable(context)
                            : () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) {
                                      return FailedOrdersPage(
                                        user: user,
                                        ordersRepository: ordersRepository,
                                        orderHistoryRepository:
                                            historyRepository,
                                        agentRepository: agentRepository,
                                      );
                                    },
                                  ),
                                );
                              },
                      ),
                      const Divider(height: 1),
                      IzyTelMenuRow(
                        icon: Symbols.history_rounded,
                        title: 'Journal d’activité',
                        subtitle:
                            'Retrouver les évolutions récentes des commandes et demandes.',
                        iconColor: IzyTelColors.success,
                        onTap: historyRepository == null
                            ? () => _historyUnavailable(context)
                            : () {
                                Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) {
                                      return AdminActivityJournalPage(
                                        user: user,
                                        orderHistoryRepository:
                                            historyRepository,
                                        supportRequestRepository:
                                            supportRepository,
                                      );
                                    },
                                  ),
                                );
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: IzyTelSpacing.lg),
                const _SectionLabel('Compte'),
                const SizedBox(height: 6),
                IzyTelSurface(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: IzyTelMenuRow(
                    icon: Symbols.logout_rounded,
                    title: 'Se déconnecter',
                    subtitle:
                        'Fermer la session Administration sur cet appareil.',
                    destructive: true,
                    onTap: () => _logout(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildManager(BuildContext context) {
    final UserPermissions permissions = user.permissions;
    final SupportRequestRepository supportRepository =
        createOperationalSupportRequestRepository();
    final OrderHistoryRepository? historyRepository =
        ordersRepository is OrderHistoryRepository
        ? ordersRepository as OrderHistoryRepository
        : null;

    void openSupportRequests() {
      final OrderHistoryRepository? history = historyRepository;
      if (history == null) {
        _historyUnavailable(context);
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => SupportRequestCenterPage(
            user: user,
            repository: supportRepository,
            // Le Manager supervise les demandes sans droit de gestion
            // des remboursements operationnels Supabase.
            refundRepository: FakeRefundRepository(),
            orderHistoryRepository: history,
          ),
        ),
      );
    }

    void openAssignments() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => OrdersPage(
            user: user,
            ordersRepository: ordersRepository,
            agentRepository: agentRepository,
          ),
        ),
      );
    }

    void openIssues() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => AgentIssueCenterPage(
            user: user,
            repository: agentRepository,
          ),
        ),
      );
    }

    void openAgents() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => AgentManagementPage(
            user: user,
            repository: agentRepository,
          ),
        ),
      );
    }

    void openCabinistes() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CabinisteFinanceSupervisionPage(viewer: user),
        ),
      );
    }

    void openPerformance() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TeamPerformancePage(user: user),
        ),
      );
    }

    void openSuppliers() {
      if (!SupabaseBootstrap.isInitialized) {
        IzyTelFeedback.show(
          context,
          'La gestion des fournisseurs de zone nécessite Supabase.',
          tone: IzyTelFeedbackTone.warning,
        );
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SupplierFinancePage(
            user: user,
            repository: ManagerReadOnlyFinanceOperationsRepository(),
            agentRepository: agentRepository,
          ),
        ),
      );
    }

    void openMyProfile() {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => StaffPersonalProfilePage(user: user),
        ),
      );
    }

    void openPilotage() {
      if (!SupabaseBootstrap.isInitialized) {
        IzyTelFeedback.show(
          context,
          'Le pilotage opérationnel nécessite la connexion Supabase.',
          tone: IzyTelFeedbackTone.warning,
        );
        return;
      }
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => ManagerPilotagePage(
            repository: SupabaseControlRepository(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: IzyTelColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            IzyTelPageHeader(
              title: 'Espace Manager',
              subtitle: 'Supervision opérationnelle et suivi IzyTel.',
              actions: <Widget>[
                ManagerProfileAvatar(
                  user: user,
                  size: 42,
                  onTap: () {
                    showIzyTelAccountSheet(
                      context: context,
                      name: user.name,
                      role: user.roleLabel,
                      actions: <IzyTelAccountAction>[
                        IzyTelAccountAction(
                          icon: Symbols.person_rounded,
                          label: 'Mon profil',
                          onTap: openMyProfile,
                        ),
                        if (permissions.canViewSupportRequests)
                          IzyTelAccountAction(
                            icon: Symbols.support_agent_rounded,
                            label: 'Demandes clients',
                            onTap: openSupportRequests,
                          ),
                        if (permissions.canAssignOrders)
                          IzyTelAccountAction(
                            icon: Symbols.assignment_rounded,
                            label: 'Affectations',
                            onTap: openAssignments,
                          ),
                        if (permissions.canViewAgentDirectory)
                          IzyTelAccountAction(
                            icon: Symbols.groups_rounded,
                            label: 'Agents',
                            onTap: openAgents,
                          ),
                        if (permissions.canViewAgentDirectory)
                          IzyTelAccountAction(
                            icon: Symbols.storefront_rounded,
                            label: 'Cabinistes',
                            onTap: openCabinistes,
                          ),
                        if (permissions.canResolveAgentIssues)
                          IzyTelAccountAction(
                            icon: Symbols.report_problem_rounded,
                            label: 'Signalements agents',
                            onTap: openIssues,
                          ),
                        IzyTelAccountAction(
                          icon: Symbols.analytics_rounded,
                          label: 'Performance de ma zone',
                          onTap: openPerformance,
                        ),
                        IzyTelAccountAction(
                          icon: Symbols.monitoring_rounded,
                          label: 'Pilotage opérationnel',
                          onTap: openPilotage,
                        ),
                        IzyTelAccountAction(
                          icon: Symbols.logout_rounded,
                          label: 'Se déconnecter',
                          destructive: true,
                          onTap: () => _logout(context),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: IzyTelSpacing.lg),
            _StaffIdentityCard(user: user),
            const SizedBox(height: IzyTelSpacing.xl),
            const _SectionLabel('Opérations'),
            const SizedBox(height: 6),
            IzyTelSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (permissions.canViewSupportRequests)
                    IzyTelMenuRow(
                      icon: Symbols.support_agent_rounded,
                      title: 'Demandes clients',
                      subtitle:
                          'Consulter les demandes et leur suivi sans modifier le dossier.',
                      iconColor: IzyTelColors.orange,
                      onTap: openSupportRequests,
                    ),
                  if (permissions.canViewSupportRequests &&
                      permissions.canAssignOrders)
                    const Divider(height: 1),
                  if (permissions.canAssignOrders)
                    IzyTelMenuRow(
                      icon: Symbols.assignment_rounded,
                      title: 'Affectations des commandes',
                      subtitle:
                          'Consulter les commandes réellement sans agent et leur affectation Phase 4.',
                      iconColor: IzyTelColors.primary,
                      onTap: openAssignments,
                    ),
                ],
              ),
            ),
            const SizedBox(height: IzyTelSpacing.lg),
            const _SectionLabel('Pilotage'),
            const SizedBox(height: 6),
            IzyTelSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IzyTelMenuRow(
                    icon: Symbols.analytics_rounded,
                    title: 'Performance de ma zone',
                    subtitle:
                        'Volume généré, gain IzyTel observé, commissions Agents et situation Cabinistes de tes zones.',
                    iconColor: IzyTelColors.success,
                    onTap: openPerformance,
                  ),
                  const Divider(height: 1),
                  IzyTelMenuRow(
                    icon: Symbols.monitoring_rounded,
                    title: 'Pilotage opérationnel',
                    subtitle:
                        'Suivre les commandes et incidents opérationnels de tes zones.',
                    iconColor: IzyTelColors.primary,
                    onTap: openPilotage,
                  ),
                ],
              ),
            ),
            if (permissions.canViewAgentDirectory ||
                permissions.canResolveAgentIssues) ...<Widget>[
              const SizedBox(height: IzyTelSpacing.lg),
              const _SectionLabel('Équipe'),
              const SizedBox(height: 6),
              IzyTelSurface(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (permissions.canViewAgentDirectory)
                      IzyTelMenuRow(
                        icon: Symbols.groups_rounded,
                        title: 'Agents',
                        subtitle:
                            'Superviser disponibilité, réseaux, zones et capacités.',
                        iconColor: IzyTelColors.moov,
                        onTap: openAgents,
                      ),
                    if (permissions.canViewAgentDirectory)
                      const Divider(height: 1),
                    if (permissions.canViewAgentDirectory)
                      IzyTelMenuRow(
                        icon: Symbols.storefront_rounded,
                        title: 'Cabinistes',
                        subtitle:
                            'Consulter uniquement les Cabinistes de tes zones, leur activité et leurs montants.',
                        iconColor: IzyTelColors.orange,
                        onTap: openCabinistes,
                      ),
                    if (permissions.canViewAgentDirectory)
                      const Divider(height: 1),
                    if (permissions.canViewAgentDirectory)
                      IzyTelMenuRow(
                        icon: Symbols.inventory_2_rounded,
                        title: 'Fournisseurs de ma zone',
                        subtitle:
                            'Gérer tes fournisseurs et recharger les Agents de tes zones. Les règlements restent Admin.',
                        iconColor: IzyTelColors.primary,
                        onTap: openSuppliers,
                      ),
                    if (permissions.canViewAgentDirectory &&
                        permissions.canResolveAgentIssues)
                      const Divider(height: 1),
                    if (permissions.canResolveAgentIssues)
                      IzyTelMenuRow(
                        icon: Symbols.report_problem_rounded,
                        title: 'Signalements agents',
                        subtitle:
                            'Consulter, filtrer et traiter les incidents remontés par les agents.',
                        iconColor: IzyTelColors.warning,
                        onTap: openIssues,
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: IzyTelSpacing.lg),
            const _SectionLabel('Compte'),
            const SizedBox(height: 6),
            IzyTelSurface(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IzyTelMenuRow(
                    icon: Symbols.person_rounded,
                    title: 'Mon profil',
                    subtitle: 'Photo, identité, coordonnées et contact d’urgence.',
                    iconColor: IzyTelColors.primary,
                    onTap: openMyProfile,
                  ),
                  const Divider(height: 1),
                  IzyTelMenuRow(
                    icon: Symbols.logout_rounded,
                    title: 'Se déconnecter',
                    subtitle: 'Fermer la session Manager sur cet appareil.',
                    destructive: true,
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _historyUnavailable(BuildContext context) {
    IzyTelFeedback.show(
      context,
      'L’historique n’est pas disponible avec ce dépôt de données.',
      tone: IzyTelFeedbackTone.warning,
    );
  }
}

class _StaffIdentityCard extends StatelessWidget {
  const _StaffIdentityCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(IzyTelSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[IzyTelColors.primary, IzyTelColors.primaryStrong],
        ),
        borderRadius: BorderRadius.circular(IzyTelRadii.largeCard),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x282E63EB),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (user.isManager)
            ManagerProfileAvatar(user: user, size: 52, editable: true)
          else
            IzyTelAvatar(
              name: user.name,
              size: 52,
              initialsOverride: _initials(user.name),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.roleLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white.withAlpha(220),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (user.isManager) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Touchez la photo pour la modifier',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                ],
                if (user.phoneNumber.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    user.phoneNumber,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withAlpha(190),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Symbols.verified_user_rounded,
            color: Colors.white,
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: IzyTelColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: .2,
      ),
    );
  }
}

String _initials(String value) {
  final List<String> parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
