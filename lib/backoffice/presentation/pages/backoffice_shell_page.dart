import 'dart:async';

import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/backoffice/data/repositories/fake_territory_repository.dart';
import 'package:cabine_flow/backoffice/domain/repositories/territory_repository.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_dashboard_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/clients/backoffice_refunds_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/clients/backoffice_support_requests_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/team/backoffice_agent_issues_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/team/backoffice_agents_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/team/backoffice_managers_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/team/backoffice_zones_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/backoffice_users_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_assignments_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_failed_orders_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_orders_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/operations/backoffice_payments_page.dart';
import 'package:cabine_flow/backoffice/presentation/pages/profile/backoffice_my_profile_page.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/backoffice/presentation/widgets/backoffice_order_widgets.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/permissions/user_permissions.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/staff_profile_avatar.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
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
  managers,
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
      case BackofficeDestination.managers:
        return 'Managers';
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
      case BackofficeDestination.managers:
        return Symbols.supervisor_account_rounded;
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
      case BackofficeDestination.managers:
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
      case BackofficeDestination.managers:
        return user.role == UserRole.administrator;
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
  IconData get icon {
    switch (this) {
      case _BackofficeSection.overview:
        return Symbols.dashboard_rounded;
      case _BackofficeSection.operations:
        return Symbols.receipt_long_rounded;
      case _BackofficeSection.clients:
        return Symbols.support_agent_rounded;
      case _BackofficeSection.team:
        return Symbols.groups_rounded;
      case _BackofficeSection.administration:
        return Symbols.admin_panel_settings_rounded;
      case _BackofficeSection.catalog:
        return Symbols.local_offer_rounded;
      case _BackofficeSection.finances:
        return Symbols.account_balance_wallet_rounded;
      case _BackofficeSection.control:
        return Symbols.fact_check_rounded;
      case _BackofficeSection.pilotage:
        return Symbols.monitoring_rounded;
    }
  }

  String get menuLabel {
    switch (this) {
      case _BackofficeSection.overview:
        return 'Aperçu';
      case _BackofficeSection.operations:
        return 'Opérations';
      case _BackofficeSection.clients:
        return 'Clients';
      case _BackofficeSection.team:
        return 'Équipe';
      case _BackofficeSection.administration:
        return 'Administration';
      case _BackofficeSection.catalog:
        return 'Catalogue';
      case _BackofficeSection.finances:
        return 'Finances';
      case _BackofficeSection.control:
        return 'Contrôle';
      case _BackofficeSection.pilotage:
        return 'Pilotage';
    }
  }

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
    required this.ordersRepository,
    required this.agentRepository,
    this.territoryRepository,
    this.supportRepository,
    this.refundRepository,
    required this.onLogout,
  });

  final AppUser user;
  final BackofficeUserRepository userRepository;
  final OrdersRepository ordersRepository;
  final AgentRepository agentRepository;
  final TerritoryRepository? territoryRepository;
  final SupportRequestRepository? supportRepository;
  final RefundRepository? refundRepository;
  final Future<void> Function() onLogout;

  @override
  State<BackofficeShellPage> createState() => _BackofficeShellPageState();
}

class _BackofficeShellPageState extends State<BackofficeShellPage> {
  late final TerritoryRepository _territoryRepository;
  BackofficeDestination _destination = BackofficeDestination.dashboard;
  QueueOrder? _assignmentFocusOrder;
  String? _supportFocusOrderReference;
  String? _refundFocusOrderReference;
  StreamSubscription<List<QueueOrder>>? _paymentNotificationSubscription;
  StreamSubscription<List<QueueOrder>>? _assignmentNotificationSubscription;
  StreamSubscription<List<QueueOrder>>? _historyNotificationSubscription;
  StreamSubscription<List<SupportRequest>>? _supportNotificationSubscription;
  StreamSubscription<List<AgentIssue>>? _agentIssueNotificationSubscription;
  StreamSubscription<List<RefundCase>>? _refundNotificationSubscription;
  List<QueueOrder> _paymentNotificationOrders = const <QueueOrder>[];
  List<QueueOrder> _assignmentNotificationOrders = const <QueueOrder>[];
  List<QueueOrder> _historyNotificationOrders = const <QueueOrder>[];
  List<SupportRequest> _supportNotificationRequests = const <SupportRequest>[];
  List<AgentIssue> _agentIssueNotificationItems = const <AgentIssue>[];
  List<RefundCase> _refundNotificationItems = const <RefundCase>[];
  DateTime? _lastOperationalUpdateAt;

