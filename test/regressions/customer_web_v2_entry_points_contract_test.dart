import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  group('Web Client V2 - Accueil Catalogue Recapitulatif', () {
    test('Accueil distingue clairement transfert direct et catalogue', () {
      final String home = _read(
        'lib/app/modules/customer/views/customer_home_page.dart',
      );

      expect(home, contains('Commandez directement ou choisissez une offre'));
      expect(home, contains("service: CustomerService.unitTransfer"));
      expect(home, contains("badge: 'Sans offre'"));
      expect(home, contains("badge: 'Catalogue'"));
      expect(home, contains("text: 'Commander maintenant'"));
      expect(home, contains("text: 'Voir les offres'"));
    });

    test('Catalogue garde un acces explicite au transfert sans offre', () {
      final String catalog = _read(
        'lib/app/modules/customer/views/customer_catalog_page.dart',
      );
      final String flow = _read(
        'lib/app/modules/customer/views/customer_order_flow_page.dart',
      );

      expect(catalog, contains('required this.onStartDirectTransfer'));
      expect(catalog, contains("'Transfert direct'"));
      expect(catalog, contains("'Commencer sans offre'"));
      expect(
        flow,
        contains(
          '_startServiceOrder(CustomerService.unitTransfer)',
        ),
      );
    });

    test('Catalogue conserve aussi le choix des offres reelles', () {
      final String catalog = _read(
        'lib/app/modules/customer/views/customer_catalog_page.dart',
      );

      expect(catalog, contains('watchAllOffers()'));
      expect(catalog, contains('onChoose: widget.onChooseOffer'));
      expect(catalog, contains('_CatalogOfferCard'));
      expect(catalog, contains("child: const Text('Choisir')"));
    });

    test('Recapitulatif distingue transfert direct et offre sans remettre WhatsApp au centre', () {
      final String summary = _read(
        'lib/app/modules/customer/views/customer_summary_page.dart',
      );

      expect(summary, contains("'Vérifiez votre commande'"));
      expect(summary, contains("'Transfert direct • Sans offre'"));
      expect(summary, contains("'Offre IzyTel'"));
      expect(
        summary,
        contains("'Aucune offre du catalogue n’est requise pour ce transfert.'"),
      );
      expect(summary, isNot(contains("_SummaryRow(label: 'WhatsApp'")));
    });
  });
}
