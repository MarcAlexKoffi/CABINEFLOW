import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_inputs.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerOfferPage extends StatefulWidget {
  const CustomerOfferPage({
    super.key,
    required this.viewModel,
    required this.offerRepository,
  });

  final CustomerOrderViewModel viewModel;
  final CustomerOfferRepository offerRepository;

  @override
  State<CustomerOfferPage> createState() {
    return _CustomerOfferPageState();
  }
}

class _CustomerOfferPageState extends State<CustomerOfferPage> {
  final GlobalKey<FormState> _transferFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _customOfferFormKey = GlobalKey<FormState>();

  late final TextEditingController _transferAmountController;
  late final TextEditingController _customOfferLabelController;
  late final TextEditingController _customOfferAmountController;
  late final Future<List<CustomerOffer>> _offersFuture;

  CustomerService get _service => widget.viewModel.draft.service!;
  MobileNetwork get _network => widget.viewModel.draft.network!;

  bool get _isTransfer => _service == CustomerService.unitTransfer;
  bool get _isUsingCustomOffer => widget.viewModel.isUsingCustomOffer;

  @override
  void initState() {
    super.initState();

    final bool usesCustomOffer = widget.viewModel.draft.usesCustomOffer;

    _transferAmountController = TextEditingController(
      text: _isTransfer ? widget.viewModel.draft.amount?.toString() ?? '' : '',
    );

    _customOfferLabelController = TextEditingController(
      text: widget.viewModel.draft.customOfferLabel ?? '',
    );

    _customOfferAmountController = TextEditingController(
      text: usesCustomOffer
          ? widget.viewModel.draft.amount?.toString() ?? ''
          : '',
    );

    _offersFuture = _isTransfer
        ? Future<List<CustomerOffer>>.value(const <CustomerOffer>[])
        : widget.offerRepository.fetchOffers(
            service: _service,
            network: _network,
          );
  }

  @override
  void dispose() {
    _transferAmountController.dispose();
    _customOfferLabelController.dispose();
    _customOfferAmountController.dispose();
    super.dispose();
  }

  String get _pageTitle {
    switch (_service) {
      case CustomerService.unitTransfer:
        return 'Saisissez le montant';
      case CustomerService.internetSubscription:
        return 'Choisissez votre forfait';
      case CustomerService.calls:
        return 'Choisissez votre forfait';
    }
  }

  String get _pageSubtitle {
    switch (_service) {
      case CustomerService.unitTransfer:
        return 'Indiquez le montant d’unités à transférer.';
      case CustomerService.internetSubscription:
        return 'Sélectionnez un forfait ${_networkLabel(_network)} ou renseignez votre propre offre.';
      case CustomerService.calls:
        return 'Sélectionnez un forfait ${_networkLabel(_network)} ou renseignez votre propre offre.';
    }
  }

  String get _customOfferHint {
    switch (_service) {
      case CustomerService.internetSubscription:
        return 'Ex. Pass Internet 3 Go, validité 7 jours';
      case CustomerService.calls:
        return 'Ex. Pack 200 min tous réseaux, validité 15 jours';
      case CustomerService.unitTransfer:
        return '';
    }
  }

  String get _recommendedOffersTitle {
    switch (_service) {
      case CustomerService.internetSubscription:
        return 'Forfaits Internet recommandés';
      case CustomerService.calls:
        return 'Forfaits appels recommandés';
      case CustomerService.unitTransfer:
        return '';
    }
  }

  String _networkLabel(MobileNetwork network) {
    switch (network) {
      case MobileNetwork.orange:
        return 'Orange';
      case MobileNetwork.mtn:
        return 'MTN';
      case MobileNetwork.moov:
        return 'Moov Africa';
    }
  }

  String? _validateTransferAmount(String? value) {
    final String rawValue = value?.trim() ?? '';

    if (rawValue.isEmpty) {
      return 'Saisissez le montant à transférer.';
    }

    final int? amount = int.tryParse(rawValue);

    if (amount == null || amount <= 0) {
      return 'Saisissez un montant supérieur à zéro.';
    }

    return null;
  }

