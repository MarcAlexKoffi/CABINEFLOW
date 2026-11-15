import 'package:cabine_flow/app/domain/entities/customer/beneficiary_phone_number.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_identity.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_profile.dart';

abstract class CustomerProfileRepository {
  Stream<CustomerProfile?> watchCurrentProfile();

  Future<void> saveDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiaryPhone,
  });
}
