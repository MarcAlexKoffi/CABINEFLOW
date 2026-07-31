import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerIdentificationPage extends StatefulWidget {
  const CustomerIdentificationPage({
    super.key,
    required this.viewModel,
  });

  final CustomerOrderViewModel viewModel;

  @override
  State<CustomerIdentificationPage> createState() {
    return _CustomerIdentificationPageState();
  }
}

class _CustomerIdentificationPageState
    extends State<CustomerIdentificationPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _whatsappController;

  @override
  void initState() {
    super.initState();

    final CustomerIdentity? identity = widget.viewModel.draft.identity;

    _nameController = TextEditingController(
      text: identity?.name ?? '',
    );

    _whatsappController = TextEditingController(
      text: identity?.whatsappNumber.displayValue ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final String name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Saisissez votre nom ou surnom.';
    }

    if (name.length < 2) {
      return 'Le nom doit contenir au moins 2 caractères.';
    }

    if (name.length > 50) {
      return 'Le nom ne doit pas dépasser 50 caractères.';
    }

    return null;
  }

  void _continue() {
    FocusManager.instance.primaryFocus?.unfocus();

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    widget.viewModel.saveIdentity(
      name: _nameController.text,
      whatsappInput: _whatsappController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomerFlowScaffold(
      currentStep: 1,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Passez votre commande',
      subtitle:
          'Indiquez simplement votre nom et votre numéro WhatsApp.',
      onTopBack: () {
        Navigator.of(context).maybePop();
      },
      onBottomBack: null,
      onContinue: _continue,
      footer: const _NoAccountMessage(),
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
              const _FieldLabel(text: 'Nom ou surnom'),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'Ex. Jean Dupont',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 22),
              const _FieldLabel(text: 'Numéro WhatsApp'),
              TextFormField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9+ ()-]'),
                  ),
                  LengthLimitingTextInputFormatter(24),
                ],
                decoration: const InputDecoration(
                  hintText: '+225 07 00 00 00 00',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: WhatsappPhoneNumber.validate,
                onFieldSubmitted: (_) {
                  _continue();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _NoAccountMessage extends StatelessWidget {
  const _NoAccountMessage();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 16,
          color: CustomerAppColors.onSurfaceVariant,
        ),
        SizedBox(width: 7),
        Text(
          'Aucun compte à créer.',
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
