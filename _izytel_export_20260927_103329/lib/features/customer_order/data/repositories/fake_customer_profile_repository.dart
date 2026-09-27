import 'dart:async';

import 'package:cabine_flow/features/customer_order/domain/models/beneficiary_phone_number.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_identity.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_profile.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_profile_repository.dart';

class FakeCustomerProfileRepository implements CustomerProfileRepository {
  FakeCustomerProfileRepository({CustomerProfile? initialProfile})
    : _profile = initialProfile;

  CustomerProfile? _profile;
  final StreamController<CustomerProfile?> _controller =
      StreamController<CustomerProfile?>.broadcast();

  CustomerProfile? get profile => _profile;

  @override
  Stream<CustomerProfile?> watchCurrentProfile() async* {
    yield _profile;
    yield* _controller.stream;
  }

  @override
  Future<void> saveDefaultBeneficiary({
    required CustomerIdentity identity,
    required BeneficiaryPhoneNumber beneficiaryPhone,
  }) async {
    _profile = CustomerProfile(
      name: identity.name,
      whatsappPhone: identity.whatsappNumber,
      defaultBeneficiaryPhone: beneficiaryPhone,
    );
    _controller.add(_profile);
  }

  Future<void> close() => _controller.close();
}
