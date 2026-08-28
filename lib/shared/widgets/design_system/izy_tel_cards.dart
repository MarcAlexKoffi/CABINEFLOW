import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class IzyTelCard extends StatelessWidget {
  const IzyTelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.isSelected = false,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 16,
    this.showShadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final Color resolvedBackground =
        backgroundColor ??
        (isSelected
            ? CustomerAppColors.primarySoft
            : CustomerAppColors.surfaceContainerLowest);
    final Color resolvedBorder =
        borderColor ??
        (isSelected
            ? CustomerAppColors.primary
            : CustomerAppColors.outlineSoft);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: resolvedBorder, width: isSelected ? 1.6 : 1),
        boxShadow: showShadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: CustomerAppColors.primary.withValues(alpha: 0.07),
          highlightColor: CustomerAppColors.primary.withValues(alpha: 0.035),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
