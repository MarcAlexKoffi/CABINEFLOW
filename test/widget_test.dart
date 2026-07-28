import 'package:cabine_flow/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('affiche correctement l’écran de démarrage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const CabineFlowApp());

    expect(find.text('CabineFlow'), findsOneWidget);
    expect(find.text('Vos commandes,\nsimplement organisées.'), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
  });
}
