import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerBeneficiaryPage extends StatefulWidget {
  const CustomerBeneficiaryPage({super.key, required this.viewModel});

  final CustomerOrderViewModel viewModel;

  @override
  State<CustomerBeneficiaryPage> createState() {
    return _CustomerBeneficiaryPageState();
  }
}

class _CustomerBeneficiaryPageState extends State<CustomerBeneficiaryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _beneficiaryController;
  late final TextEditingController _confirmationController;

  bool _canContinue = false;

  @override
  void initState() {
    super.initState();

    final String initialValue =
        widget.viewModel.draft.beneficiaryNumber?.displayValue ?? '';

    _beneficiaryController = TextEditingController(text: initialValue);

    _confirmationController = TextEditingController(text: initialValue);

    _canContinue = _fieldsAreValidAndMatching();
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validateBeneficiary(String? value) {
    return BeneficiaryPhoneNumber.validate(value);
  }

  String? _validateConfirmation(String? value) {
    final String? formatError = BeneficiaryPhoneNumber.validate(
      value,
      emptyMessage: 'Confirmez le numéro bénéficiaire.',
    );

    if (formatError != null) {
      return formatError;
    }

    if (BeneficiaryPhoneNumber.validate(_beneficiaryController.text) != null) {
      return null;
    }

    final BeneficiaryPhoneNumber beneficiary = BeneficiaryPhoneNumber.parse(
      _beneficiaryController.text,
    );

    final BeneficiaryPhoneNumber confirmation = BeneficiaryPhoneNumber.parse(
      value!,
    );

    if (beneficiary.normalized != confirmation.normalized) {
      return 'Les deux numéros ne correspondent pas.';
    }

    return null;
  }

  bool _fieldsAreValidAndMatching() {
    if (BeneficiaryPhoneNumber.validate(_beneficiaryController.text) != null) {
      return false;
    }

    if (BeneficiaryPhoneNumber.validate(
          _confirmationController.text,
          emptyMessage: 'Confirmez le numéro bénéficiaire.',
        ) !=
        null) {
      return false;
    }

    final BeneficiaryPhoneNumber beneficiary = BeneficiaryPhoneNumber.parse(
      _beneficiaryController.text,
    );

    final BeneficiaryPhoneNumber confirmation = BeneficiaryPhoneNumber.parse(
      _confirmationController.text,
    );

    return beneficiary.normalized == confirmation.normalized;
  }

  void _refreshContinueAvailability(String _) {
    final bool nextValue = _fieldsAreValidAndMatching();

    if (_canContinue == nextValue) {
      return;
    }

    setState(() {
      _canContinue = nextValue;
    });
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    try {
      widget.viewModel.saveBeneficiary(
        phoneInput: _beneficiaryController.text,
        confirmationInput: _confirmationController.text,
      );
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomerFlowScaffold(
      currentStep: 5,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Quel numéro doit recevoir la commande ?',
      subtitle: 'Vérifiez attentivement le numéro avant de continuer.',
      onTopBack: widget.viewModel.goBack,
      onBottomBack: widget.viewModel.goBack,
      onContinue: _continue,
      isContinueEnabled: _canContinue,
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: CustomerAppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CustomerAppColors.surfaceContainerHighest,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel(text: 'Numéro bénéficiaire'),
              TextFormField(
                controller: _beneficiaryController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: _phoneInputFormatters,
                decoration: const InputDecoration(
                  hintText: 'Ex. 07 00 00 00 00',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
                validator: _validateBeneficiary,
                onChanged: _refreshContinueAvailability,
              ),
              const SizedBox(height: 22),
              const _FieldLabel(text: 'Confirmez le numéro'),
              TextFormField(
                controller: _confirmationController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: _phoneInputFormatters,
                decoration: const InputDecoration(
                  hintText: 'Saisissez à nouveau le numéro',
                  prefixIcon: Icon(Icons.dialpad_rounded),
                ),
                validator: _validateConfirmation,
                onChanged: _refreshContinueAvailability,
                onFieldSubmitted: (_) {
                  if (_canContinue) {
                    _continue();
                  }
                },
              ),
              const SizedBox(height: 22),
              const _BeneficiaryWarning(),
            ],
          ),
        ),
      ),
    );
  }

  static final List<TextInputFormatter> _phoneInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]')),
    LengthLimitingTextInputFormatter(24),
  ];
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _BeneficiaryWarning extends StatelessWidget {
  const _BeneficiaryWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerAppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: CustomerAppColors.error,
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Une opération envoyée sur un mauvais numéro peut être difficile à récupérer.',
              style: TextStyle(
                color: CustomerAppColors.onErrorContainer,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
