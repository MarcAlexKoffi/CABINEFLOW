import 'package:cabine_flow/app/app_routes.dart';
import 'package:cabine_flow/core/services/session_preferences.dart';
import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:cabine_flow/features/agents/domain/repositories/agent_repository.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_issue_center_page.dart';
import 'package:cabine_flow/features/agents/presentation/pages/agent_management_page.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';
import 'package:cabine_flow/features/more/presentation/pages/admin_activity_journal_page.dart';
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
import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:firebase_core/firebase_core.dart';
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
    if (user.role != UserRole.administrator) {
      return const FeaturePlaceholderPage(
        title: 'Plus',
        description: 'Accède aux autres fonctions de IzyTel.',
        message:
            'Le profil, les paramètres et les fonctions autorisées pour ton rôle seront placés ici.',
        icon: Symbols.apps_rounded,
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
                              label: 'Agents et zones',
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
                _AdminIdentityCard(user: user),
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
                        title: 'Agents et zones',
                        subtitle:
                            'Disponibilité, capacités, réseaux, zones et incidents agents.',
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

  void _historyUnavailable(BuildContext context) {
    IzyTelFeedback.show(
      context,
      'L’historique n’est pas disponible avec ce dépôt de données.',
      tone: IzyTelFeedbackTone.warning,
    );
  }
}

class _AdminIdentityCard extends StatelessWidget {
  const _AdminIdentityCard({required this.user});

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
