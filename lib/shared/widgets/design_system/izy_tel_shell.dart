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
    final Widget body = SafeArea(
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

    return Scaffold(
      backgroundColor: CustomerAppColors.background,
      appBar: AppBar(
        toolbarHeight: 62,
        backgroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(
            color: CustomerAppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.35,
          ),
        ),
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
