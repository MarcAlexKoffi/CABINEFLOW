import 'package:cabine_flow/features/customer_order/domain/repositories/customer_location_consent_store.dart';

CustomerLocationConsentStore createPlatformCustomerLocationConsentStore() {
  return const _NoopCustomerLocationConsentStore();
}

class _NoopCustomerLocationConsentStore
    implements CustomerLocationConsentStore {
  const _NoopCustomerLocationConsentStore();

  @override
  bool get hasGrantedConsent => false;

  @override
  void markGrantedConsent() {}

  @override
  void clearGrantedConsent() {}
}
