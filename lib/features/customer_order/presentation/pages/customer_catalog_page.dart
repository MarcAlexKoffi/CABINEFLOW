import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_states.dart';
import 'package:flutter/material.dart';

class CustomerCatalogPage extends StatefulWidget {
  const CustomerCatalogPage({
    super.key,
    required this.offerRepository,
    required this.onBack,
    required this.onChooseOffer,
    required this.onStartOrder,
    required this.onOpenHome,
    required this.onOpenHistory,
    required this.onOpenHelp,
  });

  final CustomerOfferRepository offerRepository;
  final VoidCallback onBack;
  final ValueChanged<CustomerOffer> onChooseOffer;
  final VoidCallback onStartOrder;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenHelp;

  @override
  State<CustomerCatalogPage> createState() => _CustomerCatalogPageState();
}

class _CustomerCatalogPageState extends State<CustomerCatalogPage> {
  CustomerOfferType? _typeFilter;
  MobileNetwork? _networkFilter;
  late Future<List<CustomerOffer>> _offersFuture = _loadOffers();

  Future<List<CustomerOffer>> _loadOffers() async {
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
      final int byNetwork = a.network.index.compareTo(b.network.index);
      if (byNetwork != 0) {
        return byNetwork;
      }
      return a.amount.compareTo(b.amount);
    });
    return values;
  }

  List<CustomerOffer> _filtered(List<CustomerOffer> source) {
    return source
        .where((CustomerOffer offer) {
          if (_typeFilter != null && offer.type != _typeFilter) {
            return false;
          }
          if (_networkFilter != null && offer.network != _networkFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  void _retry() {
    setState(() {
      _offersFuture = _loadOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelShell(
      title: 'Forfaits',
      onBack: widget.onBack,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: TextButton(
            onPressed: widget.onStartOrder,
            child: const Text('Commander'),
          ),
        ),
      ],
      bottomNavigationBar: IzyTelBottomNavigation(
        current: IzyTelCustomerDestination.offers,
        onHome: widget.onOpenHome,
        onOffers: () {},
        onHistory: widget.onOpenHistory,
        onHelp: widget.onOpenHelp,
      ),
      child: FutureBuilder<List<CustomerOffer>>(
        future: _offersFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<CustomerOffer>> snapshot,
            ) {
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool desktop = constraints.maxWidth >= 760;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 32 : 18,
                      24,
                      desktop ? 32 : 18,
                      36,
                    ),
                    children: [
                      Text(
                        'Découvrez les offres IzyTel',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Les offres affichées viennent du catalogue actif Firestore. Choisissez celle qui vous convient puis finalisez votre commande.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      _Filters(
                        type: _typeFilter,
                        network: _networkFilter,
                        onTypeChanged: (CustomerOfferType? value) =>
                            setState(() => _typeFilter = value),
                        onNetworkChanged: (MobileNetwork? value) =>
                            setState(() => _networkFilter = value),
                      ),
                      const SizedBox(height: 24),
                      if (snapshot.connectionState != ConnectionState.done)
                        const _CatalogLoading()
                      else if (snapshot.hasError)
                        IzyTelErrorState(
                          message:
                              'Impossible de charger les offres pour le moment.',
                          onRetry: _retry,
                        )
                      else
                        _OffersGrid(
                          offers: _filtered(
                            snapshot.data ?? const <CustomerOffer>[],
                          ),
                          desktop: desktop,
                          onChoose: widget.onChooseOffer,
                        ),
                    ],
                  );
                },
              );
            },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.type,
    required this.network,
    required this.onTypeChanged,
    required this.onNetworkChanged,
  });

  final CustomerOfferType? type;
  final MobileNetwork? network;
  final ValueChanged<CustomerOfferType?> onTypeChanged;
  final ValueChanged<MobileNetwork?> onNetworkChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CustomerAppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'Tous',
              selected: type == null,
              onTap: () => onTypeChanged(null),
            ),
            _FilterChip(
              label: 'Internet',
              selected: type == CustomerOfferType.internet,
              onTap: () => onTypeChanged(CustomerOfferType.internet),
            ),
            _FilterChip(
              label: 'Appels',
              selected: type == CustomerOfferType.calls,
              onTap: () => onTypeChanged(CustomerOfferType.calls),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Réseau',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: CustomerAppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'Tous',
              selected: network == null,
              onTap: () => onNetworkChanged(null),
            ),
            for (final MobileNetwork item in MobileNetwork.values)
              _FilterChip(
                label: item.brandLabel,
                selected: network == item,
                onTap: () => onNetworkChanged(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: CustomerAppColors.primaryContainer,
      side: BorderSide(
        color: selected
            ? CustomerAppColors.primary
            : CustomerAppColors.outlineSoft,
      ),
      labelStyle: TextStyle(
        color: selected
            ? CustomerAppColors.primary
            : CustomerAppColors.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }
}

class _OffersGrid extends StatelessWidget {
  const _OffersGrid({
    required this.offers,
    required this.desktop,
    required this.onChoose,
  });
  final List<CustomerOffer> offers;
  final bool desktop;
  final ValueChanged<CustomerOffer> onChoose;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return const IzyTelEmptyState(
        title: 'Aucune offre pour ces filtres',
        message: 'Essayez un autre réseau ou un autre type de forfait.',
        icon: Icons.local_offer_outlined,
      );
    }

    if (!desktop) {
      return Column(
        children: [
          for (int index = 0; index < offers.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _CatalogOfferCard(
              offer: offers[index],
              onChoose: () => onChoose(offers[index]),
            ),
          ],
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: offers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (BuildContext context, int index) {
        final CustomerOffer offer = offers[index];
        return _CatalogOfferCard(offer: offer, onChoose: () => onChoose(offer));
      },
    );
  }
}

class _CatalogOfferCard extends StatelessWidget {
  const _CatalogOfferCard({required this.offer, required this.onChoose});
  final CustomerOffer offer;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IzyTelOperatorLogo(
                network: offer.network,
                size: 42,
                borderRadius: 11,
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
              if (offer.badgeLabel != null)
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
                    offer.badgeLabel!,
                    style: const TextStyle(
                      color: CustomerAppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(offer.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 9),
          ...offer.details
              .take(4)
              .map(
                (String detail) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: CustomerAppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          detail,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 14),
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
            child: FilledButton(
              onPressed: onChoose,
              child: const Text('Choisir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogLoading extends StatelessWidget {
  const _CatalogLoading();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (int index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: IzyTelSkeleton(width: double.infinity, height: 170),
        ),
      ),
    );
  }
}
