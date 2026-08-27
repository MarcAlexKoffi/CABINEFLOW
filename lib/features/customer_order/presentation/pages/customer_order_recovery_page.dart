import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_recovery_key.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_bottom_actions.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_support_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomerOrderRecoveryPage extends StatefulWidget {
  const CustomerOrderRecoveryPage({
    super.key,
    required this.viewModel,
    required this.onBack,
    required this.onRecovered,
  });

  final CustomerOrderViewModel viewModel;
  final VoidCallback onBack;
  final VoidCallback onRecovered;

  @override
  State<CustomerOrderRecoveryPage> createState() {
    return _CustomerOrderRecoveryPageState();
  }
}

class _CustomerOrderRecoveryPageState extends State<CustomerOrderRecoveryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _referenceController;
  late final TextEditingController _whatsappController;

  @override
  void initState() {
    super.initState();
    _referenceController = TextEditingController();
    _whatsappController = TextEditingController();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  String? _validateWhatsapp(String? input) {
    return WhatsappPhoneNumber.validate('+225 ${input ?? ''}');
  }

  void _clearServerError() {
    widget.viewModel.clearRecoveryError();
  }

  Future<void> _recover() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final bool recovered = await widget.viewModel.recoverOrder(
      reference: _referenceController.text,
      whatsappInput: '+225 ${_whatsappController.text}',
    );
    if (!mounted || !recovered) {
      return;
    }

    widget.onRecovered();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: CustomerAppColors.surface,
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0x33C2C6D8)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _RecoveryTopBar(onBack: widget.onBack),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Retrouver une\ncommande',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Saisissez les informations utilisées lors de votre commande pour retrouver son suivi.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _RecoveryFormCard(
                            formKey: _formKey,
                            referenceController: _referenceController,
                            whatsappController: _whatsappController,
                            recoveryErrorMessage:
                                widget.viewModel.recoveryErrorMessage,
                            onChanged: _clearServerError,
                            validateWhatsapp: _validateWhatsapp,
                          ),
                          const SizedBox(height: 22),
                          const _RecoverySupportHelp(),
                        ],
                      ),
                    ),
                  ),
                  CustomerBottomActions(
                    onBack: widget.viewModel.isRecoveringOrder
                        ? null
                        : widget.onBack,
                    onContinue: () {
                      _recover();
                    },
                    continueLabel: 'Retrouver ma commande',
                    isContinueEnabled: !widget.viewModel.isRecoveringOrder,
                    isLoading: widget.viewModel.isRecoveringOrder,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecoverySupportHelp extends StatelessWidget {
  const _RecoverySupportHelp();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          'Vous n’arrivez pas à retrouver votre commande ?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        SizedBox(height: 2),
        CustomerSupportButton(),
      ],
    );
  }
}

class _RecoveryTopBar extends StatelessWidget {
  const _RecoveryTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: CustomerAppColors.primary,
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'CabineFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CustomerAppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _RecoveryFormCard extends StatelessWidget {
  const _RecoveryFormCard({
    required this.formKey,
    required this.referenceController,
    required this.whatsappController,
    required this.recoveryErrorMessage,
    required this.onChanged,
    required this.validateWhatsapp,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController referenceController;
  final TextEditingController whatsappController;
  final String? recoveryErrorMessage;
  final VoidCallback onChanged;
  final FormFieldValidator<String> validateWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel(text: 'Référence de commande'),
            TextFormField(
              controller: referenceController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                LengthLimitingTextInputFormatter(40),
              ],
              decoration: const InputDecoration(
                hintText: 'CF-20260827-XXXXXX',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              validator: CustomerOrderRecoveryKey.validateReference,
              onChanged: (_) {
                onChanged();
              },
            ),
            const SizedBox(height: 22),
            const _FieldLabel(text: 'Numéro WhatsApp'),
            TextFormField(
              controller: whatsappController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()-]')),
                LengthLimitingTextInputFormatter(18),
              ],
              decoration: const InputDecoration(
                hintText: '07 12 34 56 78',
                prefixText: '+225  ',
                prefixIcon: Icon(Icons.chat_outlined),
              ),
              validator: validateWhatsapp,
              onChanged: (_) {
                onChanged();
              },
              onFieldSubmitted: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
            if (recoveryErrorMessage != null) ...[
              const SizedBox(height: 22),
              _RecoveryErrorBanner(message: recoveryErrorMessage!),
            ],
          ],
        ),
      ),
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
      child: Text(
        text,
        style: const TextStyle(
          color: CustomerAppColors.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RecoveryErrorBanner extends StatelessWidget {
  const _RecoveryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CustomerAppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: CustomerAppColors.onErrorContainer,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: CustomerAppColors.onErrorContainer,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