  String? _validateCustomOfferLabel(String? value) {
    final String label = value?.trim() ?? '';

    if (label.isEmpty) {
      return 'Décrivez le forfait souhaité.';
    }

    if (label.length < 3) {
      return 'Ajoutez un peu plus de détails sur le forfait.';
    }

    return null;
  }

  String? _validateCustomOfferAmount(String? value) {
    final String rawValue = value?.trim() ?? '';

    if (rawValue.isEmpty) {
      return 'Saisissez le prix exact du forfait.';
    }

    final int? amount = int.tryParse(rawValue);

    if (amount == null || amount <= 0) {
      return 'Saisissez un montant supérieur à zéro.';
    }

    return null;
  }

  int? _positiveAmountFrom(String value) {
    final int? amount = int.tryParse(value.trim());
    return amount != null && amount > 0 ? amount : null;
  }

  void _updateTransferAmount(String value) {
    widget.viewModel.setTransferAmount(_positiveAmountFrom(value));
  }

  void _selectCustomOffer() {
    widget.viewModel.useCustomOffer(
      label: _customOfferLabelController.text,
      amount: _positiveAmountFrom(_customOfferAmountController.text),
    );
  }

  void _updateCustomOffer() {
    if (!_isUsingCustomOffer) {
      return;
    }

    widget.viewModel.updateCustomOffer(
      label: _customOfferLabelController.text,
      amount: _positiveAmountFrom(_customOfferAmountController.text),
    );
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_isTransfer) {
      final bool isValid = _transferFormKey.currentState?.validate() ?? false;

      if (!isValid) {
        return;
      }

      widget.viewModel.setTransferAmount(
        int.parse(_transferAmountController.text.trim()),
      );
    } else if (_isUsingCustomOffer) {
      final bool isValid =
          _customOfferFormKey.currentState?.validate() ?? false;

      if (!isValid) {
        return;
      }

      widget.viewModel.updateCustomOffer(
        label: _customOfferLabelController.text.trim(),
        amount: int.parse(_customOfferAmountController.text.trim()),
      );
    }

