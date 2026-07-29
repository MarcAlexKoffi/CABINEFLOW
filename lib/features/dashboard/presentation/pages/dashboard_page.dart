import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/dashboard/domain/models/dashboard_data.dart';
import 'package:cabine_flow/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:cabine_flow/features/dashboard/presentation/view_models/dashboard_view_model.dart';
import 'package:cabine_flow/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.dashboardRepository,
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;

  @override
  State<DashboardPage> createState() {
    return _DashboardPageState();
  }
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = DashboardViewModel(
      dashboardRepository: widget.dashboardRepository,
    );

    _viewModel.loadDashboard();
  }

  @override
  void dispose() {
    _viewModel.dispose();

    super.dispose();
  }

  String _formatCurrentDate() {
    const List<String> months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];

    final DateTime currentDate = DateTime.now();
    final String month = months[currentDate.month - 1];

    return '${currentDate.day} $month ${currentDate.year}';
  }

  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openOrder(PriorityOrder order) {
    _showTemporaryMessage(
      'Ouverture prochaine de la commande ${order.reference}.',
    );
  }

  void _onNavigationSelected(int index) {
    if (index == 0) {
      return;
    }

    const List<String> pageNames = [
      'Accueil',
      'Commandes',
      'Paiements',
      'Finances',
      'Plus',
    ];

    _showTemporaryMessage(
      'La page ${pageNames[index]} sera construite prochainement.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final DashboardData? dashboardData = _viewModel.dashboardData;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: 'Créer une commande',
            onPressed: () {
              _showTemporaryMessage(
                'Le formulaire de création sera ajouté prochainement.',
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.add_rounded, size: 30),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: _onNavigationSelected,
            backgroundColor: AppColors.surfaceContainer,
            indicatorColor: AppColors.primaryContainer.withAlpha(35),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Accueil',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Commandes',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Paiements',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Finances',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                label: 'Plus',
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _viewModel.loadDashboard,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                children: [
                  DashboardHeader(
                    user: widget.user,
                    dateLabel: _formatCurrentDate(),
                    onSearchPressed: () {
                      _showTemporaryMessage(
                        'La recherche sera ajoutée prochainement.',
                      );
                    },
                    onNotificationsPressed: () {
                      _showTemporaryMessage(
                        'L’écran des notifications sera ajouté prochainement.',
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  if (_viewModel.isLoading && dashboardData == null)
                    const _DashboardLoadingState()
                  else if (_viewModel.errorMessage != null &&
                      dashboardData == null)
                    _DashboardErrorState(
                      message: _viewModel.errorMessage!,
                      onRetry: _viewModel.loadDashboard,
                    )
                  else if (dashboardData != null) ...[
                    if (_viewModel.isLoading) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 12),
                    ],
                    QueueOverviewCard(
                      orderCount: dashboardData.ordersToProcess,
                      averageWaitingMinutes:
                          dashboardData.averageWaitingMinutes,
                      onOpenQueue: () {
                        _showTemporaryMessage(
                          'La file d’attente sera notre prochain écran métier.',
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 9,
                      mainAxisSpacing: 9,
                      childAspectRatio: 1.35,
                      children: [
                        DashboardStatisticCard(
                          value: dashboardData.statistics.newRequests,
                          label: 'Nouvelles demandes',
                          icon: Icons.fiber_new_rounded,
                          accentColor: AppColors.error,
                        ),
                        DashboardStatisticCard(
                          value: dashboardData.statistics.paymentsToVerify,
                          label: 'Paiements à vérifier',
                          icon: Icons.fact_check_outlined,
                          accentColor: AppColors.warning,
                        ),
                        DashboardStatisticCard(
                          value: dashboardData.statistics.inProgress,
                          label: 'En cours',
                          icon: Icons.hourglass_top_rounded,
                          accentColor: AppColors.primaryContainer,
                        ),
                        DashboardStatisticCard(
                          value: dashboardData.statistics.completed,
                          label: 'Terminées',
                          icon: Icons.check_circle_outline_rounded,
                          accentColor: AppColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionHeader(
                      title: 'Soldes des caisses',
                      actionLabel: 'Gérer',
                      onActionPressed: () {
                        _showTemporaryMessage(
                          'La gestion des soldes sera ajoutée dans Finances.',
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 125,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: dashboardData.balances.length,
                        separatorBuilder: (BuildContext context, int index) {
                          return const SizedBox(width: 9);
                        },
                        itemBuilder: (BuildContext context, int index) {
                          return BalanceCard(
                            balance: dashboardData.balances[index],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 25),
                    _SectionHeader(
                      title: 'Priorités',
                      actionIcon: Icons.filter_list_rounded,
                      onActionPressed: () {
                        _showTemporaryMessage(
                          'Les filtres seront ajoutés avec la liste des commandes.',
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ...dashboardData.priorityOrders.map((PriorityOrder order) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: PriorityOrderCard(
                          order: order,
                          onPressed: () {
                            _openOrder(order);
                          },
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onActionPressed,
    this.actionLabel,
    this.actionIcon,
  });

  final String title;
  final VoidCallback onActionPressed;
  final String? actionLabel;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onActionPressed, child: Text(actionLabel!))
        else if (actionIcon != null)
          IconButton(
            onPressed: onActionPressed,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHigh,
            ),
            icon: Icon(actionIcon, size: 19),
          ),
      ],
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 350,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
