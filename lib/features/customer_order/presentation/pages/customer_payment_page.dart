import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerPaymentPage extends StatefulWidget {
  const CustomerPaymentPage({
    super.key,
    required this.viewModel,
    this.linkBuilder = const WavePaymentLinkBuilder(),
  });

  final CustomerOrderViewModel viewModel;
  final WavePaymentLinkBuilder linkBuilder;

  @override
  State<CustomerPaymentPage> createState() {
    return _CustomerPaymentPageState();
  }
}

class _CustomerPaymentPageState extends State<CustomerPaymentPage> {
  bool _isOpeningWave = false;

  Uri get _paymentUri {
    return widget.linkBuilder.build(amount: widget.viewModel.draft.amount!);
  }

  Future<void> _openWave() async {
    if (widget.viewModel.receipt?.isExpired == true) {
      _showMessage(
        'Cette commande a expiré. N’effectuez plus un nouveau paiement pour cette référence.',
      );
      return;
    }

    if (_isOpeningWave) {
      return;
    }

    setState(() {
      _isOpeningWave = true;
    });

    try {
      final bool launched = await launchUrl(
        _paymentUri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) {
        return;
      }

      if (!launched) {
        _showMessage(
          'Impossible d’ouvrir Wave. Réessayez dans quelques instants.',
        );
        return;
      }

      widget.viewModel.markPaymentLinkOpened();
    } catch (_) {
      if (mounted) {
        _showMessage(
          'Impossible d’ouvrir Wave. Réessayez dans quelques instants.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningWave = false;
        });
      }
    }
  }

  Future<void> _confirmPaymentDeclaration() async {
    final CustomerOrderDraft draft = widget.viewModel.draft;
    final _PaymentDeclarationFormData? declaration =
        await showModalBottomSheet<_PaymentDeclarationFormData>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext sheetContext) {
            return _PaymentDeclarationSheet(
              initialName: draft.identity!.name,
              initialPhone: draft.identity!.whatsappNumber.displayValue,
            );
          },
        );

    if (declaration == null || !mounted) {
      return;
    }

    final bool successful = await widget.viewModel.declarePayment(
      waveAccountName: declaration.waveAccountName,
      wavePayerPhoneInput: declaration.wavePayerPhone,
      approximatePaymentTime: declaration.approximatePaymentTime,
      declaredWaveReference: declaration.declaredWaveReference,
    );

    if (!mounted || successful) {
      return;
    }

    _showMessage(
      widget.viewModel.submissionErrorMessage ??
          'Impossible d’enregistrer la déclaration de paiement.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrderDraft draft = widget.viewModel.draft;
    final bool isExpiredWithoutDeclaration =
        widget.viewModel.receipt?.isExpired == true &&
        widget.viewModel.receipt?.isPaymentDeclared == false;

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
                  _PaymentTopBar(onBack: widget.viewModel.goBack),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CustomerProgressIndicator(
                            currentStep: 7,
                            totalSteps: CustomerOrderViewModel.totalSteps,
                          ),
                          const SizedBox(height: 34),
                          Text(
                            'Paiement de la commande',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Vérifiez les détails avant de procéder au paiement.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 26),
                          _PaymentSummaryCard(draft: draft),
                          const SizedBox(height: 24),
                          if (isExpiredWithoutDeclaration)
                            const _ExpiredPaymentWarning()
                          else
                            _WavePaymentButton(
                              isLoading: _isOpeningWave,
                              onPressed: _openWave,
                            ),
                          if (!isExpiredWithoutDeclaration) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: CustomerAppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.schedule_rounded,
                                    color: CustomerAppColors.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Finalisez le paiement dans les 6 heures. '
                                      'Après ce délai, la commande expirera '
                                      'automatiquement si le paiement n’est pas confirmé.',
                                      style: TextStyle(
                                        color:
                                            CustomerAppColors.onSurfaceVariant,
                                        fontSize: 12,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (widget.viewModel.paymentLinkWasOpened) ...[
                            const SizedBox(height: 18),
                            const Text(
                              'Revenez sur cette page après le paiement '
                              'et confirmez ci-dessous.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CustomerAppColors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _PaymentBottomActions(
                    isSubmitting: widget.viewModel.isSubmitting,
                    isPaymentDeclarationEnabled:
                        widget.viewModel.paymentLinkWasOpened ||
                        isExpiredWithoutDeclaration,
                    isExpired: isExpiredWithoutDeclaration,
                    onBack: widget.viewModel.goBack,
                    onConfirm: _confirmPaymentDeclaration,
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

class _PaymentTopBar extends StatelessWidget {
  const _PaymentTopBar({required this.onBack});

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

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({required this.draft});

  final CustomerOrderDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          _PaymentRow(
            label: 'Montant',
            value: '${formatCfa(draft.amount!)} CFA',
            isAmount: true,
          ),
          _PaymentRow(label: 'Réseau', value: draft.network!.customerLabel),
          _PaymentRow(label: 'Offre', value: draft.selectedOfferLabel!),
          _PaymentRow(
            label: 'Numéro bénéficiaire',
            value: draft.beneficiaryNumber!.displayValue,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    this.isAmount = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isAmount;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: CustomerAppColors.surfaceContainerHigh,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: isAmount
                    ? CustomerAppColors.primary
                    : CustomerAppColors.onSurface,
                fontSize: isAmount ? 19 : 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiredPaymentWarning extends StatelessWidget {
  const _ExpiredPaymentWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE8E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withAlpha(90)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.timer_off_outlined, color: Color(0xFFB91C1C), size: 24),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Cette commande a expiré. N’effectuez plus de nouveau paiement. Si vous aviez déjà payé avant de constater l’expiration, déclarez-le avec le bouton ci-dessous afin qu’un opérateur l’examine.',
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePaymentButton extends StatelessWidget {
  const _WavePaymentButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1B439C),
      borderRadius: BorderRadius.circular(16),
      elevation: 5,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              if (isLoading)
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              else
                const Text(
                  'WAVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Payer avec Wave Mobile Money',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentBottomActions extends StatelessWidget {
  const _PaymentBottomActions({
    required this.isSubmitting,
    required this.isPaymentDeclarationEnabled,
    required this.isExpired,
    required this.onBack,
    required this.onConfirm,
  });

  final bool isSubmitting;
  final bool isPaymentDeclarationEnabled;
  final bool isExpired;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CustomerAppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isSubmitting ? null : onBack,
                child: const Text(
                  'Retour au récapitulatif',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: isSubmitting || !isPaymentDeclarationEnabled
                    ? null
                    : onConfirm,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isExpired
                            ? 'J’ai déjà effectué le paiement'
                            : 'J’ai effectué le paiement',
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentDeclarationFormData {
  const _PaymentDeclarationFormData({
    required this.waveAccountName,
    required this.wavePayerPhone,
    required this.approximatePaymentTime,
    this.declaredWaveReference,
  });

  final String waveAccountName;
  final String wavePayerPhone;
  final String approximatePaymentTime;
  final String? declaredWaveReference;
}

class _PaymentDeclarationSheet extends StatefulWidget {
  const _PaymentDeclarationSheet({
    required this.initialName,
    required this.initialPhone,
  });

  final String initialName;
  final String initialPhone;

  @override
  State<_PaymentDeclarationSheet> createState() {
    return _PaymentDeclarationSheetState();
  }
}

class _PaymentDeclarationSheetState extends State<_PaymentDeclarationSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _referenceController;
  late TimeOfDay _approximateTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _referenceController = TextEditingController();
    _approximateTime = TimeOfDay.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final String hour = _approximateTime.hour.toString().padLeft(2, '0');
    final String minute = _approximateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: _approximateTime,
      helpText: 'Heure approximative du paiement',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      _approximateTime = selectedTime;
    });
  }

  void _submit() {
    final FormState? form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    final String reference = _referenceController.text.trim();

    Navigator.of(context).pop(
      _PaymentDeclarationFormData(
        waveAccountName: _nameController.text.trim(),
        wavePayerPhone: _phoneController.text.trim(),
        approximatePaymentTime: _formattedTime,
        declaredWaveReference: reference.isEmpty ? null : reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: CustomerAppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: CustomerAppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Déclarer le paiement Wave',
                    style: TextStyle(
                      color: CustomerAppColors.onSurface,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Ces informations aideront l’opérateur à retrouver '
                    'votre transaction. Elles ne confirment pas '
                    'automatiquement le paiement.',
                    style: TextStyle(
                      color: CustomerAppColors.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Nom affiché sur le compte Wave',
                      hintText: 'Ex. KOFFI MARC',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (String? value) {
                      final String cleaned = value?.trim() ?? '';

                      if (cleaned.length < 2) {
                        return 'Saisissez le nom affiché sur le compte Wave.';
                      }

                      if (cleaned.length > 80) {
                        return 'Maximum 80 caractères.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[
                      AutofillHints.telephoneNumber,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Numéro Wave utilisé',
                      hintText: 'Ex. 07 00 00 00 00',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    validator: (String? value) {
                      final String? error = WhatsappPhoneNumber.validate(value);
                      return error?.replaceAll(
                        'votre numéro WhatsApp',
                        'le numéro Wave',
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _selectTime,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Heure approximative du paiement',
                        prefixIcon: Icon(Icons.schedule_rounded),
                        suffixIcon: Icon(Icons.edit_outlined),
                      ),
                      child: Text(
                        _formattedTime,
                        style: const TextStyle(
                          color: CustomerAppColors.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _referenceController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Référence Wave éventuelle',
                      hintText: 'Facultatif',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (String? value) {
                      if ((value?.trim().length ?? 0) > 80) {
                        return 'Maximum 80 caractères.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Confirmer ma déclaration'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Annuler'),
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
