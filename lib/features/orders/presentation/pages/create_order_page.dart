import 'package:cabine_flow/core/theme/app_colors.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/domain/models/create_order_request.dart';
import 'package:cabine_flow/features/orders/domain/models/offer_catalog_item.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/offer_catalog_repository.dart';
import 'package:cabine_flow/features/orders/domain/repositories/orders_repository.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/create_order_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateOrderPageResult {
  const CreateOrderPageResult({
    required this.order,
    required this.preparePayment,
  });

  final QueueOrder order;
  final bool preparePayment;
}

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({
    super.key,
    required this.user,
    required this.ordersRepository,
    required this.offerCatalogRepository,
  });

  final AppUser user;
  final OrdersRepository ordersRepository;
  final OfferCatalogRepository offerCatalogRepository;

  @override
  State<CreateOrderPage> createState() {
    return _CreateOrderPageState();
  }
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _clientNameController = TextEditingController();

  final TextEditingController _whatsappController = TextEditingController();

  final TextEditingController _beneficiaryController = TextEditingController();

  final TextEditingController _offerDetailController = TextEditingController();

  final TextEditingController _amountController = TextEditingController();

  final TextEditingController _originalMessageController =
      TextEditingController();

  final TextEditingController _notesController = TextEditingController();

  late final CreateOrderViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = CreateOrderViewModel(
      ordersRepository: widget.ordersRepository,
      offerCatalogRepository: widget.offerCatalogRepository,
    );

    _viewModel.initialize();
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _whatsappController.dispose();
    _beneficiaryController.dispose();
    _offerDetailController.dispose();
    _amountController.dispose();
    _originalMessageController.dispose();
    _notesController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  String? _validateRequiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }

    return null;
  }

  String? _validatePhone(String? value) {
    String digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('225')) {
      digits = digits.substring(3);
    }

    if (digits.length != 10) {
      return 'Saisis un numéro ivoirien valide de 10 chiffres.';
    }

    return null;
  }

  String? _validateAmount(String? value) {
    final int? amount = int.tryParse(value ?? '');

    if (amount == null || amount <= 0) {
      return 'Saisis un montant supérieur à zéro.';
    }

    return null;
  }

  String _operationTypeLabel(OrderOperationType operationType) {
    switch (operationType) {
      case OrderOperationType.internetSubscription:
        return 'Souscription Internet';

      case OrderOperationType.unitTransfer:
        return 'Transfert d’unités';

      case OrderOperationType.callBundle:
        return 'Forfait appels';

      case OrderOperationType.mixedBundle:
        return 'Forfait mixte';

      case OrderOperationType.other:
        return 'Autre opération';
    }
  }

  Future<void> _submit({required bool preparePayment}) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final OrderOperationType? operationType = _viewModel.selectedOperationType;

    if (operationType == null) {
      return;
    }

    final CreateOrderRequest request = CreateOrderRequest(
      clientName: _clientNameController.text,
      clientWhatsappPhone: _whatsappController.text,
      network: _viewModel.selectedNetwork,
      beneficiaryPhone: _beneficiaryController.text,
      operationType: operationType,
      offerLabel: _offerDetailController.text,
      amount: int.parse(_amountController.text),
      originalWhatsappMessage: _originalMessageController.text.trim().isEmpty
          ? null
          : _originalMessageController.text,
      internalNotes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text,
    );

    final QueueOrder? createdOrder = await _viewModel.createOrder(request);

    if (!mounted || createdOrder == null) {
      return;
    }

    Navigator.of(context).pop(
      CreateOrderPageResult(
        order: createdOrder,
        preparePayment: preparePayment,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    IconData? prefixIcon,
    String? suffixText,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.outlineVariant.withAlpha(50)),
    );

    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixText: suffixText,
      filled: true,
      fillColor: AppColors.surfaceContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _CreateOrderTopBar(
                  user: widget.user,
                  onBackPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                Divider(
                  height: 1,
                  color: AppColors.outlineVariant.withAlpha(70),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      children: [
                        _FormSection(
                          title: 'Informations client',
                          children: [
                            const _FormLabel(text: 'Nom du client'),
                            TextFormField(
                              controller: _clientNameController,
                              decoration: _inputDecoration(
                                hintText: 'Ex. Jean Dupont',
                              ),
                              validator: (String? value) {
                                return _validateRequiredText(
                                  value,
                                  'Saisis le nom du client.',
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(text: 'Numéro WhatsApp'),
                            TextFormField(
                              controller: _whatsappController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9 +]'),
                                ),
                              ],
                              decoration: _inputDecoration(
                                hintText: '+225 00 00 00 00 00',
                                prefixIcon: Icons.chat_outlined,
                              ),
                              validator: _validatePhone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _FormSection(
                          title: 'Détails de l’opération',
                          children: [
                            const _FormLabel(text: 'Réseau'),
                            Row(
                              children: MobileNetwork.values.map((
                                MobileNetwork network,
                              ) {
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: network != MobileNetwork.moov
                                          ? 8
                                          : 0,
                                    ),
                                    child: _NetworkButton(
                                      network: network,
                                      isSelected:
                                          _viewModel.selectedNetwork == network,
                                      onPressed: () {
                                        _viewModel.selectNetwork(network);
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(text: 'Numéro bénéficiaire'),
                            TextFormField(
                              controller: _beneficiaryController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9 +]'),
                                ),
                              ],
                              decoration: _inputDecoration(
                                hintText: '00 00 00 00 00',
                                prefixIcon: Icons.phone_android_rounded,
                              ),
                              validator: _validatePhone,
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(text: 'Type d’opération'),
                            DropdownButtonFormField<OrderOperationType>(
                              initialValue: _viewModel.selectedOperationType,
                              dropdownColor: AppColors.surfaceContainer,
                              decoration: _inputDecoration(
                                hintText: 'Sélectionner...',
                              ),
                              items: OrderOperationType.values.map((
                                OrderOperationType type,
                              ) {
                                return DropdownMenuItem<OrderOperationType>(
                                  value: type,
                                  child: Text(_operationTypeLabel(type)),
                                );
                              }).toList(),
                              onChanged: _viewModel.selectOperationType,
                              validator: (OrderOperationType? value) {
                                if (value == null) {
                                  return 'Sélectionne le type d’opération.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(text: 'Offre proposée'),
                            DropdownButtonFormField<String>(
                              initialValue: _viewModel.selectedOfferId,
                              dropdownColor: AppColors.surfaceContainer,
                              decoration: _inputDecoration(
                                hintText: _viewModel.isLoadingOffers
                                    ? 'Chargement...'
                                    : 'Sélectionner une offre',
                              ),
                              items: _viewModel.availableOffers.map((
                                OfferCatalogItem offer,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: offer.id,
                                  child: Text(
                                    offer.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged:
                                  _viewModel.selectedOperationType == null
                                  ? null
                                  : (String? offerId) {
                                      _viewModel.selectOffer(offerId);

                                      final OfferCatalogItem? offer =
                                          _viewModel.selectedOffer;

                                      if (offer != null && !offer.isCustom) {
                                        _offerDetailController.text =
                                            offer.label;

                                        final int? amount =
                                            offer.suggestedAmount;

                                        if (amount != null) {
                                          _amountController.text = amount
                                              .toString();
                                        }
                                      } else {
                                        _offerDetailController.clear();
                                      }
                                    },
                              validator: (String? value) {
                                if (value == null) {
                                  return 'Sélectionne une offre.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(text: 'Détail exact de l’offre'),
                            TextFormField(
                              controller: _offerDetailController,
                              decoration: _inputDecoration(
                                hintText: 'Ex. Pass Internet 5 Go — 30 jours',
                              ),
                              validator: (String? value) {
                                return _validateRequiredText(
                                  value,
                                  'Précise l’offre demandée.',
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(text: 'Montant'),
                            TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              textAlign: TextAlign.right,
                              decoration: _inputDecoration(
                                hintText: '0',
                                suffixText: 'FCFA',
                              ),
                              validator: _validateAmount,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _FormSection(
                          title: 'Contexte et notes',
                          children: [
                            const _FormLabel(text: 'Message WhatsApp original'),
                            TextFormField(
                              controller: _originalMessageController,
                              minLines: 3,
                              maxLines: 6,
                              decoration: _inputDecoration(
                                hintText: 'Colle le message original ici...',
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _FormLabel(
                              text: 'Observations / notes internes',
                            ),
                            TextFormField(
                              controller: _notesController,
                              minLines: 2,
                              maxLines: 5,
                              decoration: _inputDecoration(
                                hintText:
                                    'Informations supplémentaires pertinentes...',
                              ),
                            ),
                          ],
                        ),
                        if (_viewModel.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer.withAlpha(60),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _viewModel.errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _viewModel.isSubmitting
                              ? null
                              : () {
                                  _submit(preparePayment: false);
                                },
                          style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.save_rounded),
                          label: const Text('Enregistrer la commande'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _viewModel.isSubmitting
                              ? null
                              : () {
                                  _submit(preparePayment: true);
                                },
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text(
                            'Enregistrer et préparer le paiement',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _viewModel.isSubmitting
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Annuler'),
                        ),
                        if (_viewModel.isSubmitting) ...[
                          const SizedBox(height: 14),
                          const Center(child: CircularProgressIndicator()),
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

class _CreateOrderTopBar extends StatelessWidget {
  const _CreateOrderTopBar({required this.user, required this.onBackPressed});

  final AppUser user;
  final VoidCallback onBackPressed;

  String get initial {
    final String name = user.name.trim();

    if (name.isEmpty) {
      return '?';
    }

    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBackPressed,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              'Nouvelle commande',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(40),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NetworkButton extends StatelessWidget {
  const _NetworkButton({
    required this.network,
    required this.isSelected,
    required this.onPressed,
  });

  final MobileNetwork network;
  final bool isSelected;
  final VoidCallback onPressed;

  String get label {
    switch (network) {
      case MobileNetwork.orange:
        return 'Orange';

      case MobileNetwork.mtn:
        return 'MTN';

      case MobileNetwork.moov:
        return 'Moov';
    }
  }

  Color get color {
    switch (network) {
      case MobileNetwork.orange:
        return AppColors.orange;

      case MobileNetwork.mtn:
        return AppColors.mtn;

      case MobileNetwork.moov:
        return AppColors.moov;
    }
  }

  String get assetPath {
    switch (network) {
      case MobileNetwork.orange:
        return 'assets/images/orange_logo.png';
      case MobileNetwork.mtn:
        return 'assets/images/mtn_logo.png';
      case MobileNetwork.moov:
        return 'assets/images/moov_logo.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? color.withAlpha(25)
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? color
                  : AppColors.outlineVariant.withAlpha(50),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Image.asset(assetPath, fit: BoxFit.cover),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? color : AppColors.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
