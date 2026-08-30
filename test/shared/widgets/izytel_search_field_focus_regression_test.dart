import 'package:cabine_flow/shared/widgets/izytel/izytel_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('IzyTelSearchField garde le focus pendant les rebuilds', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    String query = '';

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Scaffold(
              body: IzyTelSearchField(
                controller: controller,
                hintText: 'Rechercher',
                onChanged: (String value) {
                  setState(() => query = value);
                },
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    for (final String value in <String>[
      'o',
      'or',
      'ora',
      'oran',
      'orang',
      'orange',
    ]) {
      await tester.enterText(find.byType(TextField), value);
      await tester.pump();
      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);
    }

    expect(query, 'orange');
    expect(controller.text, 'orange');
  });
}
