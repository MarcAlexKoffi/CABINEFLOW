import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the shell in charge of Android Back, even when an inactive tab emits
/// a NavigationNotification saying that its own stack is empty. Flutter's root
/// Navigator otherwise forwards that notification to the Android embedding.
class IzyTelBackNavigationBoundary extends StatelessWidget {
  const IzyTelBackNavigationBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        if (notification.canHandlePop) return false;
        const NavigationNotification(canHandlePop: true).dispatch(context);
        return true;
      },
      child: child,
    );
  }
}

/// Politique unique du bouton Retour Android pour les shells mobiles IzyTel.
///
/// Ordre strict :
/// 1. depiler une sous-page du Navigator de l'onglet actif ;
/// 2. si l'onglet actif est a sa racine et n'est pas Accueil, revenir a Accueil ;
/// 3. uniquement depuis Accueil a sa racine, laisser Android fermer/minimiser
///    l'application.
///
/// Le [PopScope] bloque le pop automatique de la route racine afin qu'un geste
/// Retour ne puisse jamais sauter la pile du Navigator imbrique.
class IzyTelMobileBackScope extends StatefulWidget {
  const IzyTelMobileBackScope({
    super.key,
    required this.activeNavigatorKey,
    required this.isHomeTab,
    required this.onReturnHome,
    required this.child,
    this.onExit,
  });

  final GlobalKey<NavigatorState> activeNavigatorKey;
  final bool isHomeTab;
  final VoidCallback onReturnHome;
  final Widget child;
  final Future<void> Function()? onExit;

  @override
  State<IzyTelMobileBackScope> createState() => _IzyTelMobileBackScopeState();
}

class _IzyTelMobileBackScopeState extends State<IzyTelMobileBackScope> {
  bool _handlingBack = false;

  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      final NavigatorState? activeNavigator =
          widget.activeNavigatorKey.currentState;

      if (activeNavigator != null && await activeNavigator.maybePop()) {
        return;
      }

      if (!widget.isHomeTab) {
        widget.onReturnHome();
        return;
      }

      final Future<void> Function()? onExit = widget.onExit;
      if (onExit != null) {
        await onExit();
      } else {
        await SystemNavigator.pop();
      }
    } finally {
      _handlingBack = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IzyTelBackNavigationBoundary(
      child: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (didPop) return;
          unawaited(_handleBack());
        },
        child: widget.child,
      ),
    );
  }
}
