import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class CustomerProgressIndicator extends StatelessWidget {
  const CustomerProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  static const List<String> _labels = <String>[
    'Identité',
    'Service',
    'Réseau',
    'Offre',
    'Bénéficiaire',
    'Vérification',
    'Paiement',
  ];

  @override
  Widget build(BuildContext context) {
    final int visibleStep = currentStep.clamp(1, _labels.length);
    final String label = _labels[visibleStep - 1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: CustomerAppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$visibleStep/${_labels.length}',
              style: const TextStyle(
                color: CustomerAppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            for (int index = 0; index < _labels.length; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: index < visibleStep ? 4 : 3,
                  decoration: BoxDecoration(
                    color: index < visibleStep
                        ? CustomerAppColors.primary
                        : CustomerAppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              if (index != _labels.length - 1) const SizedBox(width: 5),
            ],
          ],
        ),
      ],
    );
  }
}
