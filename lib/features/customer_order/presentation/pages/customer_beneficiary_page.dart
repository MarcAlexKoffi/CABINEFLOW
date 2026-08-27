import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_beneficiary_target.dart';
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

  bool _isEditingSavedSelfNumber = false;
  bool _hasEditedPhoneFields = false;

  @override
  void initState() {
    super.initState();

    final String initialValue =
        widget.viewModel.draft.beneficiaryNumber?.displayValue ?? '';

    _beneficiaryController = TextEditingController(text: initialValue);
    _confirmationController = TextEditingController(text: initialValue);
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  bool get _isForMe {
    return widget.viewModel.beneficiaryTarget == CustomerBeneficiaryTarget.self;
  }

  BeneficiaryPhoneNumber? get _savedSelfNumber {
    return widget.viewModel.defaultBeneficiaryNumber;
  }

  bool get _usesSavedSelfNumber {
    return _isForMe &&
        _savedSelfNumber != null &&
        !_isEditingSavedSelfNumber &&
        !_hasEditedPhoneFields;
  }

  bool get _canContinue {
    if (_usesSavedSelfNumber) {
      return true;
    }

    return _fieldsAreValidAndMatching();
  }

  String? _validateBeneficiary(String? value) {
    return BeneficiaryPhoneNumber.validate(
      value,
      emptyMessage: _isForMe
          ? 'Saisissez votre numéro habituel.'
          : 'Saisissez le numéro bénéficiaire.',
    );
  }

  String? _validateConfirmation(String? value) {
    final String? formatError = BeneficiaryPhoneNumber.validate(
      value,
      emptyMessage: _isForMe
          ? 'Confirmez votre numéro habituel.'
          : 'Confirmez le numéro bénéficiaire.',
    );

    if (formatError != null) {
      return formatError;
    }

    if (_validateBeneficiary(_beneficiaryController.text) != null) {
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
    if (_validateBeneficiary(_beneficiaryController.text) != null) {
      return false;
    }

    if (BeneficiaryPhoneNumber.validate(
          _confirmationController.text,
          emptyMessage: _isForMe
              ? 'Confirmez votre numéro habituel.'
              : 'Confirmez le numéro bénéficiaire.',
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

  void _onPhoneChanged(String _) {
    if (_isForMe && !_hasEditedPhoneFields) {
      _hasEditedPhoneFields = true;
      _isEditingSavedSelfNumber = true;
    }

    setState(() {});
  }

  void _selectTarget(CustomerBeneficiaryTarget target) {
    if (widget.viewModel.beneficiaryTarget == target) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    _beneficiaryController.clear();
    _confirmationController.clear();

    setState(() {
      _isEditingSavedSelfNumber = false;
      _hasEditedPhoneFields = false;
    });

    widget.viewModel.selectBeneficiaryTarget(target);
  }

  void _editSavedSelfNumber() {
    final BeneficiaryPhoneNumber? savedNumber = _savedSelfNumber;

    if (savedNumber == null) {
      return;
    }

    _beneficiaryController.text = savedNumber.displayValue;
    _confirmationController.text = savedNumber.displayValue;

    setState(() {
      _isEditingSavedSelfNumber = true;
      _hasEditedPhoneFields = true;
    });
  }

  void _cancelSavedSelfNumberEdit() {
    FocusManager.instance.primaryFocus?.unfocus();
    _beneficiaryController.clear();
    _confirmationController.clear();

    setState(() {
      _isEditingSavedSelfNumber = false;
      _hasEditedPhoneFields = false;
    });
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_usesSavedSelfNumber) {
      widget.viewModel.useSavedBeneficiaryForMe();
      return;
    }

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    try {
      if (_isForMe) {
        widget.viewModel.saveBeneficiaryForMe(
          phoneInput: _beneficiaryController.text,
          confirmationInput: _confirmationController.text,
        );
      } else {
        widget.viewModel.saveBeneficiary(
          phoneInput: _beneficiaryController.text,
          confirmationInput: _confirmationController.text,
        );
      }
    } on FormatException catch (error) {
      _showError(error.message.toString());
    } on StateError catch (error) {
      _showError(error.message.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final BeneficiaryPhoneNumber? savedSelfNumber = _savedSelfNumber;
    final bool showPhoneFields = !_usesSavedSelfNumber;

    return CustomerFlowScaffold(
      currentStep: 5,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Pour qui achetez-vous ?',
      subtitle: 'Choisissez le numéro qui doit recevoir cette commande.',
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
              _BeneficiaryTargetCard(
                selected: _isForMe,
                icon: Icons.person_rounded,
                title: 'Pour moi',
                subtitle: savedSelfNumber == null
                    ? 'Utiliser et mémoriser mon numéro habituel'
                    : savedSelfNumber.displayValue,
                onTap: () => _selectTarget(CustomerBeneficiaryTarget.self),
              ),
              const SizedBox(height: 12),
              _BeneficiaryTargetCard(
                selected: !_isForMe,
                icon: Icons.person_add_alt_1_rounded,
                title: 'Pour un autre numéro',
                subtitle: 'Saisir le numéro du bénéficiaire de cette commande',
                onTap: () => _selectTarget(CustomerBeneficiaryTarget.other),
              ),
              const SizedBox(height: 22),
              if (_isForMe && widget.viewModel.isLoadingCustomerProfile)
                const _ProfileStatusMessage(
                  icon: Icons.sync_rounded,
                  text: 'Recherche de votre numéro habituel…',
                ),
              if (_isForMe &&
                  widget.viewModel.customerProfileErrorMessage != null)
                _ProfileStatusMessage(
                  icon: Icons.info_outline_rounded,
                  text: widget.viewModel.customerProfileErrorMessage!,
                ),
              if (_usesSavedSelfNumber) ...[
                _SavedBeneficiaryCard(number: savedSelfNumber!),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _editSavedSelfNumber,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Modifier mon numéro habituel'),
                  ),
                ),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: showPhoneFields
                    ? _PhoneFields(
                        key: ValueKey<String>(
                          _isForMe ? 'self-fields' : 'other-fields',
                        ),
                        isForMe: _isForMe,
                        beneficiaryController: _beneficiaryController,
                        confirmationController: _confirmationController,
                        validateBeneficiary: _validateBeneficiary,
                        validateConfirmation: _validateConfirmation,
                        onChanged: _onPhoneChanged,
                        onSubmitted: _canContinue ? _continue : null,
                        inputFormatters: _phoneInputFormatters,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey<String>('saved-self-number'),
                      ),
              ),
              if (_isForMe && showPhoneFields) ...[
                const SizedBox(height: 12),
                const _RememberNumberInfo(),
                if (savedSelfNumber != null && _isEditingSavedSelfNumber)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _cancelSavedSelfNumberEdit,
                      child: const Text('Conserver mon numéro actuel'),
                    ),
                  ),
              ],
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

class _BeneficiaryTargetCard extends StatelessWidget {
  const _BeneficiaryTargetCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? CustomerAppColors.primary.withValues(alpha: 0.07)
                : CustomerAppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? CustomerAppColors.primary
                  : CustomerAppColors.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected
                      ? CustomerAppColors.primary.withValues(alpha: 0.1)
                      : CustomerAppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: selected
                      ? CustomerAppColors.primary
                      : CustomerAppColors.onSurfaceVariant,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? CustomerAppColors.primary
                    : CustomerAppColors.outline,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedBeneficiaryCard extends StatelessWidget {
  const _SavedBeneficiaryCard({required this.number});

  final BeneficiaryPhoneNumber number;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CustomerAppColors.surfaceContainerHighest),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.phone_android_rounded,
            color: CustomerAppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Votre numéro habituel',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  number.displayValue,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: CustomerAppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: CustomerAppColors.success,
            size: 21,
          ),
        ],
      ),
    );
  }
}

