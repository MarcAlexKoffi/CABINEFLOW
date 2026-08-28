import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_buttons.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:flutter/material.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
    required this.offerRepository,
    required this.onStartOrder,
    required this.onStartService,
    required this.onChooseOffer,
    required this.onOpenOffers,
    required this.onOpenHistory,
    required this.onOpenHelp,
    required this.onOpenRecovery,
  });

  final CustomerOfferRepository offerRepository;
  final VoidCallback onStartOrder;
  final ValueChanged<CustomerService> onStartService;
  final ValueChanged<CustomerOffer> onChooseOffer;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenRecovery;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  late final Future<List<CustomerOffer>> _featuredOffers =
      _loadFeaturedOffers();

  Future<List<CustomerOffer>> _loadFeaturedOffers() async {
    final List<List<CustomerOffer>> groups = await Future.wait(
      <Future<List<CustomerOffer>>>[
        for (final MobileNetwork network
            in MobileNetwork.values) ...<Future<List<CustomerOffer>>>[
          widget.offerRepository.fetchOffers(
            service: CustomerService.internetSubscription,
            network: network,
          ),
          widget.offerRepository.fetchOffers(
            service: CustomerService.calls,
            network: network,
          ),
        ],
      ],
    );

    final List<CustomerOffer> values = groups.expand((items) => items).toList();
    values.sort((CustomerOffer a, CustomerOffer b) {
      final int badgeScoreA = a.badgeLabel == null ? 1 : 0;
      final int badgeScoreB = b.badgeLabel == null ? 1 : 0;
      final int badge = badgeScoreA.compareTo(badgeScoreB);
      if (badge != 0) {
        return badge;
      }
      return a.amount.compareTo(b.amount);
    });
    return values.take(3).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bool desktopHeader = MediaQuery.sizeOf(context).width >= 900;

    return IzyTelShell(
      showBackButton: false,
      showMenuButton: !desktopHeader,
      drawer: desktopHeader
          ? null
          : _HomeMobileDrawer(
              onStartOrder: widget.onStartOrder,
              onOpenOffers: widget.onOpenOffers,
              onOpenHistory: widget.onOpenHistory,
              onOpenRecovery: widget.onOpenRecovery,
              onOpenHelp: widget.onOpenHelp,
            ),
      actions: desktopHeader
          ? [
              TextButton(
                onPressed: widget.onOpenOffers,
                child: const Text('Offres'),
              ),
              TextButton(
                onPressed: widget.onOpenRecovery,
                child: const Text('Suivre une commande'),
              ),
              TextButton(
                onPressed: widget.onOpenHelp,
                child: const Text('Aide'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton(
                  onPressed: widget.onStartOrder,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Commander maintenant'),
                ),
              ),
            ]
          : [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  onPressed: widget.onStartOrder,
                  child: const Text('Commander'),
                ),
              ),
            ],
      bottomNavigationBar: IzyTelBottomNavigation(
        current: IzyTelCustomerDestination.home,
        onHome: () {},
        onOffers: widget.onOpenOffers,
        onHistory: widget.onOpenHistory,
        onHelp: widget.onOpenHelp,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 820;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              desktop ? 32 : 18,
              desktop ? 34 : 22,
              desktop ? 32 : 18,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(
                  desktop: desktop,
                  onStartOrder: widget.onStartOrder,
                  onOpenOffers: widget.onOpenOffers,
                ),
                const SizedBox(height: 44),
                _SectionHeader(
                  eyebrow: 'SERVICES',
                  title: 'Que voulez-vous faire ?',
                  subtitle:
                      'Choisissez votre besoin. IzyTel vous guide ensuite étape par étape.',
                ),
                const SizedBox(height: 18),
                _ServiceGrid(desktop: desktop, onSelect: widget.onStartService),
                const SizedBox(height: 44),
                const _SectionHeader(
                  eyebrow: 'RÉSEAUX',
                  title: 'Tous vos réseaux au même endroit',
                  subtitle:
                      'Orange, MTN et Moov Africa dans une expérience unique et simple.',
                ),
                const SizedBox(height: 18),
                _NetworkGrid(desktop: desktop),
                const SizedBox(height: 44),
                _SectionHeader(
                  eyebrow: 'CATALOGUE',
                  title: 'Les offres du moment',
                  subtitle:
                      'Quelques forfaits actifs issus de votre catalogue IzyTel.',
                  actionLabel: 'Voir toutes les offres',
                  onAction: widget.onOpenOffers,
                ),
                const SizedBox(height: 18),
                _FeaturedOffers(
                  future: _featuredOffers,
                  desktop: desktop,
                  onChoose: widget.onChooseOffer,
                ),
                const SizedBox(height: 46),
                const _HowItWorks(),
                const SizedBox(height: 46),
                _ControlSection(onOpenRecovery: widget.onOpenRecovery),
                const SizedBox(height: 28),
                _SupportSection(onOpenHelp: widget.onOpenHelp),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.desktop,
    required this.onStartOrder,
    required this.onOpenOffers,
  });

  final bool desktop;
  final VoidCallback onStartOrder;
  final VoidCallback onOpenOffers;

  @override
  Widget build(BuildContext context) {
    final Widget copy = Column(
      crossAxisAlignment: desktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: CustomerAppColors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'SIMPLE • RAPIDE • SUIVI',
            style: TextStyle(
              color: CustomerAppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.55,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Vos forfaits et unités, simplement.',
          textAlign: desktop ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: CustomerAppColors.primaryDeep,
            fontSize: desktop ? 48 : 34,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Internet, appels et transfert d’unités Orange, MTN et Moov, en quelques instants.',
          textAlign: desktop ? TextAlign.start : TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontSize: desktop ? 18 : 15),
        ),
        const SizedBox(height: 24),
        if (desktop)
          Row(
            children: [
              SizedBox(
                width: 210,
                child: IzyTelPrimaryButton(
                  text: 'Faire une commande',
                  onPressed: onStartOrder,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 180,
                child: IzyTelSecondaryButton(
                  text: 'Voir les offres',
                  onPressed: onOpenOffers,
                ),
              ),
            ],
          )
        else ...[
          IzyTelPrimaryButton(
            text: 'Faire une commande',
            onPressed: onStartOrder,
          ),
          const SizedBox(height: 10),
          IzyTelSecondaryButton(
            text: 'Voir les offres',
            onPressed: onOpenOffers,
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
          spacing: 14,
          runSpacing: 9,
          children: const [
            _TrustPill(icon: Icons.no_accounts_outlined, label: 'Aucun compte'),
            _TrustPill(
              icon: Icons.lock_outline_rounded,
              label: 'Paiement sécurisé',
            ),
            _TrustPill(
              icon: Icons.track_changes_rounded,
              label: 'Suivi de commande',
            ),
          ],
        ),
      ],
    );

    final Widget visual = Container(
      constraints: BoxConstraints(maxHeight: desktop ? 390 : 245),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: CustomerAppColors.outlineSoft),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120757C9),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(27),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CustomerAppColors.primarySoft,
                      Colors.white,
                      CustomerAppColors.primaryContainer.withValues(
                        alpha: 0.55,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                'assets/images/splash_illustration.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ],
        ),
      ),
    );

    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 11, child: copy),
          const SizedBox(width: 42),
          Expanded(flex: 9, child: visual),
        ],
      );
    }

    return Column(children: [visual, const SizedBox(height: 28), copy]);
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: CustomerAppColors.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: CustomerAppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.desktop, required this.onSelect});
  final bool desktop;
  final ValueChanged<CustomerService> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<_ServiceSpec> services = [
      const _ServiceSpec(
        service: CustomerService.unitTransfer,
        icon: Icons.swap_horiz_rounded,
        title: 'Transfert d’unités',
        description: 'Envoyez rapidement des unités vers un numéro mobile.',
      ),
      const _ServiceSpec(
        service: CustomerService.internetSubscription,
        icon: Icons.wifi_rounded,
        title: 'Internet',
        description: 'Choisissez un forfait data parmi les offres disponibles.',
      ),
      const _ServiceSpec(
        service: CustomerService.calls,
        icon: Icons.call_rounded,
        title: 'Appels',
        description: 'Souscrivez facilement à vos forfaits voix et mixtes.',
      ),
    ];

    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int index = 0; index < services.length; index++) ...[
            if (index > 0) const SizedBox(width: 14),
            Expanded(
              child: _ServiceHomeCard(
                spec: services[index],
                onTap: () => onSelect(services[index].service),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int index = 0; index < services.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _ServiceHomeCard(
            spec: services[index],
            onTap: () => onSelect(services[index].service),
          ),
        ],
      ],
    );
  }
}

