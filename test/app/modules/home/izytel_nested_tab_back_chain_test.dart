import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Retour Android: sous-page -> onglet -> Accueil -> double sortie',
    (WidgetTester tester) async {
      final GlobalKey<_BackChainHarnessState> harnessKey =
          GlobalKey<_BackChainHarnessState>();

      await tester.pumpWidget(
        MaterialApp(home: _BackChainHarness(key: harnessKey)),
      );
      await tester.pumpAndSettle();

      final _BackChainHarnessState state = harnessKey.currentState!;
      expect(state.selectedIndex, 1);
      expect(state._keys[1].currentState, isNotNull);
      expect(state._keys[1].currentState!.canPop(), isFalse);

      state.openSubPage();
      await tester.pumpAndSettle();
      expect(find.text('Messagerie clients'), findsOneWidget);

      // 1. Le gestionnaire unique depile seulement la sous-page active.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state._keys[1].currentState!.canPop(), isFalse);
      expect(state.selectedIndex, 1);
      expect(state.exitCount, 0);
      await tester.pump(const Duration(milliseconds: 300));

      // 2. A la racine de Plus, le Retour du shell ramene a Accueil.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(state.selectedIndex, 0);
      expect(state._keys[0].currentState, isNotNull);
      expect(state._keys[0].currentState!.canPop(), isFalse);
      expect(state.exitCount, 0);
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Premier Retour depuis Accueil arme seulement la sortie.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(state.exitCount, 0);
      expect(state.exitArmed, isTrue);
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Seul le second Retour depuis Accueil quitte.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(state.exitCount, 1);

      // Vide le debounce de 250 ms lance dans le finally de _handleRootBack.
      // Sans cela Flutter Test detecte correctement un Timer encore actif alors
      // que le comportement fonctionnel a deja ete valide.
      await tester.pump(const Duration(milliseconds: 300));
      expect(state._handlingRootBack, isFalse);
    },
  );
}

class _BackChainHarness extends StatefulWidget {
  const _BackChainHarness({super.key});

  @override
  State<_BackChainHarness> createState() => _BackChainHarnessState();
}

class _BackChainHarnessState extends State<_BackChainHarness> {
  final List<GlobalKey<NavigatorState>> _keys = <GlobalKey<NavigatorState>>[
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  int selectedIndex = 1;
  int exitCount = 0;
  DateTime? _lastBackPressAt;
  bool _handlingRootBack = false;

  bool get exitArmed => _lastBackPressAt != null;

  void _disarmExit() {
    _lastBackPressAt = null;
  }

  void openSubPage() {
    _disarmExit();
    _keys[1].currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('Messagerie clients'))),
      ),
    );
  }

  Future<void> _handleRootBack() async {
    if (_handlingRootBack) return;
    _handlingRootBack = true;
    try {
      final NavigatorState? current = _keys[selectedIndex].currentState;
      if (current != null && current.canPop()) {
        _disarmExit();
        await current.maybePop();
        return;
      }

      if (selectedIndex != 0) {
        _disarmExit();
        setState(() => selectedIndex = 0);
        return;
      }

      final DateTime now = DateTime.now();
      final DateTime? previous = _lastBackPressAt;
      if (previous == null ||
          now.difference(previous) > const Duration(seconds: 2)) {
        _lastBackPressAt = now;
        return;
      }

      exitCount++;
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      _handlingRootBack = false;
    }
  }

  Widget _tab(int index, String label) {
    return Navigator(
      key: _keys[index],
      initialRoute: '/',
      onGenerateInitialRoutes: (
        NavigatorState navigator,
        String initialRouteName,
      ) {
        return <Route<void>>[
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => Scaffold(
              body: Center(child: Text(label)),
            ),
          ),
        ];
      },
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Center(child: Text(label))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) unawaited(_handleRootBack());
      },
      child: IndexedStack(
        index: selectedIndex,
        children: <Widget>[_tab(0, 'Accueil'), _tab(1, 'Plus')],
      ),
    );
  }
}
