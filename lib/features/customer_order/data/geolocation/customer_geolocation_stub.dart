import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';

CustomerGeolocationService createPlatformCustomerGeolocationService() {
  return const _UnavailableCustomerGeolocationService();
}

class _UnavailableCustomerGeolocationService
    implements CustomerGeolocationService {
  const _UnavailableCustomerGeolocationService();

  @override
  Future<CustomerLocationCapture> requestCurrentLocation() async {
    return const CustomerLocationCapture.unavailable();
  }
}
