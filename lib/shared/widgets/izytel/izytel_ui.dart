import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:cabine_flow/core/theme/izytel_design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class IzyTelSurface extends StatelessWidget {
  const IzyTelSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(IzyTelSpacing.md),
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.radius = IzyTelRadii.largeCard,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final Widget container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? IzyTelColors.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? IzyTelColors.outline),
        boxShadow: const [
          BoxShadow(
            color: IzyTelColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return container;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: container,
      ),
    );
  }
}

class IzyTelStatusPill extends StatelessWidget {
  const IzyTelStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: IzyTelIconSize.info, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            fit: FlexFit.loose,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontSize: IzyTelTypeScale.micro,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IzyTelSectionHeader extends StatelessWidget {
  const IzyTelSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: IzyTelTypeScale.title3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class IzyTelAvatar extends StatelessWidget {
  const IzyTelAvatar({
    super.key,
    required this.name,
    this.onTap,
    this.size = 42,
    this.initialsOverride,
  });

  final String name;
  final VoidCallback? onTap;
  final double size;
  final String? initialsOverride;

  String get _initials {
    final String? override = initialsOverride?.trim();
    if (override != null && override.isNotEmpty) {
      return override.toUpperCase();
    }
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: IzyTelColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (onTap == null) return avatar;
    return InkResponse(onTap: onTap, radius: size * .7, child: avatar);
  }
}

Future<void> showIzyTelAccountSheet({
  required BuildContext context,
  required String name,
  required String role,
  required List<IzyTelAccountAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: const BoxDecoration(
          color: IzyTelColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(IzyTelRadii.sheet)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: IzyTelColors.outlineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                IzyTelAvatar(name: name, size: 48),
                const SizedBox(width: 12),
                Flexible(
                  fit: FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role,
                        style: Theme.of(sheetContext).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            for (final IzyTelAccountAction action in actions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  action.icon,
                  color: action.destructive
                      ? IzyTelColors.error
                      : IzyTelColors.textSecondary,
                ),
                title: Text(
                  action.label,
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                    color: action.destructive
                        ? IzyTelColors.error
                        : IzyTelColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: action.destructive
                    ? null
                    : const Icon(
                        Symbols.chevron_right_rounded,
                        color: IzyTelColors.textMuted,
                      ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  action.onTap();
                },
              ),
          ],
        ),
      );
    },
  );
}

class IzyTelAccountAction {
  const IzyTelAccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

class IzyTelPageHeader extends StatelessWidget {
  const IzyTelPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <Widget>[],
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: IzyTelSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.35,
                  color: IzyTelColors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: IzyTelColors.textSecondary,
                    fontSize: IzyTelTypeScale.label,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: IzyTelSpacing.sm),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ],
    );
  }
}

class IzyTelSearchField extends StatefulWidget {
  const IzyTelSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  State<IzyTelSearchField> createState() => _IzyTelSearchFieldState();
}

class _IzyTelSearchFieldState extends State<IzyTelSearchField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'IzyTelSearchField');
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant IzyTelSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.done,
      keyboardType: TextInputType.text,
      enableInteractiveSelection: true,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(
          Symbols.search_rounded,
          size: IzyTelIconSize.action,
        ),
        suffixIcon: widget.controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Effacer',
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                  widget.onClear?.call();
                  _focusNode.requestFocus();
                },
                icon: const Icon(
                  Symbols.close_rounded,
                  size: IzyTelIconSize.action,
                ),
              ),
      ),
    );
  }
}

class IzyTelFilterPill extends StatelessWidget {
  const IzyTelFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
    this.selectedColor = IzyTelColors.primary,
    this.softColor = IzyTelColors.primarySoft,
    this.tintedWhenIdle = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  final Color selectedColor;
  final Color softColor;
  final bool tintedWhenIdle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? selectedColor
          : tintedWhenIdle
          ? softColor
          : IzyTelColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? selectedColor
                  : tintedWhenIdle
                  ? selectedColor.withAlpha(48)
                  : IzyTelColors.outline,
            ),
            boxShadow: selected
                ? const <BoxShadow>[]
                : const <BoxShadow>[
                    BoxShadow(
                      color: IzyTelColors.shadow,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: IzyTelIconSize.info,
                  color: selected ? Colors.white : selectedColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : IzyTelColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withAlpha(42) : softColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? Colors.white : selectedColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class IzyTelEmptyState extends StatelessWidget {
  const IzyTelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IzyTelSpacing.xl,
        vertical: IzyTelSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: IzyTelColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: IzyTelColors.primary, size: 28),
          ),
          const SizedBox(height: IzyTelSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: IzyTelColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: IzyTelColors.textSecondary,
              fontSize: IzyTelTypeScale.label,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: IzyTelSpacing.md),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class IzyTelMenuRow extends StatelessWidget {
  const IzyTelMenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.iconColor = IzyTelColors.primary,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;
  final Color iconColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = destructive ? IzyTelColors.error : iconColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveColor.withAlpha(22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: effectiveColor, size: 21),
              ),
              const SizedBox(width: 12),
              Flexible(
                fit: FlexFit.tight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: destructive
                            ? IzyTelColors.error
                            : IzyTelColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: IzyTelColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null && badge!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: IzyTelColors.warningSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: IzyTelColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (!destructive) ...[
                const SizedBox(width: 8),
                const Icon(
                  Symbols.chevron_right_rounded,
                  color: IzyTelColors.textMuted,
                  size: 21,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
