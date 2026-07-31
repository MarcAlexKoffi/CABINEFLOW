import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
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
      title: 'Choisissez le réseau',
      subtitle: null,
      onTopBack: viewModel.goBack,
      onBottomBack: viewModel.goBack,
      onContinue: viewModel.continueFromNetwork,
      isContinueEnabled: viewModel.canContinueFromNetwork,
      content: Column(
        children: MobileNetwork.values.map((MobileNetwork network) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: network == MobileNetwork.values.last ? 0 : 16,
            ),
            child: _NetworkOptionCard(
              network: network,
              isSelected: selectedNetwork == network,
              onTap: () {
                viewModel.selectNetwork(network);
              },
            ),
          );
        }).toList(),
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

  String get label {
    switch (network) {
      case MobileNetwork.orange:
        return 'Orange';
      case MobileNetwork.mtn:
        return 'MTN';
      case MobileNetwork.moov:
        return 'Moov Africa';
    }
  }

  Color get accentColor {
    switch (network) {
      case MobileNetwork.orange:
        return const Color(0xFFFF7900);
      case MobileNetwork.mtn:
        return const Color(0xFFFFCC00);
      case MobileNetwork.moov:
        return const Color(0xFF0066CC);
    }
  }

  Color get selectedIconColor {
    if (network == MobileNetwork.mtn) {
      return Colors.black;
    }

    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Réseau $label',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.08)
              : CustomerAppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor
                          : CustomerAppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.signal_cellular_alt_rounded,
                      size: 24,
                      color: isSelected
                          ? selectedIconColor
                          : CustomerAppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: CustomerAppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? accentColor : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? accentColor
                            : CustomerAppColors.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: selectedIconColor,
                          )
                        : null,
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
