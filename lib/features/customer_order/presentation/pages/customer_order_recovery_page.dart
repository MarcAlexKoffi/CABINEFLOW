import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_bottom_actions.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_support_button.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
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
  State<CustomerOrderRecoveryPage> createState() =>
      _CustomerOrderRecoveryPageState();
}

class _CustomerOrderRecoveryPageState extends State<CustomerOrderRecoveryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _beneficiaryController;
  MobileNetwork? _network;
  CustomerService? _service;

  @override
  void initState() {
    super.initState();
    _beneficiaryController = TextEditingController();
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    super.dispose();
  }

  void _clearServerError() => widget.viewModel.clearRecoveryError();

  Future<void> _recover() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false) ||
        _network == null ||
        _service == null) {
      return;
    }

    final bool recovered = await widget.viewModel.recoverOrderByDetails(
      network: _network!,
      service: _service!,
      beneficiaryInput: _beneficiaryController.text,
    );
    if (mounted && recovered) {
      widget.onRecovered();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelShell(
      title: 'Suivi de commande',
      onBack: widget.onBack,
      maxContentWidth: 760,
      child: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Retrouvez votre commande',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Indiquez simplement le réseau, le type de commande et le numéro bénéficiaire.',
                    style: TextStyle(
                      color: CustomerAppColors.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  IzyTelCard(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const _FieldLabel(text: 'Réseau'),
                          DropdownButtonFormField<MobileNetwork>(
                            initialValue: _network,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.cell_tower_rounded),
                              hintText: 'Choisissez le réseau',
                            ),
                            items: MobileNetwork.values
                                .map(
                                  (MobileNetwork network) => DropdownMenuItem<MobileNetwork>(
                                    value: network,
                                    child: Text(network.brandLabel),
                                  ),
                                )
                                .toList(growable: false),
                            validator: (MobileNetwork? value) => value == null
                                ? 'Sélectionnez le réseau.'
                                : null,
                            onChanged: widget.viewModel.isRecoveringOrder
                                ? null
                                : (MobileNetwork? value) {
                                    setState(() => _network = value);
                                    _clearServerError();
                                  },
                          ),
                          const SizedBox(height: 20),
                          const _FieldLabel(text: 'Type de commande'),
                          DropdownButtonFormField<CustomerService>(
                            initialValue: _service,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.category_outlined),
                              hintText: 'Choisissez le service',
                            ),
                            items: CustomerService.values
                                .map(
                                  (CustomerService service) =>
                                      DropdownMenuItem<CustomerService>(
                                        value: service,
                                        child: Text(service.label),
                                      ),
                                )
                                .toList(growable: false),
                            validator: (CustomerService? value) => value == null
                                ? 'Sélectionnez le type de commande.'
                                : null,
                            onChanged: widget.viewModel.isRecoveringOrder
                                ? null
                                : (CustomerService? value) {
                                    setState(() => _service = value);
                                    _clearServerError();
                                  },
                          ),
                          const SizedBox(height: 20),
                          const _FieldLabel(text: 'Numéro bénéficiaire'),
                          TextFormField(
                            controller: _beneficiaryController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+ ]'),
                              ),
                              LengthLimitingTextInputFormatter(20),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Ex. 07 00 00 00 00',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            validator: (String? value) =>
                                BeneficiaryPhoneNumber.validate(
                                  value,
                                  emptyMessage:
                                      'Saisissez le numéro bénéficiaire.',
                                ),
                            onChanged: (_) => _clearServerError(),
                            onFieldSubmitted: (_) => _recover(),
                          ),
                          if (widget.viewModel.recoveryErrorMessage != null) ...<Widget>[
                            const SizedBox(height: 20),
                            _RecoveryErrorBanner(
                              message: widget.viewModel.recoveryErrorMessage!,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: CustomerAppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.lock_outline_rounded,
                          color: CustomerAppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Seules les commandes associées à votre session client sont consultées.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _RecoverySupportHelp(),
                ],
              ),
            ),
          ),
          CustomerBottomActions(
            onBack: widget.viewModel.isRecoveringOrder ? null : widget.onBack,
            onContinue: _recover,
            continueLabel: 'Retrouver ma commande',
            isContinueEnabled: !widget.viewModel.isRecoveringOrder,
            isLoading: widget.viewModel.isRecoveringOrder,
          ),
        ],
      ),
    );
  }
}

class _RecoverySupportHelp extends StatelessWidget {
  const _RecoverySupportHelp();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: <Widget>[
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
        children: <Widget>[
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
