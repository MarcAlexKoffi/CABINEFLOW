import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_bottom_actions.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_progress_indicator.dart';
import 'package:cabine_flow/shared/widgets/design_system/izy_tel_shell.dart';
import 'package:flutter/material.dart';

class CustomerFlowScaffold extends StatelessWidget {
  const CustomerFlowScaffold({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.title,
    required this.content,
    required this.onContinue,
    this.subtitle,
    this.titleTextAlign = TextAlign.start,
    this.onTopBack,
    this.onBottomBack,
    this.footer,
    this.backLabel = 'Retour',
    this.continueLabel = 'Suivant',
    this.isContinueEnabled = true,
    this.isContinueLoading = false,
  });

  final int currentStep;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final TextAlign titleTextAlign;
  final Widget content;
  final VoidCallback onContinue;
  final VoidCallback? onTopBack;
  final VoidCallback? onBottomBack;
  final Widget? footer;
  final String backLabel;
  final String continueLabel;
  final bool isContinueEnabled;
  final bool isContinueLoading;

  @override
  Widget build(BuildContext context) {
    final String? normalizedSubtitle = subtitle?.trim();
    final String? visibleSubtitle =
        normalizedSubtitle == null || normalizedSubtitle.isEmpty
        ? null
        : normalizedSubtitle;

    return IzyTelShell(
      title: 'IzyTel',
      onBack: onTopBack,
      showBackButton: onTopBack != null,
      maxContentWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomerProgressIndicator(
                    currentStep: currentStep,
                    totalSteps: totalSteps,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: titleTextAlign,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (visibleSubtitle != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      visibleSubtitle,
                      textAlign: titleTextAlign,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 24),
                  content,
                  if (footer != null) ...[const SizedBox(height: 32), footer!],
                ],
              ),
            ),
          ),
          CustomerBottomActions(
            onBack: onBottomBack,
            onContinue: onContinue,
            backLabel: backLabel,
            continueLabel: continueLabel,
            isContinueEnabled: isContinueEnabled,
            isLoading: isContinueLoading,
          ),
        ],
      ),
    );
  }
}
