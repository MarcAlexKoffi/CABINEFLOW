import 'package:cabine_flow/features/dashboard/presentation/widgets/dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PriorityOrderItemCard reste sans overflow à 360 px', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: PriorityOrderItemCard(
              reference: 'CF-20260827-RESP01',
              phoneNumber: '+225 01 52 36 82 90',
              operationLabel: 'Moov Folie Appels 70 min - 5 jours',
              amount: 500,
              channel: 'moov',
              statusLabel: 'ready',
              actionLabel: 'Traiter',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Moov Folie Appels 70 min - 5 jours'), findsOneWidget);
    expect(find.text('Traiter'), findsOneWidget);
  });
}
