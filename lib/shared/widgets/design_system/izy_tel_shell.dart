import 'package:cabine_flow/core/theme/customer_app_colors.dart';
import 'package:flutter/material.dart';

class IzyTelShell extends StatelessWidget {
  const IzyTelShell({
    super.key,
    required this.child,
    this.title = 'IzyTel',
    this.showBackButton = true,
    this.showMenuButton = false,
    this.onBack,
    this.onMenu,
    this.actions,
    this.bottomNavigationBar,
    this.drawer,
    this.maxContentWidth = 1180,
    this.centerContent = true,
  });

  final Widget child;
  final String title;
  final bool showBackButton;
  final bool showMenuButton;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final double maxContentWidth;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 900;

    final Widget constrainedBody = SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double contentWidth = constraints.maxWidth > maxContentWidth
              ? maxContentWidth
              : constraints.maxWidth;
          return Align(
            alignment: centerContent ? Alignment.topCenter : Alignment.topLeft,
            child: SizedBox(
              width: contentWidth,
              height: constraints.maxHeight,
              child: child,
            ),
          );
        },
      ),
    );

    final Widget body = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFFBFDFF),
            CustomerAppColors.background,
          ],
          stops: <double>[0, 0.42],
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (desktop) ...<Widget>[
            const Positioned(
              right: -180,
              top: -240,
              child: _AmbientCircle(
                size: 520,
                color: Color(0x120757C9),
              ),
            ),
            const Positioned(
              left: -210,
              bottom: -300,
              child: _AmbientCircle(
                size: 560,
                color: Color(0x0D29B6F6),
              ),
            ),
          ],
          Positioned.fill(child: constrainedBody),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        toolbarHeight: desktop ? 70 : 62,
        backgroundColor: Colors.white.withValues(alpha: 0.97),
        titleSpacing: showBackButton || showMenuButton ? 0 : desktop ? 24 : 14,
        title: _ShellTitle(title: title, desktop: desktop),
        leading: showBackButton
            ? IconButton(
                tooltip: 'Retour',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : showMenuButton
            ? Builder(
                builder: (BuildContext scaffoldContext) {
                  return IconButton(
                    tooltip: 'Menu',
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: drawer != null
                        ? () => Scaffold.of(scaffoldContext).openDrawer()
                        : onMenu,
                  );
                },
              )
            : null,
        actions: actions,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: CustomerAppColors.outlineSoft),
        ),
      ),
      drawer: drawer,
      drawerScrimColor: const Color(0x660A1B34),
      body: body,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class _ShellTitle extends StatelessWidget {
  const _ShellTitle({required this.title, required this.desktop});

  final String title;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final bool brandOnly = title.trim().toLowerCase() == 'izytel';

    if (!desktop && !brandOnly) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: CustomerAppColors.onSurface,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: desktop ? 34 : 30,
          child: Image.asset(
            'assets/images/izyTel_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, _, _) => const Icon(
              Icons.bolt_rounded,
              color: CustomerAppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'IzyTel',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: CustomerAppColors.primaryDeep,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
          ),
        ),
        if (!brandOnly) ...<Widget>[
          const SizedBox(width: 12),
          Container(
            width: 1,
            height: 22,
            color: CustomerAppColors.outlineSoft,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: CustomerAppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AmbientCircle extends StatelessWidget {
  const _AmbientCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