class _PhoneFields extends StatelessWidget {
  const _PhoneFields({
    super.key,
    required this.isForMe,
    required this.beneficiaryController,
    required this.confirmationController,
    required this.validateBeneficiary,
    required this.validateConfirmation,
    required this.onChanged,
    required this.onSubmitted,
    required this.inputFormatters,
  });

  final bool isForMe;
  final TextEditingController beneficiaryController;
  final TextEditingController confirmationController;
  final FormFieldValidator<String> validateBeneficiary;
  final FormFieldValidator<String> validateConfirmation;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;
  final List<TextInputFormatter> inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(
          text: isForMe ? 'Votre numéro habituel' : 'Numéro bénéficiaire',
        ),
        TextFormField(
          controller: beneficiaryController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: 'Ex. 07 00 00 00 00',
            prefixIcon: const Icon(Icons.phone_android_rounded),
            helperText: isForMe
                ? 'Ce numéro sera proposé automatiquement lors de vos prochaines commandes.'
                : null,
          ),
          validator: validateBeneficiary,
          onChanged: onChanged,
        ),
        const SizedBox(height: 22),
        _FieldLabel(
          text: isForMe
              ? 'Confirmez votre numéro habituel'
              : 'Confirmez le numéro',
        ),
        TextFormField(
          controller: confirmationController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: inputFormatters,
          decoration: const InputDecoration(
            hintText: 'Saisissez à nouveau le numéro',
            prefixIcon: Icon(Icons.dialpad_rounded),
          ),
          validator: validateConfirmation,
          onChanged: onChanged,
          onFieldSubmitted: (_) => onSubmitted?.call(),
        ),
      ],
    );
  }
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

class _ProfileStatusMessage extends StatelessWidget {
  const _ProfileStatusMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: CustomerAppColors.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _RememberNumberInfo extends StatelessWidget {
  const _RememberNumberInfo();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.bookmark_added_outlined,
          size: 18,
          color: CustomerAppColors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'IzyTel mémorisera ce numéro pour cette session client. Vous pourrez toujours acheter pour un autre numéro.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
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
