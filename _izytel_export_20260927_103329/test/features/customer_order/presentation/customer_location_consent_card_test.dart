import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';
import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/customer_order/presentation/widgets/customer_location_consent_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('WC4B le client partage explicitement sa position', (
    WidgetTester tester,
  ) async {
    final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
      orderRepository: FakeCustomerOrderRepository(),
      orderContext: const CustomerOrderContextDraft(sourceCode: 'QR-TEST-01'),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerLocationConsentCard(
            viewModel: viewModel,
            geolocationService: _GrantedGeolocationService(),
          ),
        ),
      ),
    );

    expect(find.text('Optionnel'), findsOneWidget);
    expect(find.text('Partager ma position'), findsOneWidget);

    await tester.tap(find.text('Partager ma position'));
    await tester.pumpAndSettle();

    expect(viewModel.orderContext.locationStatus, CustomerLocationStatus.granted);
    expect(viewModel.orderContext.sourceCode, 'QR-TEST-01');
    expect(viewModel.orderContext.latitude, 6.8276);
    expect(find.textContaining('Position partagée'), findsOneWidget);
  });

  testWidgets('WC4B le refus ne bloque pas et conserve la source', (
    WidgetTester tester,
  ) async {
    final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
      orderRepository: FakeCustomerOrderRepository(),
      orderContext: const CustomerOrderContextDraft(sourceCode: 'DIRECT-TEST'),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerLocationConsentCard(
            viewModel: viewModel,
            geolocationService: _GrantedGeolocationService(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Continuer sans localisation'));
    await tester.pumpAndSettle();

    expect(viewModel.orderContext.locationStatus, CustomerLocationStatus.denied);
    expect(viewModel.orderContext.sourceCode, 'DIRECT-TEST');
    expect(viewModel.orderContext.hasLocation, isFalse);
    expect(find.textContaining('peut continuer normalement'), findsOneWidget);
  });
}

class _GrantedGeolocationService implements CustomerGeolocationService {
  @override
  Future<CustomerLocationCapture> requestCurrentLocation() async {
    return CustomerLocationCapture.granted(
      latitude: 6.8276,
      longitude: -5.2893,
      accuracyMeters: 12,
      capturedAt: DateTime.utc(2026, 9, 27, 0, 30),
    );
  }
}
