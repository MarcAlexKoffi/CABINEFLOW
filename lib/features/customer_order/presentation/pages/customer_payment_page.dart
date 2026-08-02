import 'package:cabine_flow/core/services/wave_payment_link_builder.dart';
import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Avez-vous terminé le paiement ?'),
          content: const Text(
            'Confirmez uniquement après avoir validé le paiement '
            'dans Wave. CabineFlow vérifiera ensuite la transaction.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Pas encore'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('J’ai payé'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final bool successful = await widget.viewModel.declarePayment();

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
                          _WavePaymentButton(
                            isLoading: _isOpeningWave,
                            onPressed: _openWave,
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
                                    'Finalisez le paiement dans les 6 heures. '
                                    'Après ce délai, une commande non validée '
                                    'pourra être annulée.',
                                    style: TextStyle(
                                      color: CustomerAppColors.onSurfaceVariant,
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
                        widget.viewModel.paymentLinkWasOpened,
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
    required this.onBack,
    required this.onConfirm,
  });

  final bool isSubmitting;
  final bool isPaymentDeclarationEnabled;
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
                    : const Text(
                        'J’ai effectué le paiement',
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
