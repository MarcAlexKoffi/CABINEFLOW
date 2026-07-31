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

  @override
  Widget build(BuildContext context) {
    final double progress = currentStep / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ÉTAPE $currentStep SUR $totalSteps',
          style: const TextStyle(
            color: CustomerAppColors.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(minHeight: 4, value: progress),
        ),
      ],
    );
  }
}
