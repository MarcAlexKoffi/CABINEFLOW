import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:flutter/material.dart';

class CustomerServicePage extends StatelessWidget {
  const CustomerServicePage({super.key, required this.viewModel});

  final CustomerOrderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final CustomerService? selectedService = viewModel.draft.service;

    return CustomerFlowScaffold(
      currentStep: 2,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Choisissez votre service',
      subtitle:
          'Sélectionnez le type de recharge que vous souhaitez effectuer.',
      titleTextAlign: TextAlign.start,
      onTopBack: viewModel.goBack,
      onBottomBack: viewModel.goBack,
      onContinue: viewModel.continueFromService,
      isContinueEnabled: viewModel.canContinueFromService,
      content: Column(
        children: CustomerService.values.map((CustomerService service) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: service == CustomerService.values.last ? 0 : 18,
            ),
            child: _ServiceOptionCard(
              service: service,
              isSelected: selectedService == service,
              onTap: () {
                viewModel.selectService(service);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ServiceOptionCard extends StatelessWidget {
  const _ServiceOptionCard({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  final CustomerService service;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get icon {
    switch (service) {
      case CustomerService.unitTransfer:
        return Icons.send_rounded;
      case CustomerService.internetSubscription:
        return Icons.wifi_rounded;
      case CustomerService.calls:
        return Icons.call_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${service.label}. ${service.description}',
      child: IzyTelCard(
        isSelected: isSelected,
        onTap: onTap,
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? CustomerAppColors.primary
                    : CustomerAppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? CustomerAppColors.onPrimary
                    : CustomerAppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CustomerAppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CustomerAppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? CustomerAppColors.primary
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? CustomerAppColors.primary
                      : CustomerAppColors.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: CustomerAppColors.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
