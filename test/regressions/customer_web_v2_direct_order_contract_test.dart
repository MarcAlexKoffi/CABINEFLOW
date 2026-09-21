import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web Client V2 - parcours directs et catalogue', () {
    test('le parcours direct Transfert d unites reste sans choix d offre', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      final String offerPage = File(
        'lib/features/customer_order/presentation/pages/customer_offer_page.dart',
      ).readAsStringSync();
      final String viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();

      expect(flow, contains('_startServiceOrder(CustomerService service)'));
      expect(flow, contains('_viewModel.selectService(service);'));
      expect(offerPage, contains('CustomerService.unitTransfer'));
      expect(offerPage, contains('_buildTransferAmountForm()'));
      expect(viewModel, contains('case CustomerService.unitTransfer:'));
      expect(viewModel, contains('return (_draft.amount ?? 0) > 0;'));
      expect(viewModel, contains('clearOffer: true'));
    });

    test('une offre du catalogue garde son raccourci vers le beneficiaire', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      final String viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();

      expect(flow, contains('void _startOfferOrder(CustomerOffer offer)'));
      expect(flow, contains('_viewModel.selectOffer(offer);'));
      expect(viewModel, contains('int _nextStepAfterIdentity()'));
      expect(viewModel, contains('if (!canContinueFromOffer)'));
      expect(viewModel, contains('return 5;'));
    });

    test('la page beneficiaire reprend le contexte sans imposer de noms', () {
      final String beneficiaryPage = File(
        'lib/features/customer_order/presentation/pages/customer_beneficiary_page.dart',
      ).readAsStringSync();

      expect(beneficiaryPage, contains("'À qui envoyer les unités ?'"));
      expect(beneficiaryPage, contains("'À qui envoyer l’offre ?'"));
      expect(beneficiaryPage, contains('Numéros fréquents'));
      expect(beneficiaryPage, contains('_OrderContextCard'));
      expect(beneficiaryPage, contains('Continuer quand même'));
      expect(beneficiaryPage, isNot(contains('Marc Koffi')));
      expect(beneficiaryPage, isNot(contains('Awa Touré')));
      expect(beneficiaryPage, isNot(contains('Daniel Koné')));
    });
  });
}
