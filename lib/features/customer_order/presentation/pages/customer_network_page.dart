import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_cards.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_operator_brand.dart';
import 'package:flutter/material.dart';

class CustomerNetworkPage extends StatelessWidget {
  const CustomerNetworkPage({super.key, required this.viewModel});

  final CustomerOrderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final MobileNetwork? selectedNetwork = viewModel.draft.network;

    return CustomerFlowScaffold(
      currentStep: 3,
      totalSteps: CustomerOrderViewModel.totalSteps,
      title: 'Quel est votre réseau ?',
      subtitle: 'Sélectionnez l’opérateur du numéro bénéficiaire.',
      titleTextAlign: TextAlign.center,
      onTopBack: viewModel.goBack,
      onBottomBack: viewModel.goBack,
      onContinue: viewModel.continueFromNetwork,
      isContinueEnabled: viewModel.canContinueFromNetwork,
      content: Column(
        children: [
          for (int index = 0; index < MobileNetwork.values.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            _NetworkOptionCard(
              network: MobileNetwork.values[index],
              isSelected: selectedNetwork == MobileNetwork.values[index],
              onTap: () => viewModel.selectNetwork(MobileNetwork.values[index]),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: CustomerAppColors.primarySoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: CustomerAppColors.primaryContainer),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: CustomerAppColors.primary,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'IzyTel vérifiera ensuite la cohérence entre le réseau choisi et le numéro bénéficiaire afin de limiter les erreurs.',
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
        ],
      ),
    );
  }
}

class _NetworkOptionCard extends StatelessWidget {
  const _NetworkOptionCard({
    required this.network,
    required this.isSelected,
    required this.onTap,
  });

  final MobileNetwork network;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Réseau ${network.brandLabel}',
      child: Stack(
        children: [
          IzyTelCard(
            isSelected: isSelected,
            onTap: onTap,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IzyTelOperatorLogo(network: network, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        network.brandLabel,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        network.brandDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? CustomerAppColors.primary
                        : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? CustomerAppColors.primary
                          : CustomerAppColors.outlineVariant,
                      width: 1.4,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: IgnorePointer(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: network.brandColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
