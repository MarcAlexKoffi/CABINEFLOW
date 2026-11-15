import 'package:cabine_flow/app/data/platform/customer/geolocation/customer_geolocation_stub.dart'
    if (dart.library.html) 'package:cabine_flow/app/data/platform/customer/geolocation/customer_geolocation_web.dart';
import 'package:cabine_flow/app/domain/policies/customer/customer_geolocation_service.dart';

CustomerGeolocationService createCustomerGeolocationService() {
  return createPlatformCustomerGeolocationService();
}
