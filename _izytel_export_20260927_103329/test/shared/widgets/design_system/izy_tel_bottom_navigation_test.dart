import 'package:cabine_flow/shared/widgets/design_system/izy_tel_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'la navigation client reste compacte et laisse la place au contenu',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const Key bodyKey = Key('customer-body');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.expand(key: bodyKey),
            bottomNavigationBar: IzyTelBottomNavigation(
              current: IzyTelCustomerDestination.home,
              onHome: () {},
              onOffers: () {},
              onHistory: () {},
              onHelp: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      final Size navigationSize = tester.getSize(
        find.byType(IzyTelBottomNavigation),
      );
      final Size bodySize = tester.getSize(find.byKey(bodyKey));

      expect(navigationSize.height, lessThan(120));
      expect(bodySize.height, greaterThan(650));
    },
  );
}
