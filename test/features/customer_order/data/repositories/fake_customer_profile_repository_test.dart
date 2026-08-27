import 'package:cabine_flow/features/customer_order/data/repositories/fake_customer_profile_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/whatsapp_phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'le profil client mémorise explicitement le bénéficiaire par défaut',
    () async {
      final FakeCustomerProfileRepository repository =
          FakeCustomerProfileRepository();

      await repository.saveDefaultBeneficiary(
        identity: CustomerIdentity(
          name: 'Client test',
          whatsappNumber: WhatsappPhoneNumber.parse('07 00 00 00 00'),
        ),
        beneficiaryPhone: BeneficiaryPhoneNumber.parse('05 12 34 56 78'),
      );

      expect(repository.profile?.name, 'Client test');
      expect(repository.profile?.whatsappPhone.normalized, '+2250700000000');
      expect(
        repository.profile?.defaultBeneficiaryPhone.normalized,
        '+2250512345678',
      );

      await repository.close();
    },
  );
}
