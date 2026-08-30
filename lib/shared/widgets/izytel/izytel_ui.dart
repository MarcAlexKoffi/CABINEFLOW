import 'package:cabine_flow/core/theme/izytel_colors.dart';
import 'package:flutter/material.dart';

class IzyTelSurface extends StatelessWidget {
  const IzyTelSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.radius = 20,
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
            blurRadius: 24,
            offset: Offset(0, 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontSize: 8.8,
              fontWeight: FontWeight.w800,
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w800,
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
  });

  final String name;
  final VoidCallback? onTap;
  final double size;

  String get _initials {
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
          fontWeight: FontWeight.w800,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: action.destructive
                    ? null
                    : const Icon(
                        Icons.chevron_right_rounded,
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
