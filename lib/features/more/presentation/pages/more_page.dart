import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_management_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/offers/domain/repositories/admin_offer_repository.dart';
import 'package:cabine_flow/features/offers/presentation/pages/offer_management_page.dart';
import 'package:cabine_flow/features/orders/domain/repositories/order_history_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/data/repositories/firestore_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/repositories/refund_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/data/repositories/firestore_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:cabine_flow/features/support/domain/repositories/support_request_repository.dart';
import 'package:cabine_flow/features/support/presentation/pages/support_request_center_page.dart';
import 'package:cabine_flow/shared/widgets/feature_placeholder_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.user,
    required this.authRepository,
    required this.adminOfferRepository,
    required this.agentRepository,
    required this.ordersRepository,
  });

  final AppUser user;
  final AuthRepository authRepository;
  final AdminOfferRepository adminOfferRepository;
  final AgentRepository agentRepository;
  final OrdersRepository ordersRepository;

  Future<void> _logout(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerHighest,
          title: const Text('Se déconnecter ?'),
          content: const Text(
            'Tu devras te reconnecter pour accéder de nouveau à l’espace Administration.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Se déconnecter'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await authRepository.logout();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> route) => false,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Impossible de se déconnecter pour le moment.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user.role != UserRole.administrator) {
      return const FeaturePlaceholderPage(
        title: 'Plus',
        description: 'Accède aux autres fonctions de IzyTel.',
        message:
            'Le profil, les paramètres et les fonctions autorisées pour ton rôle seront placés ici.',
        icon: Icons.apps_rounded,
      );
    }

    final SupportRequestRepository supportRepository = Firebase.apps.isNotEmpty
        ? FirestoreSupportRequestRepository()
        : FakeSupportRequestRepository();
    final RefundRepository refundRepository = Firebase.apps.isNotEmpty
        ? FirestoreRefundRepository()
        : FakeRefundRepository();
    final OrderHistoryRepository? historyRepository =
        ordersRepository is OrderHistoryRepository
        ? ordersRepository as OrderHistoryRepository
        : null;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Administration',
                      style: TextStyle(
                        color: AppColors.onBackground,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Connecté en tant que ${user.name}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withAlpha(35),
                child: Text(
                  _initial(user.name),
                  style: const TextStyle(
                    color: AppColors.primaryContainer,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<List<SupportRequest>>(
            stream: supportRepository.watchAllRequests(),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<SupportRequest>> snapshot,
                ) {
                  final List<SupportRequest> requests =
                      snapshot.data ?? const <SupportRequest>[];
                  final int activeCount = requests
                      .where((SupportRequest request) => request.isActive)
                      .length;
                  return _AdminFeatureCard(
                    icon: Icons.support_agent_rounded,
                    title: 'Demandes clients',
                    description:
                        'Traiter les vérifications, répondre au client et conserver tout l’historique.',
                    enabled: historyRepository != null,
                    badgeCount: activeCount,
                    onTap: historyRepository == null
                        ? null
                        : () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) {
                                  return SupportRequestCenterPage(
                                    user: user,
                                    repository: supportRepository,
                                    refundRepository: refundRepository,
                                    orderHistoryRepository: historyRepository,
                                  );
                                },
                              ),
                            );
                          },
                  );
                },
          ),
          const SizedBox(height: 12),
          // Remboursements et commissions ont été déplacés dans l’onglet Finances.
          _AdminFeatureCard(
            icon: Icons.local_offer_rounded,
            title: 'Gestion des offres',
            description:
                'Créer, modifier, tarifer, suspendre ou réactiver les offres proposées aux clients.',
            enabled: true,
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
          const SizedBox(height: 12),
          _AdminFeatureCard(
            icon: Icons.groups_2_outlined,
            title: 'Agents et zones',
            description:
                'Disponibilités, réseaux, zones, capacités et signalements opérationnels.',
            enabled: true,
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
          const SizedBox(height: 12),
          const _AdminFeatureCard(
            icon: Icons.rule_folder_outlined,
            title: 'Supervision et incidents',
            description:
                'Anomalies, alertes opérationnelles et contrôles d’audit.',
          ),
          const SizedBox(height: 22),
          _AdminLogoutCard(onTap: () => _logout(context)),
        ],
      ),
    );
  }
}

class _AdminLogoutCard extends StatelessWidget {
  const _AdminLogoutCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withAlpha(90)),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, color: AppColors.error),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Se déconnecter',
                      style: TextStyle(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Fermer la session Administration sur cet appareil.',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.error),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminFeatureCard extends StatelessWidget {
  const _AdminFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    this.enabled = false,
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled
                  ? AppColors.primary.withAlpha(90)
                  : AppColors.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppColors.primary.withAlpha(35)
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.onBackground,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (badgeCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else if (!enabled)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Bientôt',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryContainer,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _initial(String value) {
  final String cleaned = value.trim();
  return cleaned.isEmpty ? '?' : cleaned.substring(0, 1).toUpperCase();
}