    widget.viewModel.continueFromOffer();
  }

  @override
  Widget build(BuildContext context) {
    return CustomerFlowScaffold(
      currentStep: 4,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: _pageTitle,
      subtitle: _pageSubtitle,
      onTopBack: widget.viewModel.goBack,
      onBottomBack: widget.viewModel.goBack,
      onContinue: _continue,
      isContinueEnabled: widget.viewModel.canContinueFromOffer,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelectionContextCard(service: _service, network: _network),
          const SizedBox(height: 24),
          if (_isTransfer)
            _buildTransferAmountForm()
          else
            _buildSubscriptionSelection(),
        ],
      ),
    );
  }

  Widget _buildTransferAmountForm() {
    return Form(
      key: _transferFormKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: IzyTelCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Montant à transférer',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            IzyTelTextInput(
              controller: _transferAmountController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              hintText: 'Ex. 1500',
              prefixIcon: Icons.payments_outlined,
              suffixText: 'F CFA',
              validator: _validateTransferAmount,
              onChanged: _updateTransferAmount,
              onFieldSubmitted: (_) {
                _continue();
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Le montant saisi sera repris dans le récapitulatif avant paiement.',
              style: TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _recommendedOffersTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        Text(
          'Des offres ${_network.brandLabel} disponibles actuellement.',
          style: const TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        _buildOfferList(),
        const SizedBox(height: 30),
        Text(
          'Vous ne trouvez pas votre forfait ?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        const Text(
          'Renseignez manuellement une offre uniquement si elle n’apparaît pas dans le catalogue.',
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        _buildCustomOfferCard(),
      ],
    );
  }

  Widget _buildCustomOfferCard() {
    final bool isSelected = _isUsingCustomOffer;

    return IzyTelCard(
      isSelected: isSelected,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: _selectCustomOffer,
              borderRadius: BorderRadius.circular(15),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: CustomerAppColors.primary.withValues(
                          alpha: 0.10,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: CustomerAppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Forfait personnalisé',
                            style: TextStyle(
                              color: CustomerAppColors.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Je ne trouve pas mon forfait dans la liste.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? CustomerAppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? CustomerAppColors.primary
                              : CustomerAppColors.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: CustomerAppColors.onPrimary,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isSelected) ...[
            Divider(
              height: 1,
              color: CustomerAppColors.primary.withValues(alpha: 0.18),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Form(
                key: _customOfferFormKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nom ou détails du forfait',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    IzyTelTextInput(
                      controller: _customOfferLabelController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      hintText: _customOfferHint,
                      prefixIcon: Icons.description_outlined,
                      validator: _validateCustomOfferLabel,
                      onChanged: (_) {
                        _updateCustomOffer();
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Prix exact du forfait',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    IzyTelTextInput(
                      controller: _customOfferAmountController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      hintText: 'Ex. 1500',
                      prefixIcon: Icons.payments_outlined,
                      suffixText: 'F CFA',
                      validator: _validateCustomOfferAmount,
                      onChanged: (_) {
                        _updateCustomOffer();
                      },
                      onFieldSubmitted: (_) {
                        _continue();
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CustomerAppColors.primary.withValues(
                          alpha: 0.06,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: CustomerAppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Renseignez le nom du forfait et son prix exact. Vérifiez ces informations avant de continuer.',
                              style: TextStyle(
                                color: CustomerAppColors.onSurfaceVariant,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOfferList() {
    return FutureBuilder<List<CustomerOffer>>(
      future: _offersFuture,
      builder: (BuildContext context, AsyncSnapshot<List<CustomerOffer>> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const _OfferLoadMessage(
            icon: Icons.cloud_off_outlined,
            message: 'Impossible de charger les offres pour le moment.',
          );
        }

        final List<CustomerOffer> offers =
            snapshot.data ?? const <CustomerOffer>[];

        if (offers.isEmpty) {
          return const _OfferLoadMessage(
            icon: Icons.inventory_2_outlined,
            message:
                'Aucune offre recommandée n’est disponible pour cette sélection.',
          );
        }

        return Column(
          children: offers.map((CustomerOffer offer) {
            return Padding(
              padding: EdgeInsets.only(bottom: offer == offers.last ? 0 : 16),
              child: _OfferOptionCard(
                offer: offer,
                isSelected:
                    widget.viewModel.draft.offer?.id == offer.id &&
                    !_isUsingCustomOffer,
                onTap: () {
                  widget.viewModel.selectOffer(offer);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SelectionContextCard extends StatelessWidget {
  const _SelectionContextCard({required this.service, required this.network});

  final CustomerService service;
  final MobileNetwork network;

  String get networkLabel {
    switch (network) {
      case MobileNetwork.orange:
        return 'Orange';
      case MobileNetwork.mtn:
        return 'MTN';
      case MobileNetwork.moov:
        return 'Moov Africa';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: CustomerAppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CustomerAppColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          IzyTelOperatorLogo(network: network, size: 34, borderRadius: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${service.label} • $networkLabel',
              style: const TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferOptionCard extends StatelessWidget {
  const _OfferOptionCard({
    required this.offer,
    required this.isSelected,
    required this.onTap,
  });

  final CustomerOffer offer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${offer.catalogLabel}, ${formatCfa(offer.amount)} CFA',
      child: IzyTelCard(
        isSelected: isSelected,
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IzyTelOperatorLogo(
                        network: offer.network,
                        size: 30,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        offer.network.brandLabel,
                        style: TextStyle(
                          color: offer.network.brandColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (offer.badgeLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CustomerAppColors.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        offer.badgeLabel!,
                        style: const TextStyle(
                          color: CustomerAppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                  ],
                  Text(
                    offer.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 9),
                  ...offer.details.map((String detail) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Icon(
                              Icons.circle,
                              size: 5,
                              color: CustomerAppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              detail,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 9),
                  Text(
                    '${formatCfa(offer.amount)} CFA',
                    style: const TextStyle(
                      color: CustomerAppColors.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? CustomerAppColors.primary
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? CustomerAppColors.primary
                      : CustomerAppColors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: CustomerAppColors.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferLoadMessage extends StatelessWidget {
  const _OfferLoadMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: CustomerAppColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
