import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:flutter/material.dart';

class CustomerSummaryPage extends StatefulWidget {
  const CustomerSummaryPage({super.key, required this.viewModel});

  final CustomerOrderViewModel viewModel;

  @override
  State<CustomerSummaryPage> createState() => _CustomerSummaryPageState();
}

class _CustomerSummaryPageState extends State<CustomerSummaryPage> {
  bool _beneficiaryConfirmed = false;

  Future<void> _continue() async {
    final bool successful = await widget.viewModel
        .createOrderAndContinueToPayment();

    if (!mounted || successful) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            widget.viewModel.submissionErrorMessage ??
                'Impossible de créer la commande.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrderDraft draft = widget.viewModel.draft;
    final bool orderCreated = widget.viewModel.hasCreatedOrder;

    return CustomerFlowScaffold(
      currentStep: 6,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Tout est correct ?',
      subtitle:
          'Vérifiez une dernière fois les informations avant de passer au paiement.',
      onTopBack: orderCreated || widget.viewModel.isSubmitting
          ? null
          : widget.viewModel.goBack,
      onBottomBack: orderCreated || widget.viewModel.isSubmitting
          ? null
          : widget.viewModel.goBack,
      backLabel: orderCreated ? 'Commande enregistrée' : 'Modifier',
      continueLabel: orderCreated
          ? 'Revenir au paiement'
          : 'Continuer vers le paiement',
      onContinue: _continue,
      isContinueEnabled: orderCreated || _beneficiaryConfirmed,
      isContinueLoading: widget.viewModel.isSubmitting,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OrderSummaryCard(draft: draft),
          const SizedBox(height: 18),
          IzyTelCard(
            padding: EdgeInsets.zero,
            child: CheckboxListTile(
              value: _beneficiaryConfirmed,
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: CustomerAppColors.primary,
              title: const Text(
                'J’ai vérifié le numéro bénéficiaire',
                style: TextStyle(
                  color: CustomerAppColors.onSurface,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                  'Certaines opérations ne peuvent pas être annulées après traitement.',
                  style: TextStyle(
                    color: CustomerAppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              onChanged: orderCreated
                  ? null
                  : (bool? value) {
                      setState(() {
                        _beneficiaryConfirmed = value ?? false;
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.draft});

  final CustomerOrderDraft draft;

  @override
  Widget build(BuildContext context) {
    final network = draft.network!;

    return IzyTelCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IzyTelOperatorLogo(network: network, size: 44, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.selectedOfferLabel ?? draft.service!.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${network.brandLabel} • ${draft.service!.label}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 4),
          _SummaryRow(label: 'Client', value: draft.identity!.name),
          _SummaryRow(
            label: 'WhatsApp',
            value: draft.identity!.whatsappNumber.displayValue,
          ),
          _SummaryRow(label: 'Service', value: draft.service!.label),
          _SummaryRow(label: 'Réseau', value: network.customerLabel),
          _SummaryRow(
            label: 'Bénéficiaire',
            value: draft.beneficiaryNumber!.displayValue,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CustomerAppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CustomerAppColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'À payer',
                    style: TextStyle(
                      color: CustomerAppColors.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${formatCfa(draft.amount!)} CFA',
                  style: const TextStyle(
                    color: CustomerAppColors.primary,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: CustomerAppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 13,
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
