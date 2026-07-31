import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_draft.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_order_labels.dart';
import 'package:flutter/material.dart';

class CustomerSummaryPage extends StatefulWidget {
  const CustomerSummaryPage({
    super.key,
    required this.viewModel,
  });

  final CustomerOrderViewModel viewModel;

  @override
  State<CustomerSummaryPage> createState() {
    return _CustomerSummaryPageState();
  }
}

class _CustomerSummaryPageState extends State<CustomerSummaryPage> {
  bool _beneficiaryConfirmed = false;

  @override
  Widget build(BuildContext context) {
    final CustomerOrderDraft draft = widget.viewModel.draft;

    return CustomerFlowScaffold(
      currentStep: 6,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Vérifiez votre commande',
      onTopBack: widget.viewModel.goBack,
      onBottomBack: widget.viewModel.goBack,
      backLabel: 'Modifier la commande',
      continueLabel: 'Payer avec Wave',
      onContinue: widget.viewModel.continueFromSummary,
      isContinueEnabled: _beneficiaryConfirmed,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryCard(draft: draft),
          const SizedBox(height: 28),
          Material(
            color: CustomerAppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            child: CheckboxListTile(
              value: _beneficiaryConfirmed,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Je confirme que le numéro bénéficiaire est correct.',
                style: TextStyle(
                  color: CustomerAppColors.onSurface,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onChanged: (bool? value) {
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.draft,
  });

  final CustomerOrderDraft draft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
          _SummaryRow(
            label: 'Nom',
            value: draft.identity!.name,
          ),
          _SummaryRow(
            label: 'Numéro WhatsApp',
            value: draft.identity!.whatsappNumber.displayValue,
          ),
          _SummaryRow(
            label: 'Service',
            value: draft.service!.label,
          ),
          _SummaryRow(
            label: 'Réseau',
            value: draft.network!.customerLabel,
          ),
          _SummaryRow(
            label: 'Offre',
            value: draft.selectedOfferLabel!,
          ),
          _SummaryRow(
            label: 'Numéro bénéficiaire',
            value: draft.beneficiaryNumber!.displayValue,
          ),
          _SummaryRow(
            label: 'Montant total',
            value: '${formatCfa(draft.amount!)} CFA',
            isLast: true,
            isAmount: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
    this.isAmount = false,
  });

  final String label;
  final String value;
  final bool isLast;
  final bool isAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 17,
        bottom: isLast ? 19 : 17,
      ),
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
                fontSize: 14,
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
                fontSize: isAmount ? 18 : 14,
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
