import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class CustomerBottomActions extends StatelessWidget {
  const CustomerBottomActions({
    super.key,
    required this.onContinue,
    this.onBack,
    this.backLabel = 'Retour',
    this.continueLabel = 'Continuer',
    this.isContinueEnabled = true,
    this.isLoading = false,
  });

  final VoidCallback? onBack;
  final VoidCallback onContinue;
  final String backLabel;
  final String continueLabel;
  final bool isContinueEnabled;
  final bool isLoading;

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
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                label: Text(backLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isContinueEnabled && !isLoading
                    ? onContinue
                    : null,
                iconAlignment: IconAlignment.end,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(continueLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
