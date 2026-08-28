import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_bottom_actions.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_flow_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('le parcours garde son contenu visible et ses actions en bas', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const Key contentKey = Key('flow-test-content');

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerFlowScaffold(
          currentStep: 2,
          totalSteps: 8,
          title: 'Choisissez votre service',
          subtitle: 'Sous-titre de test',
          onTopBack: () {},
          onBottomBack: () {},
          onContinue: () {},
          content: const SizedBox(
            key: contentKey,
            height: 240,
            child: Text('CONTENU DU PARCOURS'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('IzyTel'), findsOneWidget);
    expect(find.text('Choisissez votre service'), findsOneWidget);
    expect(find.text('CONTENU DU PARCOURS'), findsOneWidget);
    expect(find.byKey(contentKey), findsOneWidget);

    final Size actionsSize = tester.getSize(find.byType(CustomerBottomActions));
    final Rect actionsRect = tester.getRect(find.byType(CustomerBottomActions));
    final Rect contentRect = tester.getRect(find.byKey(contentKey));

    expect(actionsSize.height, lessThan(120));
    expect(actionsRect.bottom, closeTo(844, 1));
    expect(contentRect.top, lessThan(actionsRect.top));
    expect(tester.takeException(), isNull);
  });
}
