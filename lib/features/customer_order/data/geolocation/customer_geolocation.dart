import 'package:cabine_flow/features/customer_order/data/geolocation/customer_geolocation_stub.dart'
    if (dart.library.html) 'package:cabine_flow/features/customer_order/data/geolocation/customer_geolocation_web.dart';
import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';

CustomerGeolocationService createCustomerGeolocationService() {
  return createPlatformCustomerGeolocationService();
}
