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
    final bool desktop = MediaQuery.sizeOf(context).width >= 760;

    final Widget actions = Row(
      children: <Widget>[
        if (onBack != null) ...<Widget>[
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
            onPressed: isContinueEnabled && !isLoading ? onContinue : null,
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
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: desktop ? Colors.transparent : Colors.white,
        border: desktop
            ? null
            : const Border(
                top: BorderSide(color: CustomerAppColors.outlineSoft),
              ),
        boxShadow: desktop
            ? null
            : const <BoxShadow>[
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
          padding: EdgeInsets.fromLTRB(
            desktop ? 28 : 18,
            desktop ? 8 : 11,
            desktop ? 28 : 18,
            desktop ? 18 : 12,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: desktop
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.98),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CustomerAppColors.outlineSoft,
                        ),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x120F172A),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: actions,
                      ),
                    )
                  : actions,
            ),
          ),
        ),
      ),
    );
  }
}
