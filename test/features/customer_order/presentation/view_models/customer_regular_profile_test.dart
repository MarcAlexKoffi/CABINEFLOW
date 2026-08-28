import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_order_repository.dart';
import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_beneficiary_target.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_profile.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/presentation/view_models/customer_order_view_model.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 10A - client régulier', () {
    test('propose le numéro habituel uniquement au même WhatsApp', () async {
      final FakeCustomerProfileRepository profileRepository =
          FakeCustomerProfileRepository(
            initialProfile: CustomerProfile(
              name: 'Alex',
              whatsappPhone: WhatsappPhoneNumber.parse('07 00 00 00 00'),
              defaultBeneficiaryPhone: BeneficiaryPhoneNumber.parse(
                '05 12 34 56 78',
              ),
            ),
          );
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
        profileRepository: profileRepository,
      );

      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);

      viewModel.saveIdentity(name: 'Alex', whatsappInput: '07 00 00 00 00');
      expect(viewModel.defaultBeneficiaryNumber?.normalized, '+2250512345678');

      viewModel.saveIdentity(name: 'Autre', whatsappInput: '01 11 22 33 44');
      expect(viewModel.defaultBeneficiaryNumber, isNull);

      viewModel.dispose();
      await profileRepository.close();
    });

    test(
      'Pour moi réutilise le numéro mémorisé sans nouvelle saisie',
      () async {
        final FakeCustomerProfileRepository profileRepository =
            FakeCustomerProfileRepository(
              initialProfile: CustomerProfile(
                name: 'Mariam',
                whatsappPhone: WhatsappPhoneNumber.parse('05 00 00 00 00'),
                defaultBeneficiaryPhone: BeneficiaryPhoneNumber.parse(
                  '07 10 20 30 40',
                ),
              ),
            );
        final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
          orderRepository: FakeCustomerOrderRepository(),
          profileRepository: profileRepository,
        );

        await viewModel.initialize();
        await Future<void>.delayed(Duration.zero);
        _moveToBeneficiaryStep(
          viewModel,
          name: 'Mariam',
          whatsapp: '05 00 00 00 00',
        );

        expect(viewModel.currentStep, 5);
        expect(viewModel.beneficiaryTarget, CustomerBeneficiaryTarget.self);
        expect(viewModel.hasDefaultBeneficiaryForCurrentIdentity, isTrue);

        viewModel.useSavedBeneficiaryForMe();

        expect(viewModel.currentStep, 6);
        expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250710203040');

        viewModel.dispose();
        await profileRepository.close();
      },
    );

    test(
      'le numéro habituel est revalidé pour le réseau sélectionné',
      () async {
        final FakeCustomerProfileRepository profileRepository =
            FakeCustomerProfileRepository(
              initialProfile: CustomerProfile(
                name: 'Mariam',
                whatsappPhone: WhatsappPhoneNumber.parse('05 00 00 00 00'),
                defaultBeneficiaryPhone: BeneficiaryPhoneNumber.parse(
                  '05 10 20 30 40',
                ),
              ),
            );
        final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
          orderRepository: FakeCustomerOrderRepository(),
          profileRepository: profileRepository,
        );

        await viewModel.initialize();
        await Future<void>.delayed(Duration.zero);
        _moveToBeneficiaryStep(
          viewModel,
          name: 'Mariam',
          whatsapp: '05 00 00 00 00',
        );

        expect(
          () => viewModel.useSavedBeneficiaryForMe(),
          throwsA(
            isA<FormatException>().having(
              (FormatException error) => error.message,
              'message',
              'PORTABILITY_REQUIRED',
            ),
          ),
        );
        expect(viewModel.currentStep, 5);

        viewModel.useSavedBeneficiaryForMe(isPortabilityConfirmed: true);
        expect(viewModel.currentStep, 6);

        viewModel.dispose();
        await profileRepository.close();
      },
    );

    test(
      'premier Pour moi mémorise le numéro puis continue immédiatement',
      () async {
        final FakeCustomerProfileRepository profileRepository =
            FakeCustomerProfileRepository();
        final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
          orderRepository: FakeCustomerOrderRepository(),
          profileRepository: profileRepository,
        );

        await viewModel.initialize();
        await Future<void>.delayed(Duration.zero);
        _moveToBeneficiaryStep(
          viewModel,
          name: 'Koffi',
          whatsapp: '07 00 00 00 01',
        );

        viewModel.saveBeneficiaryForMe(
          phoneInput: '07 55 44 33 22',
          confirmationInput: '+225 07 55 44 33 22',
        );

        expect(viewModel.currentStep, 6);
        expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250755443322');

        await Future<void>.delayed(Duration.zero);

        expect(profileRepository.profile, isNotNull);
        expect(
          profileRepository.profile?.defaultBeneficiaryPhone.normalized,
          '+2250755443322',
        );
        expect(
          profileRepository.profile?.whatsappPhone.normalized,
          '+2250700000001',
        );

        viewModel.dispose();
        await profileRepository.close();
      },
    );

    test(
      'Pour un autre numéro ne remplace jamais le numéro habituel',
      () async {
        final FakeCustomerProfileRepository profileRepository =
            FakeCustomerProfileRepository(
              initialProfile: CustomerProfile(
                name: 'Awa',
                whatsappPhone: WhatsappPhoneNumber.parse('07 00 00 00 02'),
                defaultBeneficiaryPhone: BeneficiaryPhoneNumber.parse(
                  '05 00 00 00 02',
                ),
              ),
            );
        final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
          orderRepository: FakeCustomerOrderRepository(),
          profileRepository: profileRepository,
        );

        await viewModel.initialize();
        await Future<void>.delayed(Duration.zero);
        _moveToBeneficiaryStep(
          viewModel,
          name: 'Awa',
          whatsapp: '07 00 00 00 02',
        );

        viewModel.selectBeneficiaryTarget(CustomerBeneficiaryTarget.other);
        viewModel.saveBeneficiary(
          phoneInput: '01 99 88 77 66',
          confirmationInput: '01 99 88 77 66',
          isPortabilityConfirmed: true,
        );

        expect(viewModel.currentStep, 6);
        expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250199887766');
        expect(
          profileRepository.profile?.defaultBeneficiaryPhone.normalized,
          '+2250500000002',
        );

        viewModel.dispose();
        await profileRepository.close();
      },
    );

    test('une erreur de mémorisation ne bloque pas la commande', () async {
      final _FailingCustomerProfileRepository profileRepository =
          _FailingCustomerProfileRepository();
      final CustomerOrderViewModel viewModel = CustomerOrderViewModel(
        orderRepository: FakeCustomerOrderRepository(),
        profileRepository: profileRepository,
      );

      await viewModel.initialize();
      await Future<void>.delayed(Duration.zero);
      _moveToBeneficiaryStep(
        viewModel,
        name: 'Yao',
        whatsapp: '01 00 00 00 03',
      );

      viewModel.saveBeneficiaryForMe(
        phoneInput: '07 44 33 22 11',
        confirmationInput: '07 44 33 22 11',
      );

      expect(viewModel.currentStep, 6);
      expect(viewModel.draft.beneficiaryNumber?.normalized, '+2250744332211');

      await Future<void>.delayed(Duration.zero);

      expect(viewModel.customerProfileErrorMessage, isNotNull);
      expect(viewModel.currentStep, 6);

      viewModel.dispose();
    });
  });
}

void _moveToBeneficiaryStep(
  CustomerOrderViewModel viewModel, {
  required String name,
  required String whatsapp,
}) {
  viewModel.saveIdentity(name: name, whatsappInput: whatsapp);
  viewModel.selectService(CustomerService.unitTransfer);
  viewModel.continueFromService();
  viewModel.selectNetwork(MobileNetwork.orange);
  viewModel.continueFromNetwork();
  viewModel.setTransferAmount(1000);
  viewModel.continueFromOffer();
}

class _FailingCustomerProfileRepository implements CustomerProfileRepository {
  @override
  Future<void> saveDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiaryPhone,
  }) {
    return Future<void>.error(StateError('Firestore indisponible'));
  }

  @override
  Stream<CustomerProfile?> watchCurrentProfile() =>
      Stream<CustomerProfile?>.value(null);
}
