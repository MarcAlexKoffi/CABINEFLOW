import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_offer.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerOrderViewModel - parcours client', () {
    test('conserve le service sélectionné et avance vers l’étape 3', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Alex',
        whatsappInput: '07 00 00 00 00',
      );

      expect(viewModel.currentStep, 2);
      expect(viewModel.canContinueFromService, isFalse);

      viewModel.selectService(CustomerService.internetSubscription);

      expect(
        viewModel.draft.service,
        CustomerService.internetSubscription,
      );
      expect(viewModel.canContinueFromService, isTrue);

      viewModel.continueFromService();

      expect(viewModel.currentStep, 3);
    });

    test('conserve le réseau sélectionné et avance vers l’étape 4', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Mariam',
        whatsappInput: '+225 05 12 34 56 78',
      );
      viewModel.selectService(CustomerService.calls);
      viewModel.continueFromService();

      expect(viewModel.currentStep, 3);
      expect(viewModel.canContinueFromNetwork, isFalse);

      viewModel.selectNetwork(MobileNetwork.mtn);

      expect(viewModel.draft.network, MobileNetwork.mtn);
      expect(viewModel.canContinueFromNetwork, isTrue);

      viewModel.continueFromNetwork();

      expect(viewModel.currentStep, 4);
    });

    test('le retour conserve le réseau déjà choisi', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Serge',
        whatsappInput: '01 02 03 04 05',
      );
      viewModel.selectService(CustomerService.unitTransfer);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();
      viewModel.goBack();

      expect(viewModel.currentStep, 3);
      expect(viewModel.draft.network, MobileNetwork.orange);
    });

    test('changer de service efface les choix effectués ensuite', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Awa',
        whatsappInput: '07 10 20 30 40',
      );
      viewModel.selectService(CustomerService.internetSubscription);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.moov);
      viewModel.continueFromNetwork();
      viewModel.selectOffer(
        const CustomerOffer(
          id: 'moov-internet-500',
          network: MobileNetwork.moov,
          type: CustomerOfferType.internet,
          title: '1,5 Go',
          catalogLabel: 'Internet Moov 1,5 Go - 7 jours',
          amount: 500,
          details: <String>['Validité : 7 jours'],
        ),
      );
      viewModel.goBack();
      viewModel.goBack();

      viewModel.selectService(CustomerService.calls);

      expect(viewModel.draft.service, CustomerService.calls);
      expect(viewModel.draft.network, isNull);
      expect(viewModel.draft.offer, isNull);
      expect(viewModel.draft.amount, isNull);
    });

    test('un transfert exige seulement un montant supérieur à zéro', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Koffi',
        whatsappInput: '07 00 00 00 01',
      );
      viewModel.selectService(CustomerService.unitTransfer);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();

      expect(viewModel.currentStep, 4);
      expect(viewModel.canContinueFromOffer, isFalse);

      viewModel.setTransferAmount(1500);

      expect(viewModel.draft.offer, isNull);
      expect(viewModel.draft.amount, 1500);
      expect(viewModel.canContinueFromOffer, isTrue);

      viewModel.continueFromOffer();

      expect(viewModel.currentStep, 5);
    });

    test('une offre Internet fixe automatiquement le montant', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      const CustomerOffer offer = CustomerOffer(
        id: 'orange-internet-1000',
        network: MobileNetwork.orange,
        type: CustomerOfferType.internet,
        title: '4 Go',
        catalogLabel: 'Internet Orange 4 Go - 7 jours',
        amount: 1000,
        details: <String>['Validité : 7 jours'],
      );

      viewModel.saveIdentity(
        name: 'Mireille',
        whatsappInput: '05 00 00 00 02',
      );
      viewModel.selectService(CustomerService.internetSubscription);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();
      viewModel.selectOffer(offer);

      expect(viewModel.draft.offer, same(offer));
      expect(viewModel.draft.amount, 1000);
      expect(viewModel.canContinueFromOffer, isTrue);

      viewModel.continueFromOffer();

      expect(viewModel.currentStep, 5);
    });

    test('changer de réseau efface l’offre et son montant', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      const CustomerOffer offer = CustomerOffer(
        id: 'mtn-calls-500',
        network: MobileNetwork.mtn,
        type: CustomerOfferType.calls,
        title: 'Free Plus 500',
        catalogLabel: 'MTN Free Plus 500',
        amount: 500,
        details: <String>['55 min tous réseaux'],
      );

      viewModel.saveIdentity(
        name: 'Yao',
        whatsappInput: '01 00 00 00 03',
      );
      viewModel.selectService(CustomerService.calls);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.mtn);
      viewModel.continueFromNetwork();
      viewModel.selectOffer(offer);

      expect(viewModel.draft.offer, same(offer));
      expect(viewModel.draft.amount, 500);

      viewModel.selectNetwork(MobileNetwork.orange);

      expect(viewModel.draft.network, MobileNetwork.orange);
      expect(viewModel.draft.offer, isNull);
      expect(viewModel.draft.amount, isNull);
    });

    test('une offre personnalisée exige un libellé et un montant', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Fatou',
        whatsappInput: '07 00 00 00 04',
      );
      viewModel.selectService(CustomerService.internetSubscription);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.mtn);
      viewModel.continueFromNetwork();

      viewModel.useCustomOffer();

      expect(viewModel.isUsingCustomOffer, isTrue);
      expect(viewModel.draft.offer, isNull);
      expect(viewModel.canContinueFromOffer, isFalse);

      viewModel.updateCustomOffer(
        label: 'Pass Internet 8 Go - 15 jours',
        amount: 3000,
      );

      expect(viewModel.draft.offer, isNull);
      expect(
        viewModel.draft.customOfferLabel,
        'Pass Internet 8 Go - 15 jours',
      );
      expect(viewModel.draft.selectedOfferLabel, 'Pass Internet 8 Go - 15 jours');
      expect(viewModel.draft.amount, 3000);
      expect(viewModel.canContinueFromOffer, isTrue);

      viewModel.continueFromOffer();

      expect(viewModel.currentStep, 5);
    });

    test('sélectionner une offre du catalogue efface l’offre personnalisée', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      const CustomerOffer offer = CustomerOffer(
        id: 'orange-calls-1000',
        network: MobileNetwork.orange,
        type: CustomerOfferType.calls,
        title: 'Pass Mix 1 000',
        catalogLabel: 'Orange Pass Mix 1 000',
        amount: 1000,
        details: <String>['100 min tous réseaux'],
      );

      viewModel.saveIdentity(
        name: 'Konan',
        whatsappInput: '05 00 00 00 05',
      );
      viewModel.selectService(CustomerService.calls);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();
      viewModel.useCustomOffer(
        label: 'Pack appels spécial',
        amount: 2000,
      );

      expect(viewModel.isUsingCustomOffer, isTrue);

      viewModel.selectOffer(offer);

      expect(viewModel.isUsingCustomOffer, isFalse);
      expect(viewModel.draft.customOfferLabel, isNull);
      expect(viewModel.draft.offer, same(offer));
      expect(viewModel.draft.amount, 1000);
    });

    test('changer de réseau efface aussi l’offre personnalisée', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Aminata',
        whatsappInput: '01 00 00 00 06',
      );
      viewModel.selectService(CustomerService.internetSubscription);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.moov);
      viewModel.continueFromNetwork();
      viewModel.useCustomOffer(
        label: 'Pass Internet personnalisé',
        amount: 3500,
      );

      viewModel.selectNetwork(MobileNetwork.mtn);

      expect(viewModel.draft.network, MobileNetwork.mtn);
      expect(viewModel.draft.customOfferLabel, isNull);
      expect(viewModel.draft.offer, isNull);
      expect(viewModel.draft.amount, isNull);
    });


    test('enregistre le numéro bénéficiaire et avance vers l’étape 6', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Alex',
        whatsappInput: '07 00 00 00 00',
      );
      viewModel.selectService(CustomerService.unitTransfer);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();
      viewModel.setTransferAmount(2000);
      viewModel.continueFromOffer();

      expect(viewModel.currentStep, 5);
      expect(viewModel.canContinueFromBeneficiary, isFalse);

      viewModel.saveBeneficiary(
        phoneInput: '05 12 34 56 78',
        confirmationInput: '+225 05 12 34 56 78',
      );

      expect(viewModel.currentStep, 6);
      expect(viewModel.canContinueFromBeneficiary, isTrue);
      expect(
        viewModel.draft.beneficiaryNumber?.normalized,
        '+2250512345678',
      );
    });

    test('refuse deux numéros bénéficiaires différents', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Mariam',
        whatsappInput: '05 00 00 00 00',
      );
      viewModel.selectService(CustomerService.calls);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.mtn);
      viewModel.continueFromNetwork();
      viewModel.useCustomOffer(
        label: 'Pack appels spécial',
        amount: 1500,
      );
      viewModel.continueFromOffer();

      expect(
        () => viewModel.saveBeneficiary(
          phoneInput: '05 12 34 56 78',
          confirmationInput: '05 12 34 56 79',
        ),
        throwsA(isA<FormatException>()),
      );

      expect(viewModel.currentStep, 5);
      expect(viewModel.draft.beneficiaryNumber, isNull);
    });

    test('changer de réseau efface le numéro bénéficiaire confirmé', () {
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
      );

      viewModel.saveIdentity(
        name: 'Koffi',
        whatsappInput: '01 00 00 00 00',
      );
      viewModel.selectService(CustomerService.unitTransfer);
      viewModel.continueFromService();
      viewModel.selectNetwork(MobileNetwork.orange);
      viewModel.continueFromNetwork();
      viewModel.setTransferAmount(1000);
      viewModel.continueFromOffer();
      viewModel.saveBeneficiary(
        phoneInput: '07 11 22 33 44',
        confirmationInput: '07 11 22 33 44',
      );

      expect(viewModel.draft.beneficiaryNumber, isNotNull);

      viewModel.selectNetwork(MobileNetwork.moov);

      expect(viewModel.draft.network, MobileNetwork.moov);
      expect(viewModel.draft.beneficiaryNumber, isNull);
      expect(viewModel.draft.offer, isNull);
      expect(viewModel.draft.amount, isNull);
    });
  });
}

void completeCustomerDraft(CustomerOrderViewModel viewModel) {
  viewModel.saveIdentity(
    name: 'Client test',
    whatsappInput: '07 00 00 00 00',
  );
  viewModel.selectService(CustomerService.unitTransfer);
  viewModel.continueFromService();
  viewModel.selectNetwork(MobileNetwork.orange);
  viewModel.continueFromNetwork();
  viewModel.setTransferAmount(2000);
  viewModel.continueFromOffer();
  viewModel.saveBeneficiary(
    phoneInput: '05 12 34 56 78',
    confirmationInput: '05 12 34 56 78',
  );
}
