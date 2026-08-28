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
    this.onOpenOrders,
  });

  final AppUser user;
  final DashboardRepository dashboardRepository;
  final VoidCallback? onOpenOrders;

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
    _viewModel.startRealtime();
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

    // Pour coller à la maquette "Mercredi 5 août 2026"
    final List<String> days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final String dayName = days[currentDate.weekday - 1];

    return '$dayName ${currentDate.day} $month ${currentDate.year}';
  }

  void _showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  int? _getBalanceForOperator(DashboardData data, ServiceChannel channel) {
    try {
      return data.balances
          .firstWhere((AccountBalance balance) => balance.channel == channel)
          .amount;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        final DashboardData? dashboardData = _viewModel.dashboardData;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                  child: DashboardHeader(
                    user: widget.user,
                    dateLabel: _formatCurrentDate(),
                    onSearchPressed: () {
                      _showTemporaryMessage('Recherche...');
                    },
                    onNotificationsPressed: () {
                      _showTemporaryMessage('Notifications...');
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _viewModel.loadDashboard,
                    color: AppColors.primaryContainer,
                    backgroundColor: AppColors.surfaceContainer,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        10,
                        20,
                        120,
                      ), // Padding augmenté pour ne pas cacher la dernière carte sous le FAB
                      children: [
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
                            const LinearProgressIndicator(
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Activité du jour
                          DailyActivityCard(
                            revenue: dashboardData.todayRevenue,
                            percentageIncrease:
                                dashboardData.revenueChangePercentage,
                          ),
                          const SizedBox(height: 16),

                          // Statut des commandes
                          OrderStatusCard(
                            paidCount: dashboardData.statistics.newRequests,
                            inProgressCount:
                                dashboardData.statistics.inProgress,
                            completedCount: dashboardData.statistics.completed,
                          ),
                          const SizedBox(height: 24),

                          // Disponibilités réseaux
                          const SectionHeader(
                            icon: Icons.sim_card_outlined,
                            title: 'Disponibilités réseaux',
                          ),
                          const SizedBox(height: 16),

                          LayoutBuilder(
                            builder:
                                (
                                  BuildContext context,
                                  BoxConstraints constraints,
                                ) {
                                  final List<Widget> cards = <Widget>[
                                    OperatorBalanceCard(
                                      operatorName: 'Orange',
                                      balance: _getBalanceForOperator(
                                        dashboardData,
                                        ServiceChannel.orange,
                                      ),
                                      logoAsset:
                                          'assets/images/orange_logo.png',
                                      accentColor: const Color(0xFFFF7900),
                                      signalBars: 3,
                                    ),
                                    OperatorBalanceCard(
                                      operatorName: 'MTN',
                                      balance: _getBalanceForOperator(
                                        dashboardData,
                                        ServiceChannel.mtn,
                                      ),
                                      logoAsset: 'assets/images/mtn_logo.png',
                                      accentColor: const Color(0xFFFFCC00),
                                      signalBars: 4,
                                    ),
                                    OperatorBalanceCard(
                                      operatorName: 'Moov Africa',
                                      balance: _getBalanceForOperator(
                                        dashboardData,
                                        ServiceChannel.moov,
                                      ),
                                      logoAsset: 'assets/images/moov_logo.png',
                                      accentColor: const Color(0xFF0055A5),
                                      signalBars: 2,
                                    ),
                                  ];

                                  if (constraints.maxWidth < 380) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (
                                              int index = 0;
                                              index < cards.length;
                                              index++
                                            ) ...[
                                              SizedBox(
                                                width: 146,
                                                child: cards[index],
                                              ),
                                              if (index != cards.length - 1)
                                                const SizedBox(width: 8),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (
                                          int index = 0;
                                          index < cards.length;
                                          index++
                                        ) ...[
                                          Expanded(child: cards[index]),
                                          if (index != cards.length - 1)
                                            const SizedBox(width: 8),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                          ),
                          if (dashboardData.balances.every(
                            (AccountBalance balance) => !balance.isAvailable,
                          )) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'Les soldes seront disponibles après la mise en place du module Réseaux et Finances.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Caisse Wave
                          WaveBalanceCard(
                            balance: _getBalanceForOperator(
                              dashboardData,
                              ServiceChannel.wave,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // À traiter en priorité
                          const SectionHeader(
                            icon: Icons.track_changes_rounded,
                            title: 'À traiter en priorité',
                          ),
                          const SizedBox(height: 16),
                          if (dashboardData.priorityOrders.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Aucune commande en attente',
                                  style: TextStyle(color: Color(0xFF6B7280)),
                                ),
                              ),
                            )
                          else
                            ...dashboardData.priorityOrders.map((order) {
                              return PriorityOrderItemCard(
                                reference: order.reference,
                                phoneNumber: order.phoneNumber,
                                operationLabel: order.operationLabel,
                                amount: order.amount,
                                channel: order.channel.name,
                                statusLabel: order.status.name,
                                actionLabel: order.actionLabel,
                                onPressed: widget.onOpenOrders ?? () {},
                              );
                            }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