class _ServiceSpec {
  const _ServiceSpec({
    required this.service,
    required this.icon,
    required this.title,
    required this.description,
  });
  final CustomerService service;
  final IconData icon;
  final String title;
  final String description;
}

class _ServiceHomeCard extends StatelessWidget {
  const _ServiceHomeCard({required this.spec, required this.onTap});
  final _ServiceSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: CustomerAppColors.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(spec.icon, color: CustomerAppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  spec.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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

class _NetworkGrid extends StatelessWidget {
  const _NetworkGrid({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = MobileNetwork.values
        .map(
          (MobileNetwork network) => IzyTelCard(
            showShadow: false,
            child: Row(
              children: [
                IzyTelOperatorLogo(network: network, size: 54),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        network.brandLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        network.brandDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();

    if (desktop) {
      return Row(
        children: [
          for (int index = 0; index < cards.length; index++) ...[
            if (index > 0) const SizedBox(width: 14),
            Expanded(child: cards[index]),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int index = 0; index < cards.length; index++) ...[
          if (index > 0) const SizedBox(height: 10),
          cards[index],
        ],
      ],
    );
  }
}

class _FeaturedOffers extends StatelessWidget {
  const _FeaturedOffers({
    required this.future,
    required this.desktop,
    required this.onChoose,
  });
  final Future<List<CustomerOffer>> future;
  final bool desktop;
  final ValueChanged<CustomerOffer> onChoose;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CustomerOffer>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<CustomerOffer>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _OfferLoadingRow(desktop: desktop);
        }
        if (snapshot.hasError ||
            (snapshot.data ?? const <CustomerOffer>[]).isEmpty) {
          return IzyTelCard(
            showShadow: false,
            child: Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: CustomerAppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Le catalogue est momentanément indisponible. Vous pouvez toujours commencer une commande.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }

        final List<CustomerOffer> offers = snapshot.data!;
        if (desktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int index = 0; index < offers.length; index++) ...[
                if (index > 0) const SizedBox(width: 14),
                Expanded(
                  child: _FeaturedOfferCard(
                    offer: offers[index],
                    onChoose: onChoose,
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (int index = 0; index < offers.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              _FeaturedOfferCard(offer: offers[index], onChoose: onChoose),
            ],
          ],
        );
      },
    );
  }
}

class _FeaturedOfferCard extends StatelessWidget {
  const _FeaturedOfferCard({required this.offer, required this.onChoose});
  final CustomerOffer offer;
  final ValueChanged<CustomerOffer> onChoose;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IzyTelOperatorLogo(
                network: offer.network,
                size: 38,
                borderRadius: 10,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.network.brandLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      offer.type == CustomerOfferType.internet
                          ? 'Internet'
                          : 'Appels',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(offer.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final String detail in offer.details.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 16),
          Text(
            '${formatCfa(offer.amount)} F CFA',
            style: const TextStyle(
              color: CustomerAppColors.primaryDeep,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onChoose(offer),
              child: const Text('Choisir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferLoadingRow extends StatelessWidget {
  const _OfferLoadingRow({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return const _LoadingCard();
    }

    return const Row(
      children: [
        Expanded(child: _LoadingCard()),
        SizedBox(width: 12),
        Expanded(child: _LoadingCard()),
        SizedBox(width: 12),
        Expanded(child: _LoadingCard()),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 168,
      child: IzyTelCard(
        showShadow: false,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: CustomerAppColors.primaryDeep,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment ça marche ?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          const _HowStep(
            number: '1',
            title: 'Choisissez',
            description: 'Votre service, votre réseau et votre offre.',
          ),
          _HowConnector(),
          const _HowStep(
            number: '2',
            title: 'Payez',
            description: 'Réglez votre commande avec Wave.',
          ),
          _HowConnector(),
          const _HowStep(
            number: '3',
            title: 'Suivez',
            description: 'Gardez votre référence et suivez chaque étape.',
          ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.title,
    required this.description,
  });
  final String number;
  final String title;
  final String description;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: CustomerAppColors.primaryDeep,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFFD7E5F7),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HowConnector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16),
      child: SizedBox(
        height: 16,
        child: VerticalDivider(color: Color(0xFF6E8DB6), thickness: 1),
      ),
    );
  }
}

class _ControlSection extends StatelessWidget {
  const _ControlSection({required this.onOpenRecovery});
  final VoidCallback onOpenRecovery;
  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      backgroundColor: CustomerAppColors.primarySoft,
      borderColor: CustomerAppColors.primaryContainer,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.track_changes_rounded,
              color: CustomerAppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre commande, toujours sous contrôle.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Référence unique, suivi en temps réel et récupération depuis un autre appareil.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Retrouver une commande',
            onPressed: onOpenRecovery,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: CustomerAppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection({required this.onOpenHelp});
  final VoidCallback onOpenHelp;
  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: CustomerAppColors.successContainer,
            child: Icon(
              Icons.support_agent_rounded,
              color: CustomerAppColors.success,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Besoin d’aide ? On reste disponible.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Une question sur une commande ou un paiement ? Notre support WhatsApp est accessible ici.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onOpenHelp,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: CustomerAppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMobileDrawer extends StatelessWidget {
  const _HomeMobileDrawer({
    required this.onStartOrder,
    required this.onOpenOffers,
    required this.onOpenHistory,
    required this.onOpenRecovery,
    required this.onOpenHelp,
  });

  final VoidCallback onStartOrder;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenRecovery;
  final VoidCallback onOpenHelp;

  void _closeAndRun(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => action());
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double drawerWidth = screenWidth < 360
        ? screenWidth * 0.88
        : screenWidth.clamp(0, 330).toDouble();

    return Drawer(
      width: drawerWidth,
      backgroundColor: CustomerAppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 10, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'IzyTel',
                      style: TextStyle(
                        color: CustomerAppColors.primary,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer le menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.home_rounded,
              label: 'Accueil',
              isSelected: true,
              onTap: () => Navigator.of(context).pop(),
            ),
            _MenuTile(
              icon: Icons.local_offer_outlined,
              label: 'Offres',
              onTap: () => _closeAndRun(context, onOpenOffers),
            ),
            _MenuTile(
              icon: Icons.history_rounded,
              label: 'Historique',
              onTap: () => _closeAndRun(context, onOpenHistory),
            ),
            _MenuTile(
              icon: Icons.search_rounded,
              label: 'Suivre une commande',
              onTap: () => _closeAndRun(context, onOpenRecovery),
            ),
            _MenuTile(
              icon: Icons.support_agent_rounded,
              label: 'Aide',
              onTap: () => _closeAndRun(context, onOpenHelp),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: FilledButton.icon(
                onPressed: () => _closeAndRun(context, onStartOrder),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Faire une commande'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected
            ? CustomerAppColors.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          leading: Icon(
            icon,
            color: isSelected
                ? CustomerAppColors.primary
                : CustomerAppColors.onSurfaceVariant,
          ),
          title: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? CustomerAppColors.primary
                  : CustomerAppColors.onSurface,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
          trailing: isSelected
              ? const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: CustomerAppColors.primary,
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: CustomerAppColors.outline,
                ),
        ),
      ),
    );
  }
}
