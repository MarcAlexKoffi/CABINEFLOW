import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
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
  MobileNetwork? _detectedNetwork;

  @override
  void initState() {
    super.initState();
    _beneficiaryController = TextEditingController(
      text: widget.viewModel.draft.beneficiaryNumber?.displayValue ?? '',
    );
    _refreshNetworkWarning(_beneficiaryController.text, notify: false);
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

  void _refreshNetworkWarning(String value, {bool notify = true}) {
    final MobileNetwork? selectedNetwork = widget.viewModel.draft.network;
    MobileNetwork? detectedNetwork;
    bool mismatch = false;

    if (BeneficiaryPhoneNumber.validate(value) == null) {
      final BeneficiaryPhoneNumber beneficiary = BeneficiaryPhoneNumber.parse(
        value,
      );
      detectedNetwork = beneficiary.expectedNetwork;
      mismatch = selectedNetwork != null &&
          detectedNetwork != null &&
          detectedNetwork != selectedNetwork;
    }

    void apply() {
      _detectedNetwork = detectedNetwork;
      _requiresPortabilityConfirmation = mismatch;
      _isPortabilityConfirmed = false;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  void _onPhoneChanged(String value) {
    _refreshNetworkWarning(value);
  }

  void _selectSuggestion(BeneficiaryPhoneNumber beneficiary) {
    FocusManager.instance.primaryFocus?.unfocus();
    _beneficiaryController.text = beneficiary.displayValue;

    // Ce numéro a déjà été utilisé au moins deux fois avec ce même réseau.
    // Le raccourci doit rester réellement instantané, sans redemander
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
        _refreshNetworkWarning(_beneficiaryController.text);
        return;
      }
      IzyTelFeedback.error(context, error.message.toString());
    }
  }

  void _continueDespiteNetworkWarning() {
    setState(() => _isPortabilityConfirmed = true);
    _continue();
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrderDraft draft = widget.viewModel.draft;
    final MobileNetwork? selectedNetwork = draft.network;
    final List<BeneficiaryPhoneNumber> suggestions =
        widget.viewModel.suggestedBeneficiaryNumbers;
    final bool canUseMainContinue =
        _beneficiaryController.text.trim().isNotEmpty &&
        (!_requiresPortabilityConfirmation || _isPortabilityConfirmed);

    final bool isDirectTransfer = draft.service == CustomerService.unitTransfer;
    final String title = isDirectTransfer
        ? 'À qui envoyer les unités ?'
        : 'À qui envoyer l’offre ?';
    final String subtitle = isDirectTransfer
        ? 'Renseignez le numéro du bénéficiaire qui recevra les unités.'
        : 'Renseignez le numéro du bénéficiaire qui recevra cette offre.';

    return CustomerFlowScaffold(
      currentStep: 5,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: title,
      subtitle: subtitle,
      onTopBack: widget.onBack,
      onBottomBack: widget.onBack,
      onContinue: _continue,
      isContinueEnabled: canUseMainContinue,
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _OrderContextCard(draft: draft),
            const SizedBox(height: 22),
            IzyTelCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Numéro bénéficiaire',
                    style: TextStyle(
                      color: CustomerAppColors.primaryDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  IzyTelTextInput(
                    controller: _beneficiaryController,
                    hintText: 'Ex. 07 00 00 00 00',
                    helperText:
                        'Vérifiez le numéro avant de continuer. Le copier-coller est autorisé.',
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
                  if (_requiresPortabilityConfirmation) ...<Widget>[
                    const SizedBox(height: 14),
                    _PortabilityWarning(
                      selectedNetwork: selectedNetwork,
                      detectedNetwork: _detectedNetwork,
                      onContinueAnyway: _continueDespiteNetworkWarning,
                    ),
                  ],
                ],
              ),
            ),
            if (suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 22),
              _FrequentNumbers(
                numbers: suggestions,
                onSelected: _selectSuggestion,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderContextCard extends StatelessWidget {
  const _OrderContextCard({required this.draft});

  final CustomerOrderDraft draft;

  @override
  Widget build(BuildContext context) {
    final MobileNetwork network = draft.network!;
    final String title = draft.selectedOfferLabel ?? draft.service!.label;
    final int? amount = draft.amount;

    return IzyTelCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: <Widget>[
          IzyTelOperatorLogo(network: network, size: 56, borderRadius: 14),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: CustomerAppColors.primaryDeep,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${network.brandLabel} • ${draft.service!.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (amount != null) ...<Widget>[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: CustomerAppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                formatCfaFull(amount),
                style: const TextStyle(
                  color: CustomerAppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Numéros fréquents',
          style: TextStyle(
            color: CustomerAppColors.primaryDeep,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Des numéros déjà utilisés plusieurs fois sur ce réseau.',
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 12.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (int index = 0; index < numbers.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 10),
                _FrequentNumberCard(
                  number: numbers[index],
                  onTap: () => onSelected(numbers[index]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FrequentNumberCard extends StatelessWidget {
  const _FrequentNumberCard({required this.number, required this.onTap});

  final BeneficiaryPhoneNumber number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: IzyTelCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        showShadow: false,
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: CustomerAppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: CustomerAppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                number.displayValue.replaceFirst('+225 ', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CustomerAppColors.primaryDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: CustomerAppColors.primary,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }
}

class _PortabilityWarning extends StatelessWidget {
  const _PortabilityWarning({
    required this.selectedNetwork,
    required this.detectedNetwork,
    required this.onContinueAnyway,
  });

  final MobileNetwork? selectedNetwork;
  final MobileNetwork? detectedNetwork;
  final VoidCallback onContinueAnyway;

  @override
  Widget build(BuildContext context) {
    final String detectedLabel = detectedNetwork?.brandLabel ?? 'un autre réseau';
    final String selectedLabel = selectedNetwork?.brandLabel ?? 'le réseau choisi';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerAppColors.warningContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CustomerAppColors.warning.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                color: CustomerAppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ce numéro semble habituellement associé à $detectedLabel. Vérifiez le réseau choisi avant de continuer.',
                  style: const TextStyle(
                    color: CustomerAppColors.primaryDeep,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onContinueAnyway,
              child: Text('Continuer quand même avec $selectedLabel'),
            ),
          ),
        ],
      ),
    );
  }
}
