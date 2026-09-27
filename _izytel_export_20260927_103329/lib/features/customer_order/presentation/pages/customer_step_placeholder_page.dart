import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/core/utils/currency_formatter.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter/material.dart';

class CustomerStepPlaceholderPage extends StatelessWidget {
  const CustomerStepPlaceholderPage({super.key, required this.viewModel});

  final CustomerOrderViewModel viewModel;

  String _networkLabel(MobileNetwork? network) {
    switch (network) {
      case MobileNetwork.orange:
        return 'Orange';
      case MobileNetwork.mtn:
        return 'MTN';
      case MobileNetwork.moov:
        return 'Moov Africa';
      case null:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerIdentity? identity = viewModel.draft.identity;
    final CustomerService? service = viewModel.draft.service;
    final MobileNetwork? network = viewModel.draft.network;
    final CustomerOffer? offer = viewModel.draft.offer;
    final int? amount = viewModel.draft.amount;

    final String selectedProduct = service == CustomerService.unitTransfer
        ? 'Transfert d’unités'
        : viewModel.draft.selectedOfferLabel ?? offer?.catalogLabel ?? '—';

    return CustomerFlowScaffold(
      currentStep: 6,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Numéro bénéficiaire enregistré',
      subtitle:
          'La prochaine étape sera remplacée par votre écran de récapitulatif.',
      onTopBack: viewModel.goBack,
      onBottomBack: viewModel.goBack,
      onContinue: () {},
      isContinueEnabled: false,
      content: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CustomerAppColors.surfaceContainerHighest),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Brouillon actuel',
              style: TextStyle(
                color: CustomerAppColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _DraftLine(label: 'Nom', value: identity?.name ?? '—'),
            _DraftLine(
              label: 'WhatsApp',
              value: identity?.whatsappNumber.displayValue ?? '—',
            ),
            _DraftLine(label: 'Service', value: service?.label ?? '—'),
            _DraftLine(label: 'Réseau', value: _networkLabel(network)),
            _DraftLine(label: 'Offre', value: selectedProduct),
            _DraftLine(
              label: 'Montant',
              value: amount == null ? '—' : '${formatCfa(amount)} CFA',
            ),
            _DraftLine(
              label: 'Numéro bénéficiaire',
              value: viewModel.draft.beneficiaryNumber?.displayValue ?? '—',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftLine extends StatelessWidget {
  const _DraftLine({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Text(
        '$label : $value',
        style: const TextStyle(color: CustomerAppColors.onSurfaceVariant),
      ),
    );
  }
}
