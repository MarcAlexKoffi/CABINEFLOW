import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class IzyTelCard extends StatefulWidget {
  const IzyTelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.isSelected = false,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 18,
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
  State<IzyTelCard> createState() => _IzyTelCardState();
}

class _IzyTelCardState extends State<IzyTelCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color resolvedBackground =
        widget.backgroundColor ??
        (widget.isSelected
            ? CustomerAppColors.primarySoft
            : CustomerAppColors.surfaceContainerLowest);
    final Color resolvedBorder =
        widget.borderColor ??
        (widget.isSelected
            ? CustomerAppColors.primary
            : _isHovered && widget.onTap != null
            ? CustomerAppColors.primary.withValues(alpha: 0.24)
            : CustomerAppColors.outlineSoft);

    final List<BoxShadow>? shadows = widget.showShadow
        ? <BoxShadow>[
            BoxShadow(
              color: _isHovered && widget.onTap != null
                  ? const Color(0x160757C9)
                  : const Color(0x0A0F172A),
              blurRadius: _isHovered && widget.onTap != null ? 26 : 18,
              offset: Offset(0, _isHovered && widget.onTap != null ? 10 : 7),
            ),
          ]
        : null;

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: widget.onTap == null
          ? null
          : (_) => setState(() => _isHovered = true),
      onExit: widget.onTap == null
          ? null
          : (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && widget.onTap != null ? 1.008 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: resolvedBackground,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: resolvedBorder,
              width: widget.isSelected ? 1.6 : 1,
            ),
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: CustomerAppColors.primary.withValues(alpha: 0.07),
              highlightColor: CustomerAppColors.primary.withValues(alpha: 0.035),
              hoverColor: Colors.transparent,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}