  @override
  void initState() {
    super.initState();
    _territoryRepository = widget.territoryRepository ?? FakeTerritoryRepository();
    _startOperationalNotificationWatchers();
  }

  @override
  void dispose() {
    _paymentNotificationSubscription?.cancel();
    _assignmentNotificationSubscription?.cancel();
    _historyNotificationSubscription?.cancel();
    _supportNotificationSubscription?.cancel();
    _agentIssueNotificationSubscription?.cancel();
    _refundNotificationSubscription?.cancel();
    super.dispose();
  }

  void _startOperationalNotificationWatchers() {
    _paymentNotificationSubscription = widget.ordersRepository
        .watchPaymentTrackingOrders()
        .listen(
          (List<QueueOrder> orders) {
            if (!mounted) return;
            setState(() {
              _paymentNotificationOrders = orders;
              _lastOperationalUpdateAt = DateTime.now();
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              'Backoffice.notifications.payments',
              error,
              stackTrace: stackTrace,
            );
          },
        );

    _assignmentNotificationSubscription = widget.ordersRepository
        .watchPaidQueue()
        .listen(
          (List<QueueOrder> orders) {
            if (!mounted) return;
            setState(() {
              _assignmentNotificationOrders = orders;
              _lastOperationalUpdateAt = DateTime.now();
            });
          },
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              'Backoffice.notifications.assignments',
              error,
              stackTrace: stackTrace,
            );
          },
        );

    final OrderHistoryRepository? historyRepository = _historyRepository;
    if (historyRepository != null) {
      _historyNotificationSubscription = historyRepository
          .watchOrderHistory()
          .listen(
            (List<QueueOrder> orders) {
              if (!mounted) return;
              setState(() {
                _historyNotificationOrders = orders;
                _lastOperationalUpdateAt = DateTime.now();
              });
            },
            onError: (Object error, StackTrace stackTrace) {
              IzyTelLog.backendError(
                'Backoffice.notifications.history',
                error,
                stackTrace: stackTrace,
              );
            },
          );
    }

    final SupportRequestRepository? supportRepository = widget.supportRepository;
    if (supportRepository != null &&
        BackofficeDestination.customerRequests.visibleFor(widget.user)) {
      _supportNotificationSubscription = supportRepository.watchAllRequests().listen(
        (List<SupportRequest> requests) {
          if (!mounted) return;
          setState(() {
            _supportNotificationRequests = requests;
            _lastOperationalUpdateAt = DateTime.now();
          });
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError('Backoffice.notifications.support', error, stackTrace: stackTrace);
        },
      );
    }

    if (BackofficeDestination.agentIssues.visibleFor(widget.user)) {
      _agentIssueNotificationSubscription = widget.agentRepository.watchAllAgentIssues().listen(
      (List<AgentIssue> issues) {
        if (!mounted) return;
        setState(() {
          _agentIssueNotificationItems = issues;
          _lastOperationalUpdateAt = DateTime.now();
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        IzyTelLog.backendError('Backoffice.notifications.agent-issues', error, stackTrace: stackTrace);
      },
    );
    }

    final RefundRepository? refundRepository = widget.refundRepository;
    if (refundRepository != null &&
        BackofficeDestination.refunds.visibleFor(widget.user)) {
      _refundNotificationSubscription = refundRepository.watchAll().listen(
        (List<RefundCase> refunds) {
          if (!mounted) return;
          setState(() {
          _refundNotificationItems = refunds;
          _lastOperationalUpdateAt = DateTime.now();
        });
        },
        onError: (Object error, StackTrace stackTrace) {
          IzyTelLog.backendError('Backoffice.notifications.refunds', error, stackTrace: stackTrace);
        },
      );
    }
  }

  bool _paymentRequiresVerification(QueueOrder order) {
    return order.hasPaymentToReviewAfterExpiration ||
        (order.source == OrderSource.customerWeb &&
            order.paymentStatus == OrderPaymentStatus.declared &&
            (order.status == QueueOrderStatus.paymentToVerify ||
                order.status == QueueOrderStatus.awaitingPayment));
  }

  List<_BackofficeNotificationEntry> get _operationalNotifications {
    final List<_BackofficeNotificationEntry> entries =
        <_BackofficeNotificationEntry>[];

    if (BackofficeDestination.payments.visibleFor(widget.user)) {
      final List<QueueOrder> pendingPayments = _paymentNotificationOrders
          .where(_paymentRequiresVerification)
          .toList(growable: false);
      if (pendingPayments.isNotEmpty) {
        final int amount = pendingPayments.fold<int>(
          0,
          (int total, QueueOrder order) => total + order.amount,
        );
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.payments,
            title:
                '${pendingPayments.length} paiement${pendingPayments.length > 1 ? 's' : ''} à vérifier',
            subtitle: '${formatCfa(amount)} en attente de validation',
            count: pendingPayments.length,
            icon: Symbols.fact_check_rounded,
            color: BackofficePalette.warning,
          ),
        );
      }
    }

