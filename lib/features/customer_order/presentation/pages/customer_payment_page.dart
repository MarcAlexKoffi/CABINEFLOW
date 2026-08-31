import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_progress_indicator.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_inputs.dart';
import 'package:cabine_flow/shared/widgets/izytel/izytel_feedback.dart';
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
    IzyTelFeedback.show(context, message);
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: ColoredBox(
            color: CustomerAppColors.surface,
            child: SafeArea(
              child: Column(
                children: [
                  _PaymentTopBar(onBack: widget.viewModel.goBack),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CustomerProgressIndicator(
                            currentStep: 7,
                            totalSteps: CustomerOrderViewModel.totalSteps,
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'Choisissez votre moyen de paiement',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sélectionnez le service avec lequel vous souhaitez régler votre commande.',
                            style: TextStyle(
                              color: CustomerAppColors.onSurfaceVariant,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (isExpiredWithoutDeclaration)
                            const _ExpiredPaymentWarning()
                          else ...[
                            const _PaymentMethodGrid(),
                            const SizedBox(height: 18),
                            _PaymentSummaryCard(draft: draft),
                            const SizedBox(height: 16),
                            const _PaymentSecurityCard(),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _isOpeningWave ? null : _openWave,
                              icon: _isOpeningWave
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                'Payer ${formatCfa(draft.amount!)} CFA',
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Vous serez redirigé vers Wave pour finaliser le paiement.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CustomerAppColors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
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
                                      'Finalisez le paiement dans les 6 heures. Après ce délai, une commande non confirmée peut expirer.',
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
                            if (widget.viewModel.paymentLinkWasOpened) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: CustomerAppColors.successContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Paiement ouvert. Après avoir payé dans Wave, revenez ici et déclarez votre paiement.',
                                  style: TextStyle(
                                    color: CustomerAppColors.success,
                                    fontSize: 12,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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
                'IzyTel',
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

class _PaymentMethodGrid extends StatelessWidget {
  const _PaymentMethodGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 480;
        final List<Widget> cards = [
          const _PaymentMethodCard(
            name: 'Wave',
            logoPath: 'assets/images/wave_logo.png',
            isSelected: true,
          ),
          const _PaymentMethodCard(
            name: 'Orange Money',
            logoPath: 'assets/brands/operators/orange_ci.png',
            isDisabled: true,
          ),
          const _PaymentMethodCard(
            name: 'MTN MoMo',
            logoPath: 'assets/brands/operators/mtn_ci.png',
            isDisabled: true,
          ),
          const _PaymentMethodCard(
            name: 'Moov Money',
            logoPath: 'assets/brands/operators/moov_africa_ci.png',
            isDisabled: true,
          ),
        ];

        if (compact) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.12,
            children: cards,
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.name,
    required this.logoPath,
    this.isSelected = false,
    this.isDisabled = false,
  });

  final String name;
  final String logoPath;
  final bool isSelected;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDisabled ? 0.52 : 1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? CustomerAppColors.primarySoft
              : CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? CustomerAppColors.primary
                : CustomerAppColors.outlineSoft,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(logoPath, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDisabled
                        ? CustomerAppColors.onSurfaceVariant
                        : CustomerAppColors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (isSelected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: CustomerAppColors.primary,
                  size: 20,
                ),
              ),
            if (isDisabled)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: CustomerAppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'BIENTÔT',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: CustomerAppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSecurityCard extends StatelessWidget {
  const _PaymentSecurityCard();

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      showShadow: false,
      child: const Column(
        children: [
          _SecurityLine(
            icon: Icons.lock_outline_rounded,
            label: 'Paiement sécurisé',
          ),
          Divider(height: 22),
          _SecurityLine(
            icon: Icons.verified_user_outlined,
            label: 'Montant vérifié',
          ),
        ],
      ),
    );
  }
}

class _SecurityLine extends StatelessWidget {
  const _SecurityLine({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: CustomerAppColors.successContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: CustomerAppColors.success, size: 18),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: CustomerAppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({required this.draft});

  final CustomerOrderDraft draft;

  @override
  Widget build(BuildContext context) {
    return IzyTelCard(
      padding: const EdgeInsets.all(20),
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
                child: const Text('Retour', textAlign: TextAlign.center),
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
                            ? 'Paiement déjà effectué'
                            : 'Paiement effectué',
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
                  IzyTelTextInput(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    hintText: 'Ex. KOFFI MARC',
                    prefixIcon: Icons.person_outline_rounded,
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
                  IzyTelTextInput(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[
                      AutofillHints.telephoneNumber,
                    ],
                    hintText: 'Ex. 07 00 00 00 00',
                    prefixIcon: Icons.phone_android_rounded,
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
                      decoration: InputDecoration(
                        labelText: 'Heure approximative du paiement',
                        prefixIcon: const Icon(Icons.schedule_rounded),
                        suffixIcon: const Icon(Icons.edit_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: CustomerAppColors.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: CustomerAppColors.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: CustomerAppColors.primary,
                            width: 2,
                          ),
                        ),
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
                  IzyTelTextInput(
                    controller: _referenceController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    hintText: 'Facultatif',
                    prefixIcon: Icons.tag_rounded,
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
