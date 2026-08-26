import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_bottom_actions.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_progress_indicator.dart';
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
    this.continueLabel = 'Continuer',
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

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: CustomerAppColors.surface,
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0x33C2C6D8)),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _CustomerTopBar(onBack: onTopBack),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            18,
                            20,
                            footer != null ? 0 : 24,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              CustomerProgressIndicator(
                                currentStep: currentStep,
                                totalSteps: totalSteps,
                              ),
                              const SizedBox(height: 34),
                              Text(
                                title,
                                textAlign: titleTextAlign,
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              if (visibleSubtitle != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  visibleSubtitle,
                                  textAlign: titleTextAlign,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                              const SizedBox(height: 26),
                              content,
                            ]),
                          ),
                        ),
                        if (footer != null)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            fillOverscroll: true,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                36,
                                20,
                                24,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: footer!,
                              ),
                            ),
                          ),
                      ],
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
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerTopBar extends StatelessWidget {
  const _CustomerTopBar({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: 'Retour',
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: CustomerAppColors.primary,
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'CabineFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CustomerAppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}
