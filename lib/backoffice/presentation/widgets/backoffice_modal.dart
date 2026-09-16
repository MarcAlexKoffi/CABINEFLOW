import 'dart:ui';

import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Ouvre une couche modale premium commune au Back-office IzyTel.
///
/// Le voile, le flou, l'animation et les contraintes sont centralises ici
/// afin d'eviter les AlertDialog disparates et les overflows Web.
Future<T?> showBackofficeModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Fermer la fenêtre',
    barrierColor: const Color(0x7A0F172A),
    transitionDuration: const Duration(milliseconds: 190),
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      final Widget content = SafeArea(
        minimum: const EdgeInsets.all(12),
        child: builder(dialogContext),
      );

      // BackdropFilter est couteux sur Flutter Web et provoque des saccades
      // pendant le scroll des modals. Le voile sombre reste actif sur Web ;
      // le flou est conserve sur les plateformes natives.
      if (kIsWeb) return content;
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
        child: content,
      );
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .965, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class BackofficeModalShell extends StatelessWidget {
  const BackofficeModalShell({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.icon,
    this.iconColor = BackofficePalette.primary,
    this.chips = const <Widget>[],
    this.actions = const <Widget>[],
    this.maxWidth = 760,
    this.bodyPadding = const EdgeInsets.fromLTRB(24, 22, 24, 24),
    this.closeValue,
    this.showCloseButton = true,
  }) : assert(leading == null || icon == null);

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? leading;
  final IconData? icon;
  final Color iconColor;
  final List<Widget> chips;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsets bodyPadding;
  final Object? closeValue;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final Size viewport = MediaQuery.sizeOf(context);
    final bool compact = viewport.width < 640;
    final double verticalMargin = compact ? 16 : 32;
    final double maxHeight = (viewport.height - verticalMargin).clamp(240, 980).toDouble();

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: BackofficePalette.surface,
              borderRadius: BorderRadius.circular(compact ? 20 : 24),
              border: Border.all(color: const Color(0xFFD8E2F1)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x35102040),
                  blurRadius: 54,
                  spreadRadius: -8,
                  offset: Offset(0, 24),
                ),
                BoxShadow(
                  color: Color(0x141D4ED8),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _ModalHeader(
                  title: title,
                  subtitle: subtitle,
                  leading: leading,
                  icon: icon,
                  iconColor: iconColor,
                  chips: chips,
                  showCloseButton: showCloseButton,
                  onClose: showCloseButton
                      ? () => Navigator.of(context).pop(closeValue)
                      : null,
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: bodyPadding,
                    physics: const ClampingScrollPhysics(),
                    child: body,
                  ),
                ),
                if (actions.isNotEmpty) ...<Widget>[
                  const Divider(height: 1),
                  _ModalFooter(actions: actions),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.icon,
    required this.iconColor,
    required this.chips,
    required this.showCloseButton,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? icon;
  final Color iconColor;
  final List<Widget> chips;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 640;
    final Widget resolvedLeading = leading ??
        Container(
          width: compact ? 44 : 50,
          height: compact ? 44 : 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: iconColor.withValues(alpha: .14)),
          ),
          child: Icon(
            icon ?? Symbols.info_rounded,
            color: iconColor,
            size: compact ? 23 : 26,
            fill: 1,
          ),
        );

    return Container(
      width: double.infinity,
      color: const Color(0xFFFCFDFF),
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 24,
        compact ? 17 : 21,
        compact ? 12 : 16,
        compact ? 16 : 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          resolvedLeading,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.25,
                      ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BackofficePalette.muted,
                          height: 1.4,
                        ),
                  ),
                ],
                if (chips.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(spacing: 7, runSpacing: 7, children: chips),
                ],
              ],
            ),
          ),
          if (showCloseButton) ...<Widget>[
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Fermer',
              onPressed: onClose,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF2F5FA),
                foregroundColor: BackofficePalette.muted,
              ),
              icon: const Icon(Symbols.close_rounded, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModalFooter extends StatelessWidget {
  const _ModalFooter({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 560;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        14,
        compact ? 16 : 24,
        16,
      ),
      color: const Color(0xFFFCFDFF),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: actions,
      ),
    );
  }
}

class BackofficeModalSection extends StatelessWidget {
  const BackofficeModalSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.tone = BackofficePalette.primary,
    this.backgroundColor,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final IconData? icon;
  final Color tone;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: backgroundColor ?? BackofficePalette.surfaceAlt,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: BackofficePalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 19, color: tone, fill: 1),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: BackofficePalette.ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (subtitle?.trim().isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BackofficePalette.muted,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class BackofficeInfoItem {
  const BackofficeInfoItem({
    required this.label,
    required this.value,
    this.icon,
    this.emphasis = false,
    this.selectable = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool emphasis;
  final bool selectable;
}

class BackofficeInfoGrid extends StatelessWidget {
  const BackofficeInfoGrid({
    super.key,
    required this.items,
    this.minItemWidth = 230,
  });

  final List<BackofficeInfoItem> items;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= (minItemWidth * 2 + 12) ? 2 : 1;
        const double gap = 10;
        final double itemWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (BackofficeInfoItem item) => SizedBox(
                  width: itemWidth,
                  child: _InfoTile(item: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.item});

  final BackofficeInfoItem item;

  @override
  Widget build(BuildContext context) {
    final TextStyle? valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: BackofficePalette.ink,
          fontWeight: item.emphasis ? FontWeight.w900 : FontWeight.w700,
          height: 1.35,
        );
    final Widget value = item.selectable
        ? SelectableText(item.value, style: valueStyle)
        : Text(item.value, style: valueStyle);

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE3E9F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BackofficePalette.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, size: 17, color: BackofficePalette.primary),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BackofficePalette.faint,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .45,
                      ),
                ),
                const SizedBox(height: 4),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BackofficeModalHero extends StatelessWidget {
  const BackofficeModalHero({
    super.key,
    required this.leading,
    required this.eyebrow,
    required this.value,
    required this.caption,
    this.trailing,
  });

  final Widget leading;
  final String eyebrow;
  final String value;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFFFFFF), Color(0xFFF3F7FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE7F7)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 520;
          final Widget copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: BackofficePalette.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: BackofficePalette.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.45,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BackofficePalette.muted,
                    ),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    leading,
                    const SizedBox(width: 13),
                    Expanded(child: copy),
                  ],
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(height: 13),
                  trailing!,
                ],
              ],
            );
          }
          return Row(
            children: <Widget>[
              leading,
              const SizedBox(width: 15),
              Expanded(child: copy),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 16),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}
