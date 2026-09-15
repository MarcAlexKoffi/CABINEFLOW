import 'package:cabine_flow/core/services/customer_support_whatsapp.dart';
import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';

class CustomerHelpPage extends StatelessWidget {
  const CustomerHelpPage({
    super.key,
    required this.onBack,
    required this.onOpenRecovery,
    required this.onOpenHome,
    required this.onOpenOffers,
    required this.onOpenHistory,
  });

  final VoidCallback onBack;
  final VoidCallback onOpenRecovery;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;

  Future<void> _launchWhatsApp(BuildContext context) async {
    final bool opened = await CustomerSupportWhatsApp.open();
    if (!context.mounted || opened) {
      return;
    }
    IzyTelFeedback.error(
      context,
      'Impossible d’ouvrir WhatsApp pour le moment.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool desktopHeader = MediaQuery.sizeOf(context).width >= 900;

    return IzyTelShell(
      title: 'Aide',
      onBack: onBack,
      maxContentWidth: 1080,
      actions: desktopHeader
          ? <Widget>[
              TextButton(
                onPressed: onOpenHome,
                child: const Text('Accueil'),
              ),
              TextButton(
                onPressed: onOpenOffers,
                child: const Text('Offres'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: TextButton(
                  onPressed: onOpenHistory,
                  child: const Text('Historique'),
                ),
              ),
            ]
          : <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: onOpenHome,
                  child: const Text('Accueil'),
                ),
              ),
            ],
      bottomNavigationBar: desktopHeader
          ? null
          : IzyTelBottomNavigation(
              current: IzyTelCustomerDestination.help,
              onHome: onOpenHome,
              onOffers: onOpenOffers,
              onHistory: onOpenHistory,
              onHelp: () {},
            ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 900;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 32 : 18,
              26,
              desktop ? 32 : 18,
              36,
            ),
            children: [
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: CustomerAppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: CustomerAppColors.primary,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Comment pouvons-nous vous aider ?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Une question sur une commande ou votre paiement ? Retrouvez rapidement le bon point d’entrée.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              if (desktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _HelpCard(
                        leading: Image.asset(
                          'assets/images/whatsapp_logo.png',
                          width: 30,
                          height: 30,
                        ),
                        iconBackground: CustomerAppColors.successContainer,
                        title: 'Contacter sur WhatsApp',
                        description:
                            'Échangez directement avec le service client IzyTel au ${CustomerSupportWhatsApp.displayPhone}.',
                        onTap: () => _launchWhatsApp(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HelpCard(
                        leading: const Icon(
                          Icons.search_rounded,
                          color: CustomerAppColors.primary,
                        ),
                        iconBackground: CustomerAppColors.primaryContainer,
                        title: 'Retrouver ma commande',
                        description:
                            'Retrouvez une commande créée sur un autre téléphone avec sa référence et votre WhatsApp.',
                        onTap: onOpenRecovery,
                      ),
                    ),
                  ],
                )
              else ...[
                _HelpCard(
                  leading: Image.asset(
                    'assets/images/whatsapp_logo.png',
                    width: 30,
                    height: 30,
                  ),
                  iconBackground: CustomerAppColors.successContainer,
                  title: 'Contacter sur WhatsApp',
                  description:
                      'Échangez directement avec le service client IzyTel au ${CustomerSupportWhatsApp.displayPhone}.',
                  onTap: () => _launchWhatsApp(context),
                ),
                const SizedBox(height: 12),
                _HelpCard(
                  leading: const Icon(
                    Icons.search_rounded,
                    color: CustomerAppColors.primary,
                  ),
                  iconBackground: CustomerAppColors.primaryContainer,
                  title: 'Retrouver ma commande',
                  description:
                      'Retrouvez une commande créée sur un autre téléphone avec sa référence et votre WhatsApp.',
                  onTap: onOpenRecovery,
                ),
              ],
              const SizedBox(height: 24),
              IzyTelCard(
                showShadow: false,
                backgroundColor: CustomerAppColors.primarySoft,
                borderColor: CustomerAppColors.primaryContainer,
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: CustomerAppColors.primary,
                      size: 21,
                    ),
                    SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'Pour votre sécurité, ne partagez jamais d’informations sensibles inutiles. La référence de commande permet déjà à notre équipe de retrouver le bon dossier.',
                        style: TextStyle(
                          color: CustomerAppColors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.leading,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final Widget leading;
  final Color iconBackground;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: leading),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.arrow_forward_rounded,
            color: CustomerAppColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
