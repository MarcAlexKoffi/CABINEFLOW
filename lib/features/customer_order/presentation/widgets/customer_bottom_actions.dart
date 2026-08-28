import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class CustomerBottomActions extends StatelessWidget {
  const CustomerBottomActions({
    super.key,
    required this.onContinue,
    this.onBack,
    this.backLabel = 'Retour',
    this.continueLabel = 'Suivant',
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
        color: Colors.white,
        border: Border(top: BorderSide(color: CustomerAppColors.outlineSoft)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 22,
            offset: Offset(0, -7),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 11, 18, 12),
          child: Row(
            children: [
              if (onBack != null) ...[
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : onBack,
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    label: Text(backLabel),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: onBack == null ? 1 : 6,
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
      ),
    );
  }
}
