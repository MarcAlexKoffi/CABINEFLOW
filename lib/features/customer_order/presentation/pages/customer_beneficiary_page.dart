import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_inputs.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerBeneficiaryPage extends StatefulWidget {
  const CustomerBeneficiaryPage({
    super.key,
    required this.viewModel,
    this.onBack,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback? onBack;

  @override
  State<CustomerBeneficiaryPage> createState() =>
      _CustomerBeneficiaryPageState();
}

class _CustomerBeneficiaryPageState extends State<CustomerBeneficiaryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _beneficiaryController;

  bool _requiresPortabilityConfirmation = false;
  bool _isPortabilityConfirmed = false;

  @override
  void initState() {
    super.initState();
    _beneficiaryController = TextEditingController(
      text: widget.viewModel.draft.beneficiaryNumber?.displayValue ?? '',
    );
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    super.dispose();
  }

  String? _validateBeneficiary(String? value) {
    return BeneficiaryPhoneNumber.validate(
      value,
      emptyMessage: 'Saisissez le numéro bénéficiaire.',
    );
  }

  void _onPhoneChanged(String _) {
    setState(() {
      _requiresPortabilityConfirmation = false;
      _isPortabilityConfirmed = false;
    });
  }

  void _selectSuggestion(BeneficiaryPhoneNumber beneficiary) {
    FocusManager.instance.primaryFocus?.unfocus();
    _beneficiaryController.text = beneficiary.displayValue;

    // Ce numéro a déjà été utilisé au moins deux fois avec ce même réseau.
    // Le raccourci doit donc rester réellement instantané, sans redemander
    // une confirmation de portabilité ni une seconde saisie.
    widget.viewModel.selectSuggestedBeneficiary(
      beneficiary: beneficiary,
      isPortabilityConfirmed: true,
    );
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      widget.viewModel.saveBeneficiary(
        phoneInput: _beneficiaryController.text,
        isPortabilityConfirmed: _isPortabilityConfirmed,
      );
    } on FormatException catch (error) {
      if (error.message == 'PORTABILITY_REQUIRED') {
        setState(() {
          _requiresPortabilityConfirmation = true;
          _isPortabilityConfirmed = false;
        });
        return;
      }
      IzyTelFeedback.error(context, error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final MobileNetwork? selectedNetwork = widget.viewModel.draft.network;
    final List<BeneficiaryPhoneNumber> suggestions =
        widget.viewModel.suggestedBeneficiaryNumbers;

    return CustomerFlowScaffold(
      currentStep: 5,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Numéro bénéficiaire',
      subtitle: 'Quel numéro doit recevoir cette commande ?',
      onTopBack: widget.onBack,
      onBottomBack: widget.onBack,
      onContinue: _continue,
      isContinueEnabled: _beneficiaryController.text.trim().isNotEmpty,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (suggestions.isNotEmpty) ...<Widget>[
              _FrequentNumbers(
                numbers: suggestions,
                onSelected: _selectSuggestion,
              ),
              const SizedBox(height: 18),
              const _SectionDivider(label: 'Ou saisissez un autre numéro'),
              const SizedBox(height: 18),
            ],
            IzyTelCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (selectedNetwork != null) ...<Widget>[
                    Row(
                      children: <Widget>[
                        IzyTelOperatorLogo(network: selectedNetwork, size: 42),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Réseau sélectionné',
                                style: TextStyle(
                                  color: CustomerAppColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedNetwork.brandLabel,
                                style: const TextStyle(
                                  color: CustomerAppColors.primaryDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  IzyTelTextInput(
                    controller: _beneficiaryController,
                    label: 'Numéro bénéficiaire',
                    hintText: 'Ex. 07 00 00 00 00',
                    helperText: 'Vérifiez simplement le numéro avant de continuer.',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    prefixIcon: Icons.phone_rounded,
                    maxLength: 20,
                    validator: _validateBeneficiary,
                    onChanged: _onPhoneChanged,
                    onFieldSubmitted: (_) => _continue(),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                    ],
                  ),
                ],
              ),
            ),
            if (_requiresPortabilityConfirmation) ...<Widget>[
              const SizedBox(height: 16),
              _PortabilityWarning(
                selectedNetwork: selectedNetwork,
                isConfirmed: _isPortabilityConfirmed,
                onChanged: (bool? value) {
                  setState(() => _isPortabilityConfirmed = value ?? false);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FrequentNumbers extends StatelessWidget {
  const _FrequentNumbers({
    required this.numbers,
    required this.onSelected,
  });

  final List<BeneficiaryPhoneNumber> numbers;
  final ValueChanged<BeneficiaryPhoneNumber> onSelected;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      backgroundColor: CustomerAppColors.primarySoft,
      borderColor: CustomerAppColors.primary.withValues(alpha: 0.16),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: CustomerAppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: CustomerAppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Numéro déjà utilisé',
                      style: TextStyle(
                        color: CustomerAppColors.primaryDeep,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sélectionnez-le directement pour aller plus vite.',
                      style: TextStyle(
                        color: CustomerAppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...numbers.map((BeneficiaryPhoneNumber number) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IzyTelCard(
                onTap: () => onSelected(number),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                showShadow: false,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        number.displayValue,
                        style: const TextStyle(
                          color: CustomerAppColors.primaryDeep,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: CustomerAppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: CustomerAppColors.outlineSoft)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: CustomerAppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Expanded(child: Divider(color: CustomerAppColors.outlineSoft)),
      ],
    );
  }
}

class _PortabilityWarning extends StatelessWidget {
  const _PortabilityWarning({
    required this.selectedNetwork,
    required this.isConfirmed,
    required this.onChanged,
  });

  final MobileNetwork? selectedNetwork;
  final bool isConfirmed;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      backgroundColor: CustomerAppColors.warningContainer,
      borderColor: CustomerAppColors.warning.withValues(alpha: 0.28),
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                color: CustomerAppColors.warning,
                size: 21,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ce numéro semble appartenir à un autre réseau.',
                  style: TextStyle(
                    color: CustomerAppColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            selectedNetwork == null
                ? 'Si le numéro a été porté, vous pouvez continuer.'
                : 'Si ce numéro a été porté vers ${selectedNetwork!.brandLabel}, confirmez-le pour continuer.',
            style: const TextStyle(
              color: CustomerAppColors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: isConfirmed,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Je confirme que ce numéro utilise bien le réseau sélectionné.',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
