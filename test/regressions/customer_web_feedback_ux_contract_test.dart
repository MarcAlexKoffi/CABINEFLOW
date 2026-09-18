import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Web client - retours utilisateurs septembre 2026', () {
    test('le bénéficiaire est simplifié et utilise les commandes fréquentes', () {
      final String page = File(
        'lib/features/customer_order/presentation/pages/customer_beneficiary_page.dart',
      ).readAsStringSync();
      final String viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();

      expect(page, contains('suggestedBeneficiaryNumbers'));
      expect(page, isNot(contains('CustomerBeneficiaryTarget')));
      expect(page, isNot(contains('_confirmationController')));
      expect(viewModel, contains('beneficiarySuggestionMinimumOrders = 2'));
      expect(viewModel, contains('selectSuggestedBeneficiary'));
    });

    test('une offre préselectionnée saute service, réseau et forfait', () {
      final String viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();

      expect(viewModel, contains('_nextStepAfterIdentity()'));
      expect(viewModel, contains('if (_draft.service == null)'));
      expect(viewModel, contains('if (_draft.network == null)'));
      expect(viewModel, contains('if (!canContinueFromOffer)'));
      expect(viewModel, contains('return 5;'));
    });

    test('le retour de Wave ne rouvre plus un formulaire de déclaration', () {
      final String payment = File(
        'lib/features/customer_order/presentation/pages/customer_payment_page.dart',
      ).readAsStringSync();

      expect(payment, contains("'Confirmer le paiement'"));
      expect(payment, contains('TimeOfDay.now()'));
      expect(payment, isNot(contains('showModalBottomSheet')));
      expect(payment, isNot(contains('_PaymentDeclarationSheet')));
      expect(payment, isNot(contains('Confirmer ma déclaration')));
    });

    test('Retrouver ma commande utilise réseau, service et bénéficiaire', () {
      final String page = File(
        'lib/features/customer_order/presentation/pages/customer_order_recovery_page.dart',
      ).readAsStringSync();
      final String repository = File(
        'lib/features/customer_order/data/repositories/firestore_customer_order_repository.dart',
      ).readAsStringSync();

      expect(page, contains("_FieldLabel(text: 'Réseau')"));
      expect(page, contains("_FieldLabel(text: 'Type de commande')"));
      expect(page, contains("_FieldLabel(text: 'Numéro bénéficiaire')"));
      expect(page, contains('recoverOrderByDetails'));
      expect(page, isNot(contains('Référence de commande')));
      expect(repository, contains('findCustomerOrder'));
      expect(repository, contains(".where('customerAuthUid', isEqualTo: customer.uid)"));
    });

    test('les surfaces principales acceptent le geste tirer pour actualiser', () {
      for (final String path in <String>[
        'lib/features/customer_order/presentation/pages/customer_home_page.dart',
        'lib/features/customer_order/presentation/pages/customer_catalog_page.dart',
        'lib/features/customer_order/presentation/pages/customer_order_history_page.dart',
      ]) {
        final String source = File(path).readAsStringSync();
        expect(source, contains('RefreshIndicator('), reason: path);
        expect(
          source,
          contains('AlwaysScrollableScrollPhysics()'),
          reason: path,
        );
      }
    });

    test('Voir les offres a un accent visuel distinct et premium', () {
      final String home = File(
        'lib/features/customer_order/presentation/pages/customer_home_page.dart',
      ).readAsStringSync();

      expect(home, contains('CustomerAppColors.cyanAccent'));
      expect(home, contains('CustomerAppColors.primaryDeep'));
      expect(home, contains('Icons.local_offer_outlined'));
    });
  });
}
