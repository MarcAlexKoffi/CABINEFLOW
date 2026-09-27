import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_profile.dart';

abstract class CustomerProfileRepository {
  Stream<CustomerProfile?> watchCurrentProfile();

  Future<void> saveDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiaryPhone,
  });
}
