import 'package:cabine_flow/features/customer_order/domain/models/customer_order_context.dart';

class CustomerLocationCapture {
  const CustomerLocationCapture({
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
  });

  const CustomerLocationCapture.denied()
      : status = CustomerLocationStatus.denied,
        latitude = null,
        longitude = null,
        accuracyMeters = null,
        capturedAt = null;

  const CustomerLocationCapture.unavailable()
      : status = CustomerLocationStatus.unavailable,
        latitude = null,
        longitude = null,
        accuracyMeters = null,
        capturedAt = null;

  factory CustomerLocationCapture.granted({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    DateTime? capturedAt,
  }) {
    return CustomerLocationCapture(
      status: CustomerLocationStatus.granted,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      capturedAt: (capturedAt ?? DateTime.now()).toUtc(),
    );
  }

  final CustomerLocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;

  bool get isGranted =>
      status == CustomerLocationStatus.granted &&
      latitude != null &&
      longitude != null &&
      capturedAt != null;

  CustomerOrderContextDraft applyTo(CustomerOrderContextDraft current) {
    if (!isGranted) {
      return current.copyWith(
        locationStatus: status,
        clearLocation: true,
      );
    }

    return current.copyWith(
      locationStatus: CustomerLocationStatus.granted,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      locationCapturedAt: capturedAt,
    );
  }
}

abstract class CustomerGeolocationService {
  Future<CustomerLocationCapture> requestCurrentLocation();
}