    if (BackofficeDestination.assignments.visibleFor(widget.user)) {
      final List<QueueOrder> toAssign = _assignmentNotificationOrders
          .where(
            (QueueOrder order) =>
                order.status == QueueOrderStatus.paidReady &&
                !order.isAssignedToAgent,
          )
          .toList(growable: false);
      if (toAssign.isNotEmpty) {
        final int manual = toAssign
            .where((QueueOrder order) => order.manualAssignmentRequired)
            .length;
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.assignments,
            title:
                '${toAssign.length} commande${toAssign.length > 1 ? 's' : ''} à affecter',
            subtitle: manual > 0
                ? '$manual intervention${manual > 1 ? 's' : ''} manuelle${manual > 1 ? 's' : ''}'
                : 'Affectation agent en attente',
            count: toAssign.length,
            icon: Symbols.assignment_ind_rounded,
            color: BackofficePalette.primary,
          ),
        );
      }
    }

    if (BackofficeDestination.failedOrders.visibleFor(widget.user)) {
      final int failed = _historyNotificationOrders
          .where((QueueOrder order) => order.status == QueueOrderStatus.failed)
          .length;
      if (failed > 0) {
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.failedOrders,
            title: '$failed échec${failed > 1 ? 's' : ''} à traiter',
            subtitle: 'Commandes nécessitant une intervention',
            count: failed,
            icon: Symbols.error_rounded,
            color: BackofficePalette.danger,
          ),
        );
      }

      final int refundPending = _historyNotificationOrders
          .where(
            (QueueOrder order) => order.status == QueueOrderStatus.refundPending,
          )
          .length;
      if (refundPending > 0) {
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.failedOrders,
            title:
                '$refundPending remboursement${refundPending > 1 ? 's' : ''} en attente',
            subtitle: 'Dossiers financiers à suivre',
            count: refundPending,
            icon: Symbols.currency_exchange_rounded,
            color: BackofficePalette.warning,
          ),
        );
      }
    }

    if (BackofficeDestination.customerRequests.visibleFor(widget.user)) {
      final int newRequests = _supportNotificationRequests
          .where((SupportRequest request) => request.status == SupportRequestStatus.newRequest)
          .length;
      if (newRequests > 0) {
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.customerRequests,
            title: '$newRequests demande${newRequests > 1 ? 's' : ''} client${newRequests > 1 ? 's' : ''} à traiter',
            subtitle: 'Nouveaux tickets d’assistance',
            count: newRequests,
            icon: Symbols.support_agent_rounded,
            color: BackofficePalette.warning,
          ),
        );
      }
    }

    if (BackofficeDestination.agentIssues.visibleFor(widget.user)) {
      final int openIssues = _agentIssueNotificationItems
          .where((AgentIssue issue) => issue.status == 'open' || issue.status == 'in_progress')
          .length;
      if (openIssues > 0) {
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.agentIssues,
            title: '$openIssues signalement${openIssues > 1 ? 's' : ''} Agent à suivre',
            subtitle: 'Incidents ouverts ou en cours',
            count: openIssues,
            icon: Symbols.report_problem_rounded,
            color: BackofficePalette.warning,
          ),
        );
      }
    }

    if (BackofficeDestination.refunds.visibleFor(widget.user)) {
      final int pendingRefunds = _refundNotificationItems
          .where((RefundCase refund) => refund.status == RefundStatus.pendingApproval || refund.status == RefundStatus.approved)
          .length;
      if (pendingRefunds > 0) {
        entries.add(
          _BackofficeNotificationEntry(
            destination: BackofficeDestination.refunds,
            title: '$pendingRefunds remboursement${pendingRefunds > 1 ? 's' : ''} à suivre',
            subtitle: 'Validation ou exécution attendue',
            count: pendingRefunds,
            icon: Symbols.currency_exchange_rounded,
            color: BackofficePalette.warning,
          ),
        );
      }
    }

    return entries;
  }

  BackofficeDashboardSnapshot get _dashboardSnapshot {
    final List<QueueOrder> history = _historyNotificationOrders;
    final int completedOrders = history
        .where((QueueOrder order) => order.status == QueueOrderStatus.completed)
        .length;
    final int completedAmount = history
        .where((QueueOrder order) => order.status == QueueOrderStatus.completed)
        .fold<int>(0, (int total, QueueOrder order) => total + order.amount);
    final int activeOrders = history.where((QueueOrder order) {
      return order.status == QueueOrderStatus.paidReady ||
          order.status == QueueOrderStatus.inProgress ||
          order.status == QueueOrderStatus.onHold ||
          order.status == QueueOrderStatus.awaitingCustomerConfirmation ||
          order.status == QueueOrderStatus.refundPending;
    }).length;
    final int failedOrders = history
        .where((QueueOrder order) => order.status == QueueOrderStatus.failed)
        .length;
    final int pendingPayments = _paymentNotificationOrders
        .where(_paymentRequiresVerification)
        .length;
    final int pendingAssignments = _assignmentNotificationOrders
        .where(
          (QueueOrder order) =>
              order.status == QueueOrderStatus.paidReady &&
              !order.isAssignedToAgent,
        )
        .length;
    final int openSupportRequests = _supportNotificationRequests
        .where(
          (SupportRequest request) =>
              request.status == SupportRequestStatus.newRequest ||
              request.status == SupportRequestStatus.inProgress,
        )
        .length;
    final int pendingRefunds = _refundNotificationItems
        .where(
          (RefundCase refund) =>
              refund.status == RefundStatus.pendingApproval ||
              refund.status == RefundStatus.approved,
        )
        .length;
    final int openAgentIssues = _agentIssueNotificationItems
        .where(
          (AgentIssue issue) =>
              issue.status == 'open' || issue.status == 'in_progress',
        )
        .length;

    return BackofficeDashboardSnapshot(
      totalOrders: history.length,
      activeOrders: activeOrders,
      completedOrders: completedOrders,
      completedAmount: completedAmount,
      pendingPayments: pendingPayments,
      pendingAssignments: pendingAssignments,
      failedOrders: failedOrders,
      openSupportRequests: openSupportRequests,
      pendingRefunds: pendingRefunds,
      openAgentIssues: openAgentIssues,
      lastUpdatedAt: _lastOperationalUpdateAt,
    );
  }

  OrderHistoryRepository? get _historyRepository {
    final OrdersRepository repository = widget.ordersRepository;
    if (repository is! OrderHistoryRepository) {
      return null;
    }
    return repository as OrderHistoryRepository;
  }

  List<BackofficeDestination> get _visibleDestinations {
    return BackofficeDestination.values
        .where((BackofficeDestination item) => item.visibleFor(widget.user))
        .toList(growable: false);
  }

  void _selectDestination(BackofficeDestination destination) {
    if (!destination.visibleFor(widget.user)) return;
    setState(() {
      _destination = destination;
      if (destination != BackofficeDestination.assignments) {
        _assignmentFocusOrder = null;
      }
      _supportFocusOrderReference = null;
      _refundFocusOrderReference = null;
    });
  }

  void _openAssignmentsFor(QueueOrder order) {
    if (!BackofficeDestination.assignments.visibleFor(widget.user)) return;
    setState(() {
      _assignmentFocusOrder = order;
      _destination = BackofficeDestination.assignments;
    });
  }

  void _openRefundsForReference(String orderReference) {
    if (!BackofficeDestination.refunds.visibleFor(widget.user)) return;
    setState(() {
      _refundFocusOrderReference = orderReference.trim();
      _supportFocusOrderReference = null;
      _destination = BackofficeDestination.refunds;
    });
  }

  void _openSupportForReference(String orderReference) {
    if (!BackofficeDestination.customerRequests.visibleFor(widget.user)) return;
    setState(() {
      _supportFocusOrderReference = orderReference.trim();
      _refundFocusOrderReference = null;
      _destination = BackofficeDestination.customerRequests;
    });
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
    final OrderHistoryRepository? historyRepository = _historyRepository;
    switch (destination) {
      case BackofficeDestination.dashboard:
        return BackofficeDashboardPage(
          user: widget.user,
          snapshot: _dashboardSnapshot,
          onOpenUsers: widget.user.role == UserRole.administrator
              ? () => _selectDestination(BackofficeDestination.users)
              : null,
          onOpenPayments: BackofficeDestination.payments.visibleFor(widget.user)
              ? () => _selectDestination(BackofficeDestination.payments)
              : null,
          onOpenAssignments:
              BackofficeDestination.assignments.visibleFor(widget.user)
              ? () => _selectDestination(BackofficeDestination.assignments)
              : null,
          onOpenFailedOrders:
              BackofficeDestination.failedOrders.visibleFor(widget.user)
              ? () => _selectDestination(BackofficeDestination.failedOrders)
              : null,
          onOpenSupportRequests:
              BackofficeDestination.customerRequests.visibleFor(widget.user)
              ? () => _selectDestination(BackofficeDestination.customerRequests)
              : null,
          onOpenRefunds: BackofficeDestination.refunds.visibleFor(widget.user)
              ? () => _selectDestination(BackofficeDestination.refunds)
              : null,
          onOpenAgentIssues:
              BackofficeDestination.agentIssues.visibleFor(widget.user)
              ? () => _selectDestination(BackofficeDestination.agentIssues)
              : null,
        );
      case BackofficeDestination.orders:
        if (historyRepository == null) {
          return const _BackofficeOperationsUnavailable();
        }
        return BackofficeOrdersPage(
          user: widget.user,
          repository: historyRepository,
          onOpenAssignments: _openAssignmentsFor,
          onOpenPayments: () => _selectDestination(BackofficeDestination.payments),
        );
      case BackofficeDestination.payments:
        return BackofficePaymentsPage(
          user: widget.user,
          ordersRepository: widget.ordersRepository,
          onOpenOrders: () => _selectDestination(BackofficeDestination.orders),
        );
      case BackofficeDestination.assignments:
        return BackofficeAssignmentsPage(
          user: widget.user,
          ordersRepository: widget.ordersRepository,
          agentRepository: widget.agentRepository,
          focusOrderId: _assignmentFocusOrder?.id,
        );
      case BackofficeDestination.failedOrders:
        if (historyRepository == null) {
          return const _BackofficeOperationsUnavailable();
        }
        final RefundRepository? refundRepository = widget.refundRepository;
        if (refundRepository == null) {
          return const _BackofficeModuleUnavailable(
            title: 'Commandes échouées indisponibles',
            message: 'Le traitement des échecs nécessite le repository Remboursements Supabase.',
          );
        }
        return BackofficeFailedOrdersPage(
          user: widget.user,
          ordersRepository: widget.ordersRepository,
          historyRepository: historyRepository,
          refundRepository: refundRepository,
          onOpenAssignments: _openAssignmentsFor,
          onOpenRefunds: _openRefundsForReference,
        );
      case BackofficeDestination.customerRequests:
        final SupportRequestRepository? supportRepository = widget.supportRepository;
        final RefundRepository? refundRepository = widget.refundRepository;
        if (supportRepository == null ||
            refundRepository == null ||
            historyRepository == null) {
          return const _BackofficeModuleUnavailable(
            title: 'Demandes clients indisponibles',
            message:
                'Le workflow Demandes → Remboursements nécessite les repositories Support, Remboursements et Historique commandes.',
          );
        }
        return BackofficeSupportRequestsPage(
          user: widget.user,
          repository: supportRepository,
          refundRepository: refundRepository,
          orderHistoryRepository: historyRepository,
          initialOrderReference: _supportFocusOrderReference,
          onOpenRefunds: _openRefundsForReference,
        );
      case BackofficeDestination.refunds:
        final RefundRepository? refundRepository = widget.refundRepository;
        if (refundRepository == null) {
          return const _BackofficeModuleUnavailable(
            title: 'Remboursements indisponibles',
            message: 'Le repository de remboursement n’est pas configuré dans ce contexte.',
          );
        }
        return BackofficeRefundsPage(
          user: widget.user,
          repository: refundRepository,
          orderHistoryRepository: historyRepository,
          supportRepository: widget.supportRepository,
          initialOrderReference: _refundFocusOrderReference,
          onOpenSupportRequests: _openSupportForReference,
        );
      case BackofficeDestination.agents:
        return BackofficeAgentsPage(
          user: widget.user,
          repository: widget.agentRepository,
        );
      case BackofficeDestination.managers:
        return BackofficeManagersPage(
          user: widget.user,
          territoryRepository: _territoryRepository,
          agentRepository: widget.agentRepository,
        );
      case BackofficeDestination.zones:
        return BackofficeZonesPage(
          user: widget.user,
          agentRepository: widget.agentRepository,
          territoryRepository: _territoryRepository,
        );
      case BackofficeDestination.agentIssues:
        return BackofficeAgentIssuesPage(
          user: widget.user,
          repository: widget.agentRepository,
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
      notifications: _operationalNotifications,
      onNotificationSelected: _selectDestination,
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
        shape: const Border(
          bottom: BorderSide(color: BackofficePalette.line),
        ),
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
          _BackofficeNotificationButton(
            notifications: _operationalNotifications,
            onSelected: _selectDestination,
            compact: true,
          ),
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

class _BackofficeSidebar extends StatefulWidget {
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
  State<_BackofficeSidebar> createState() => _BackofficeSidebarState();
}

class _BackofficeSidebarState extends State<_BackofficeSidebar> {
  _BackofficeSection? _expandedSection;
  final ScrollController _navigationScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final _BackofficeSection section = widget.selected.section;
    _expandedSection = section == _BackofficeSection.overview ? null : section;
  }

  @override
  void didUpdateWidget(covariant _BackofficeSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      final _BackofficeSection section = widget.selected.section;
      if (section != _BackofficeSection.overview && section != _expandedSection) {
        _expandedSection = section;
      }
    }
  }

  @override
  void dispose() {
    _navigationScrollController.dispose();
    super.dispose();
  }

  void _toggleSection(_BackofficeSection section) {
    setState(() {
      _expandedSection = _expandedSection == section ? null : section;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_BackofficeSection> sections = _BackofficeSection.values
        .where(
          (_BackofficeSection section) =>
              section != _BackofficeSection.overview &&
              widget.destinations.any(
                (BackofficeDestination item) => item.section == section,
              ),
        )
        .toList(growable: false);
    final BackofficeDestination? dashboard =
        widget.destinations.contains(BackofficeDestination.dashboard)
            ? BackofficeDestination.dashboard
            : null;

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
                padding: EdgeInsets.fromLTRB(widget.drawerMode ? 18 : 20, 20, 18, 16),
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
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: BackofficePalette.ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.35,
                                ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Back-office',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              widget.user.role == UserRole.administrator
                                  ? 'Espace Administrateur'
                                  : 'Espace Manager',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: BackofficePalette.primaryStrong,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.user.role == UserRole.administrator
                                  ? 'Accès complet'
                                  : 'Supervision opérationnelle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                  controller: _navigationScrollController,
                  child: ListView(
                    controller: _navigationScrollController,
                    primary: false,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 18),
                    children: <Widget>[
                      if (dashboard != null) ...<Widget>[
                        _BackofficeNavTile(
                          destination: dashboard,
                          selected: widget.selected == dashboard,
                          onTap: () => widget.onSelected(dashboard),
                        ),
                        const SizedBox(height: 8),
                      ],
                      for (final _BackofficeSection section in sections) ...<Widget>[
                        _BackofficeSectionMenu(
                          section: section,
                          itemCount: widget.destinations
                              .where((BackofficeDestination item) => item.section == section)
                              .length,
                          expanded: _expandedSection == section,
                          active: widget.selected.section == section,
                          onTap: () => _toggleSection(section),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _expandedSection == section
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(18, 5, 2, 8),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(9, 7, 6, 5),
                                    decoration: BoxDecoration(
                                      color: BackofficePalette.surfaceAlt.withValues(alpha: .72),
                                      border: Border(
                                        left: BorderSide(
                                          color: BackofficePalette.primary.withValues(alpha: .22),
                                          width: 2,
                                        ),
                                      ),
                                      borderRadius: const BorderRadius.horizontal(
                                        right: Radius.circular(12),
                                      ),
                                    ),
                                    child: Column(
                                      children: widget.destinations
                                          .where((BackofficeDestination item) => item.section == section)
                                          .map(
                                            (BackofficeDestination destination) => _BackofficeNavTile(
                                              destination: destination,
                                              selected: destination == widget.selected,
                                              compact: true,
                                              onTap: () => widget.onSelected(destination),
                                            ),
                                          )
                                          .toList(growable: false),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.drawerMode)
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: BackofficePalette.sidebarLine)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: _BackofficeUserMenu(
                    user: widget.user,
                    onLogout: widget.onLogout,
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

class _BackofficeSectionMenu extends StatelessWidget {
  const _BackofficeSectionMenu({
    required this.section,
    required this.itemCount,
    required this.expanded,
    required this.active,
    required this.onTap,
  });

  final _BackofficeSection section;
  final int itemCount;
  final bool expanded;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = active
        ? BackofficePalette.primaryStrong
        : BackofficePalette.ink;
    return Material(
      key: ValueKey<String>('bo-section-${section.name}'),
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: active ? BackofficePalette.primarySoft : Colors.transparent,
          border: Border.all(
            color: active ? const Color(0xFFDCE7FF) : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: InkWell(
          onTap: onTap,
          hoverColor: BackofficePalette.surfaceAlt,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : BackofficePalette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    section.icon,
                    size: 19,
                    color: active
                        ? BackofficePalette.primaryStrong
                        : BackofficePalette.primary,
                    fill: active ? 1 : 0,
                    weight: active ? 650 : 560,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        section.menuLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$itemCount module${itemCount > 1 ? 's' : ''}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: BackofficePalette.faint,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? .5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Icon(
                    Symbols.keyboard_arrow_down_rounded,
                    size: 21,
                    color: active
                        ? BackofficePalette.primaryStrong
                        : BackofficePalette.muted,
                    weight: 650,
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

class _BackofficeNavTile extends StatelessWidget {
  const _BackofficeNavTile({
    required this.destination,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final BackofficeDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        key: ValueKey<String>('bo-nav-${destination.name}'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(compact ? 10 : 13),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: compact && selected ? Colors.white : null,
            gradient: !compact && selected
                ? BackofficeGradients.selectedNav
                : null,
            border: Border.all(
              color: selected
                  ? BackofficePalette.primary.withValues(
                      alpha: compact ? .16 : .20,
                    )
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(compact ? 10 : 13),
          ),
          child: InkWell(
            onTap: onTap,
            hoverColor: compact
                ? Colors.white.withValues(alpha: .72)
                : BackofficePalette.surfaceAlt,
            splashColor: BackofficePalette.primarySoft,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 7 : 10,
                vertical: compact ? 6 : 8,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: compact ? 25 : 32,
                    height: compact ? 25 : 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: compact
                          ? selected
                                ? BackofficePalette.primary.withValues(alpha: .12)
                                : Colors.transparent
                          : selected
                          ? BackofficePalette.primary
                          : BackofficePalette.primarySoft,
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                    ),
                    child: Icon(
                      destination.icon,
                      size: compact ? 16 : 20,
                      color: compact
                          ? selected
                                ? BackofficePalette.primaryStrong
                                : BackofficePalette.muted
                          : selected
                          ? Colors.white
                          : BackofficePalette.primaryStrong,
                      fill: selected ? 1 : 0,
                      weight: selected ? 650 : 520,
                      opticalSize: 22,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 11),
                  Expanded(
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? BackofficePalette.primaryStrong
                            : compact
                            ? BackofficePalette.muted
                            : BackofficePalette.ink,
                        fontSize: compact ? 12.5 : null,
                        fontWeight: selected
                            ? FontWeight.w800
                            : compact
                            ? FontWeight.w600
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: compact ? 3 : 6,
                      height: compact ? 18 : 6,
                      decoration: BoxDecoration(
                        color: BackofficePalette.primary,
                        borderRadius: compact ? BorderRadius.circular(99) : null,
                        shape: compact ? BoxShape.rectangle : BoxShape.circle,
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
    required this.notifications,
    required this.onNotificationSelected,
    required this.onLogout,
    required this.child,
  });

  final BackofficeDestination destination;
  final AppUser user;
  final List<_BackofficeNotificationEntry> notifications;
  final ValueChanged<BackofficeDestination> onNotificationSelected;
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: BackofficePalette.faint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _BackofficeNotificationButton(
                  notifications: notifications,
                  onSelected: onNotificationSelected,
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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


class _BackofficeNotificationEntry {
  const _BackofficeNotificationEntry({
    required this.destination,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
  });

  final BackofficeDestination destination;
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
}

class _BackofficeNotificationButton extends StatelessWidget {
  const _BackofficeNotificationButton({
    required this.notifications,
    required this.onSelected,
    this.compact = false,
  });

  final List<_BackofficeNotificationEntry> notifications;
  final ValueChanged<BackofficeDestination> onSelected;
  final bool compact;

  int get _totalCount => notifications.fold<int>(
        0,
        (int total, _BackofficeNotificationEntry item) => total + item.count,
      );

  @override
  Widget build(BuildContext context) {
    final int count = _totalCount;
    return PopupMenuButton<BackofficeDestination>(
      tooltip: 'Notifications',
      constraints: const BoxConstraints(minWidth: 330, maxWidth: 380),
      offset: const Offset(0, 10),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) {
        return <PopupMenuEntry<BackofficeDestination>>[
          PopupMenuItem<BackofficeDestination>(
            enabled: false,
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BackofficePalette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Symbols.notifications_rounded,
                    color: BackofficePalette.primary,
                    fill: 1,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Notifications opérationnelles',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: BackofficePalette.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        count == 0
                            ? 'Aucune action urgente'
                            : '$count action${count > 1 ? 's' : ''} à traiter',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: BackofficePalette.muted,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          if (notifications.isEmpty)
            const PopupMenuItem<BackofficeDestination>(
              enabled: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Symbols.task_alt_rounded,
                      color: BackofficePalette.success,
                      fill: 1,
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text('Tout est à jour pour le moment.')),
                  ],
                ),
              ),
            )
          else
            for (final _BackofficeNotificationEntry item in notifications)
              PopupMenuItem<BackofficeDestination>(
                value: item.destination,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          item.icon,
                          color: item.color,
                          fill: 1,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item.count}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ];
      },
      child: Container(
        width: compact ? 38 : 42,
        height: compact ? 38 : 42,
        decoration: BoxDecoration(
          color: count > 0
              ? BackofficePalette.primarySoft
              : BackofficePalette.surfaceAlt,
          border: Border.all(
            color: count > 0
                ? const Color(0xFFD6E3FF)
                : BackofficePalette.line,
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Center(
              child: Icon(
                Symbols.notifications_rounded,
                color: BackofficePalette.primaryStrong,
                fill: 1,
                size: 21,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: BackofficePalette.danger,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
          StaffProfileAvatar(
            firebaseUid: user.id,
            displayName: user.name,
            size: compact ? 30 : 36,
          ),
          if (!compact) ...<Widget>[
            const SizedBox(width: 10),
            if (fillWidth)
              Expanded(
                child: _UserIdentityCopy(user: user),
              )
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
        if (value == 'profile') {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => BackofficeMyProfilePage(user: user),
            ),
          );
          return;
        }
        if (value == 'logout') onLogout();
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(user.roleLabel),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: <Widget>[
              Icon(Symbols.person_rounded, size: 20),
              SizedBox(width: 10),
              Text('Mon profil'),
            ],
          ),
        ),
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: BackofficePalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackofficeOperationsUnavailable extends StatelessWidget {
  const _BackofficeOperationsUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: backofficePanelDecoration(),
      child: const Text(
        'Le dépôt de commandes actif ne fournit pas l’historique requis pour cette vue.',
      ),
    );
  }
}

class _BackofficeModuleUnavailable extends StatelessWidget {
  const _BackofficeModuleUnavailable({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return BackofficeEmptyState(
      icon: Symbols.cloud_off_rounded,
      title: title,
      message: message,
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
        Text(destination.label, style: Theme.of(context).textTheme.headlineLarge),
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
                      child: Icon(destination.icon, size: 28, color: Colors.white),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                        ),
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
