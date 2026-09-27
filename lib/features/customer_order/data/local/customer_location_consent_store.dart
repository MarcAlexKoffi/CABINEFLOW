import 'package:cabine_flow/features/customer_order/data/local/customer_location_consent_store_stub.dart'
    if (dart.library.html) 'package:cabine_flow/features/customer_order/data/local/customer_location_consent_store_web.dart';
import 'package:cabine_flow/features/customer_order/domain/repositories/customer_location_consent_store.dart';

CustomerLocationConsentStore createCustomerLocationConsentStore() {
  return createPlatformCustomerLocationConsentStore();
}
