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
  late Stream<List<CustomerOffer>> _featuredOffers;

  @override
  void initState() {
    super.initState();
    _featuredOffers = _watchFeaturedOffers();
  }

  Stream<List<CustomerOffer>> _watchFeaturedOffers() {
    return widget.offerRepository.watchAllOffers().map(_selectFeaturedOffers);
  }

  Future<void> _refreshOffers() async {
    try {
      await widget.offerRepository.watchAllOffers().first;
    } finally {
      if (mounted) {
        setState(() => _featuredOffers = _watchFeaturedOffers());
      }
    }
  }

  List<CustomerOffer> _selectFeaturedOffers(List<CustomerOffer> source) {
    final List<CustomerOffer> values = source.toList(growable: true);
    values.sort((CustomerOffer a, CustomerOffer b) {
      final int badgeScoreA = a.badgeLabel == null ? 1 : 0;
      final int badgeScoreB = b.badgeLabel == null ? 1 : 0;
      final int badge = badgeScoreA.compareTo(badgeScoreB);
      if (badge != 0) {
        return badge;
      }
      return a.amount.compareTo(b.amount);
    });
    return List<CustomerOffer>.unmodifiable(values.take(3));
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
          ? <Widget>[
              TextButton(
                onPressed: widget.onOpenOffers,
                child: const Text('Offres'),
              ),
              TextButton(
                onPressed: widget.onOpenHistory,
                child: const Text('Historique'),
              ),
              TextButton(
                onPressed: widget.onOpenRecovery,
                child: const Text('Suivre'),
              ),
              TextButton(
                onPressed: widget.onOpenHelp,
                child: const Text('Aide'),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14, left: 4),
                child: FilledButton(
                  onPressed: widget.onStartOrder,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Commander'),
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
      bottomNavigationBar: desktopHeader
          ? null
          : IzyTelBottomNavigation(
              current: IzyTelCustomerDestination.home,
              onHome: () {},
              onOffers: widget.onOpenOffers,
              onHistory: widget.onOpenHistory,
              onHelp: widget.onOpenHelp,
            ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 980;
          return RefreshIndicator(
            onRefresh: _refreshOffers,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
              desktop ? 34 : 18,
              desktop ? 42 : 22,
              desktop ? 34 : 18,
              desktop ? 54 : 38,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _HeroSection(
                  desktop: desktop,
                  onStartOrder: widget.onStartOrder,
                  onOpenOffers: widget.onOpenOffers,
                ),
                SizedBox(height: desktop ? 62 : 42),
                _SectionHeader(
                  eyebrow: 'COMMENCER',
                  title: 'Commandez directement ou choisissez une offre',
                  subtitle:
                      'Le transfert d’unités reste disponible sans choisir d’offre. Pour Internet et les appels, vous pouvez parcourir le catalogue IzyTel.',
                ),
                const SizedBox(height: 18),
                _ServiceGrid(desktop: desktop, onSelect: widget.onStartService),
                SizedBox(height: desktop ? 54 : 42),
                const _SectionHeader(
                  eyebrow: 'RÉSEAUX',
                  title: 'Orange, MTN et Moov. Au même endroit.',
                  subtitle:
                      'Retrouvez vos recharges et forfaits dans une seule expérience IzyTel.',
                ),
                const SizedBox(height: 18),
                _NetworkGrid(desktop: desktop),
                SizedBox(height: desktop ? 54 : 42),
                _SectionHeader(
                  eyebrow: 'OFFRES',
                  title: 'Quelques offres disponibles maintenant',
                  subtitle:
                      'Des offres actives issues directement du catalogue IzyTel.',
                  actionLabel: 'Tout voir',
                  onAction: widget.onOpenOffers,
                ),
                const SizedBox(height: 18),
                _FeaturedOffers(
                  stream: _featuredOffers,
                  desktop: desktop,
                  onChoose: widget.onChooseOffer,
                ),
                SizedBox(height: desktop ? 54 : 42),
                _HowItWorks(desktop: desktop),
                SizedBox(height: desktop ? 34 : 28),
                if (desktop)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: _ControlSection(
                            onOpenRecovery: widget.onOpenRecovery,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _SupportSection(onOpenHelp: widget.onOpenHelp),
                        ),
                      ],
                    ),
                  )
                else ...<Widget>[
                  _ControlSection(onOpenRecovery: widget.onOpenRecovery),
                  const SizedBox(height: 14),
                  _SupportSection(onOpenHelp: widget.onOpenHelp),
                ],
              ],
            ),
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
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: CustomerAppColors.primaryContainer,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: CustomerAppColors.primary.withValues(alpha: 0.10),
            ),
          ),
          child: const Text(
            'IZYTEL WEB  •  CÔTE D’IVOIRE',
            style: TextStyle(
              color: CustomerAppColors.primary,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Rechargez.\nContinuez.',
          textAlign: desktop ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: CustomerAppColors.primaryDeep,
            fontSize: desktop ? 56 : 40,
            height: 0.98,
            letterSpacing: desktop ? -2.0 : -1.25,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Achetez vos unités et forfaits Orange, MTN et Moov depuis votre téléphone, sans créer de compte.',
          textAlign: desktop ? TextAlign.start : TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontSize: desktop ? 17 : 15,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 26),
        if (desktop)
          Row(
            children: <Widget>[
              Expanded(
                child: IzyTelPrimaryButton(
                  text: 'Commander maintenant',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onStartOrder,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: IzyTelSecondaryButton(
                  text: 'Voir les offres',
                  icon: Icons.local_offer_outlined,
                  backgroundColor: CustomerAppColors.cyanAccent,
                  foregroundColor: CustomerAppColors.primaryDeep,
                  onPressed: onOpenOffers,
                ),
              ),
            ],
          )
        else ...<Widget>[
          IzyTelPrimaryButton(
            text: 'Commander maintenant',
            icon: Icons.arrow_forward_rounded,
            onPressed: onStartOrder,
          ),
          const SizedBox(height: 10),
          IzyTelSecondaryButton(
            text: 'Voir les offres',
            icon: Icons.local_offer_outlined,
            backgroundColor: CustomerAppColors.cyanAccent,
            foregroundColor: CustomerAppColors.primaryDeep,
            onPressed: onOpenOffers,
          ),
        ],
        const SizedBox(height: 22),
        Wrap(
          alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
          spacing: 14,
          runSpacing: 10,
          children: const <Widget>[
            _TrustPill(icon: Icons.person_off_outlined, label: 'Sans compte'),
            _TrustPill(
              icon: Icons.shield_outlined,
              label: 'Paiement sécurisé',
            ),
            _TrustPill(
              icon: Icons.track_changes_rounded,
              label: 'Suivi en temps réel',
            ),
          ],
        ),
      ],
    );

    final Widget visual = _IzyTelWebPreview(desktop: desktop);

    if (desktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(flex: 10, child: copy),
          const SizedBox(width: 44),
          Expanded(flex: 9, child: visual),
        ],
      );
    }

    return Column(
      children: <Widget>[
        visual,
        const SizedBox(height: 30),
        copy,
      ],
    );
  }
}

