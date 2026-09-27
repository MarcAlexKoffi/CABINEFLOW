import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_location_consent_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WC4B popup premiere visite autorise puis disparait', (
    WidgetTester tester,
  ) async {
    CustomerLocationCapture? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showCustomerLocationConsentDialog(
                      context: context,
                      moment: CustomerLocationPromptMoment.firstVisit,
                      geolocationService: _GrantedGeolocationService(),
                    );
                  },
                  child: const Text('Ouvrir'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Autoriser la localisation ?'), findsOneWidget);
    expect(find.text('Autoriser ma position'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);

    await tester.tap(find.text('Autoriser ma position'));
    await tester.pumpAndSettle();

    expect(find.text('Autoriser la localisation ?'), findsNothing);
    expect(result?.isGranted, isTrue);
  });

  testWidgets('WC4B popup paiement permet de continuer sans localisation', (
    WidgetTester tester,
  ) async {
    CustomerLocationCapture? result = const CustomerLocationCapture.denied();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    result = await showCustomerLocationConsentDialog(
                      context: context,
                      moment: CustomerLocationPromptMoment.beforePayment,
                      geolocationService: _GrantedGeolocationService(),
                    );
                  },
                  child: const Text('Ouvrir'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Localiser cette demande ?'), findsOneWidget);
    expect(find.text('Continuer sans localisation'), findsOneWidget);

    final Finder continueWithoutLocation = find.widgetWithText(
      OutlinedButton,
      'Continuer sans localisation',
    );
    await tester.ensureVisible(continueWithoutLocation);
    await tester.pumpAndSettle();
    await tester.tap(continueWithoutLocation);
    await tester.pumpAndSettle();

    expect(find.text('Localiser cette demande ?'), findsNothing);
    expect(result, isNull);
  });
}

class _GrantedGeolocationService implements CustomerGeolocationService {
  @override
  Future<CustomerLocationCapture> requestCurrentLocation() async {
    return CustomerLocationCapture.granted(
      latitude: 6.8276,
      longitude: -5.2893,
      accuracyMeters: 12,
      capturedAt: DateTime.utc(2026, 9, 27, 1, 30),
    );
  }
}
