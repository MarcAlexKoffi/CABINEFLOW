import 'package:cabine_flow/core/theme/customer_app_colors.dart';
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
      maxContentWidth: 860,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= 760;
          final EdgeInsets contentPadding = EdgeInsets.fromLTRB(
            desktop ? 36 : 18,
            desktop ? 30 : 20,
            desktop ? 36 : 18,
            desktop ? 38 : 28,
          );

          final Widget flowContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CustomerProgressIndicator(
                currentStep: currentStep,
                totalSteps: totalSteps,
              ),
              SizedBox(height: desktop ? 30 : 26),
              Text(
                title,
                textAlign: titleTextAlign,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: CustomerAppColors.primaryDeep,
                ),
              ),
              if (visibleSubtitle != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  visibleSubtitle,
                  textAlign: titleTextAlign,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              SizedBox(height: desktop ? 28 : 24),
              content,
              if (footer != null) ...<Widget>[
                const SizedBox(height: 32),
                footer!,
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: contentPadding,
                  child: desktop
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: CustomerAppColors.outlineSoft,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x0F0F172A),
                                blurRadius: 28,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: flowContent,
                          ),
                        )
                      : flowContent,
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
          );
        },
      ),
    );
  }
}