class _IzyTelWebPreview extends StatelessWidget {
  const _IzyTelWebPreview({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: desktop ? 430 : 330,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(desktop ? 34 : 28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFF7FBFF),
            Color(0xFFEAF3FF),
            Color(0xFFF9FCFF),
          ],
        ),
        border: Border.all(color: CustomerAppColors.outlineSoft),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120757C9),
            blurRadius: 38,
            offset: Offset(0, 18),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            right: desktop ? -82 : -62,
            top: desktop ? -74 : -56,
            child: Container(
              width: desktop ? 250 : 190,
              height: desktop ? 250 : 190,
              decoration: BoxDecoration(
                color: CustomerAppColors.cyanAccent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: desktop ? -76 : -54,
            bottom: desktop ? -90 : -64,
            child: Container(
              width: desktop ? 230 : 170,
              height: desktop ? 230 : 170,
              decoration: BoxDecoration(
                color: CustomerAppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.08, 0),
            child: _PhonePreview(desktop: desktop),
          ),
          Positioned(
            left: desktop ? 22 : 14,
            top: desktop ? 26 : 18,
            child: _PreviewFloatLabel(
              icon: Icons.flash_on_rounded,
              label: 'Rapide',
              desktop: desktop,
            ),
          ),
          Positioned(
            right: desktop ? 22 : 14,
            bottom: desktop ? 28 : 18,
            child: _PreviewFloatLabel(
              icon: Icons.verified_user_outlined,
              label: 'Sécurisé',
              desktop: desktop,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhonePreview extends StatelessWidget {
  const _PhonePreview({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final double width = desktop ? 238 : 186;
    final double height = desktop ? 390 : 292;

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(desktop ? 8 : 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(desktop ? 34 : 28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x290A1B34),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(desktop ? 27 : 22),
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              desktop ? 15 : 11,
              desktop ? 14 : 10,
              desktop ? 15 : 11,
              desktop ? 15 : 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: desktop ? 58 : 44,
                    height: desktop ? 6 : 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                SizedBox(height: desktop ? 18 : 12),
                Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: desktop ? 27 : 21,
                      child: Image.asset(
                        'assets/images/izyTel_logo.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'IzyTel',
                      style: TextStyle(
                        color: CustomerAppColors.primaryDeep,
                        fontSize: desktop ? 16 : 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.menu_rounded,
                      size: desktop ? 20 : 16,
                      color: CustomerAppColors.primaryDeep,
                    ),
                  ],
                ),
                SizedBox(height: desktop ? 22 : 15),
                Text(
                  'Vos unités,\nen quelques clics.',
                  style: TextStyle(
                    color: CustomerAppColors.primaryDeep,
                    fontSize: desktop ? 20 : 15.5,
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: desktop ? 8 : 5),
                Text(
                  'Simple. Rapide. Izy.',
                  style: TextStyle(
                    color: CustomerAppColors.muted,
                    fontSize: desktop ? 10.5 : 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: desktop ? 18 : 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (final MobileNetwork network in MobileNetwork.values)
                      IzyTelOperatorLogo(
                        network: network,
                        size: desktop ? 46 : 34,
                        borderRadius: desktop ? 13 : 10,
                      ),
                  ],
                ),
                SizedBox(height: desktop ? 17 : 11),
                Container(
                  padding: EdgeInsets.all(desktop ? 13 : 9),
                  decoration: BoxDecoration(
                    color: CustomerAppColors.primarySoft,
                    borderRadius: BorderRadius.circular(desktop ? 16 : 12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: desktop ? 34 : 26,
                        height: desktop ? 34 : 26,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.flash_on_rounded,
                          color: CustomerAppColors.primary,
                          size: desktop ? 20 : 15,
                        ),
                      ),
                      SizedBox(width: desktop ? 10 : 7),
                      Expanded(
                        child: Text(
                          'Recharge mobile',
                          style: TextStyle(
                            color: CustomerAppColors.onSurface,
                            fontSize: desktop ? 11.5 : 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  height: desktop ? 42 : 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[
                        CustomerAppColors.primary,
                        CustomerAppColors.cyanAccent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    'Commander',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: desktop ? 11.5 : 9,
                      fontWeight: FontWeight.w800,
                    ),
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

class _PreviewFloatLabel extends StatelessWidget {
  const _PreviewFloatLabel({
    required this.icon,
    required this.label,
    required this.desktop,
  });

  final IconData icon;
  final String label;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 11 : 9,
        vertical: desktop ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CustomerAppColors.outlineSoft),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x100A1B34),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: desktop ? 15 : 13,
            color: CustomerAppColors.primary,
          ),
          SizedBox(width: desktop ? 6 : 4),
          Text(
            label,
            style: TextStyle(
              color: CustomerAppColors.primaryDeep,
              fontSize: desktop ? 10.5 : 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
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
    final Widget copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow,
          style: const TextStyle(
            color: CustomerAppColors.primary,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.85,
          ),
        ),
        const SizedBox(height: 7),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 5),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 560;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              copy,
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: copy),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(width: 18),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        );
      },
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
        description: 'Saisissez librement le montant à envoyer, sans choisir de forfait.',
        badge: 'Sans offre',
      ),
      const _ServiceSpec(
        service: CustomerService.internetSubscription,
        icon: Icons.wifi_rounded,
        title: 'Internet',
        description: 'Choisissez un forfait data parmi les offres disponibles.',
        badge: 'Catalogue',
      ),
      const _ServiceSpec(
        service: CustomerService.calls,
        icon: Icons.call_rounded,
        title: 'Appels',
        description: 'Souscrivez facilement à vos forfaits voix et mixtes.',
        badge: 'Catalogue',
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
    required this.badge,
  });
  final CustomerService service;
  final IconData icon;
  final String title;
  final String description;
  final String badge;
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
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        spec.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CustomerAppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        spec.badge,
                        style: const TextStyle(
                          color: CustomerAppColors.primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
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
    required this.stream,
    required this.desktop,
    required this.onChoose,
  });
  final Stream<List<CustomerOffer>> stream;
  final bool desktop;
  final ValueChanged<CustomerOffer> onChoose;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CustomerOffer>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<CustomerOffer>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
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
            '${formatCfa(offer.amount)} CFA',
            style: const TextStyle(
              color: CustomerAppColors.primaryDeep,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => onChoose(offer),
              style: FilledButton.styleFrom(
                backgroundColor: CustomerAppColors.primary,
                foregroundColor: CustomerAppColors.onPrimary,
              ),
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
  const _HowItWorks({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final List<_HowStep> steps = <_HowStep>[
      const _HowStep(
        number: '01',
        icon: Icons.touch_app_outlined,
        title: 'Choisissez',
        description: 'Le service, le réseau et l’offre qui vous conviennent.',
      ),
      const _HowStep(
        number: '02',
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payez',
        description: 'Finalisez votre paiement via le parcours sécurisé.',
      ),
      const _HowStep(
        number: '03',
        icon: Icons.track_changes_rounded,
        title: 'Suivez',
        description: 'Gardez votre référence et suivez la commande en direct.',
      ),
    ];

    return Container(
      padding: EdgeInsets.all(desktop ? 24 : 18),
      decoration: BoxDecoration(
        color: CustomerAppColors.primaryDeep,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x18062B61),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'EN 3 ÉTAPES',
                      style: TextStyle(
                        color: CustomerAppColors.cyanAccent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Simple du début à la fin.',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF8FB8E9),
              ),
            ],
          ),
          SizedBox(height: desktop ? 22 : 18),
          if (desktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < steps.length; index++) ...<Widget>[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: steps[index]),
                ],
              ],
            )
          else
            Column(
              children: <Widget>[
                for (int index = 0; index < steps.length; index++) ...<Widget>[
                  if (index > 0) const SizedBox(height: 10),
                  steps[index],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$number  $title',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFD5E4F7),
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          CircleAvatar(
            radius: 25,
            backgroundColor: CustomerAppColors.successContainer,
            child: Image.asset(
              'assets/images/whatsapp_logo.png',
              width: 28,
              height: 28,
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
