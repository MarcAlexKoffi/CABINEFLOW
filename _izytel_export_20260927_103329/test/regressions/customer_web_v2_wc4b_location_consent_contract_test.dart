import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Client V2 - WC4B geolocalisation consentie', () {
    late String flow;
    late String summary;
    late String locationDialog;
    late String locationWeb;
    late String viewModel;
    late String migration;

    setUpAll(() {
      flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      summary = File(
        'lib/features/customer_order/presentation/pages/customer_summary_page.dart',
      ).readAsStringSync();
      locationDialog = File(
        'lib/features/customer_order/presentation/widgets/customer_location_consent_dialog.dart',
      ).readAsStringSync();
      locationWeb = File(
        'lib/features/customer_order/data/geolocation/customer_geolocation_web.dart',
      ).readAsStringSync();
      viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();
      migration = File(
        'supabase/migrations/20260927002759_wc4b_location_consent_zone_id.sql',
      ).readAsStringSync();
    });

    test('une popup premium propose la localisation a la premiere visite', () {
      expect(flow, contains('_initialLocationPromptShown'));
      expect(flow, contains('CustomerLocationPromptMoment.firstVisit'));
      expect(flow, contains('_showInitialLocationPrompt'));
      expect(locationDialog, contains("'Autoriser la localisation ?'"));
      expect(locationDialog, contains("'Autoriser ma position'"));
      expect(locationDialog, contains("'Plus tard'"));
      expect(locationDialog, contains('barrierDismissible: false'));
    });

    test('le recapitulatif ne montre plus aucun bloc permanent de permission', () {
      expect(summary, isNot(contains('CustomerLocationConsentCard')));
      expect(summary, isNot(contains("'Localisation de la demande'")));
      expect(summary, contains('CustomerLocationPromptMoment.beforePayment'));
    });

    test('une localisation deja accordee ne declenche rien avant paiement', () {
      expect(
        summary,
        contains('widget.viewModel.orderContext.hasLocation'),
      );
      expect(summary, contains('return true;'));
      expect(viewModel, contains('applyOrderContext'));
    });

    test('sans localisation la popup est reproposee au passage au paiement', () {
      expect(summary, contains('_confirmLocationBeforePayment'));
      expect(summary, contains('showCustomerLocationConsentDialog'));
      expect(locationDialog, contains("'Localiser cette demande ?'"));
      expect(locationDialog, contains("'Continuer sans localisation'"));
    });

    test('le navigateur ne demande la position qu apres action client', () {
      expect(locationWeb, contains('getCurrentPosition'));
      expect(locationDialog, contains('onPressed: _isRequesting ? null : _requestLocation'));
      expect(flow, isNot(contains('getCurrentPosition')));
      expect(summary, isNot(contains('getCurrentPosition')));
    });

    test('acceptation refus et indisponibilite restent dans le contexte', () {
      expect(locationWeb, contains('CustomerLocationCapture.granted'));
      expect(locationWeb, contains('CustomerLocationCapture.denied'));
      expect(locationWeb, contains('CustomerLocationCapture.unavailable'));
      expect(flow, contains('capture.applyTo(_viewModel.orderContext)'));
      expect(summary, contains('capture.applyTo(widget.viewModel.orderContext)'));
      expect(viewModel, contains('_registerOrderContextSafely(currentOrder)'));
    });

    test('zoneId vient de la position reelle et jamais du QR', () {
      expect(migration, contains('zone_id'));
      expect(migration, contains('from public.territory_zones zone'));
      expect(migration, contains('zone.is_active = true'));
      expect(migration, contains('radians(zone.latitude - p_latitude)'));
      expect(migration, contains('source_code'));
      expect(migration, isNot(contains('zone_id = source_code')));
      expect(
        locationDialog,
        contains('QR code reste uniquement une source d’acquisition'),
      );
    });

    test('aucun nouveau flux Firestore nest ajoute', () {
      expect(migration, isNot(contains('firestore')));
      expect(locationWeb, isNot(contains('cloud_firestore')));
      expect(locationDialog, isNot(contains('cloud_firestore')));
    });
  });
}
