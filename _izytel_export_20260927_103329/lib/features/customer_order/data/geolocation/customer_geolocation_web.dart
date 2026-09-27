import 'dart:async';
import 'dart:js_interop';

import 'package:cabine_flow/features/customer_order/domain/services/customer_geolocation_service.dart';

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator(JSObject _) implements JSObject {
  external _Geolocation get geolocation;
}

extension type _Geolocation(JSObject _) implements JSObject {
  external void getCurrentPosition(
    JSFunction successCallback,
    JSFunction errorCallback,
  );
}

extension type _GeolocationPosition(JSObject _) implements JSObject {
  external _GeolocationCoordinates get coords;
}

extension type _GeolocationCoordinates(JSObject _) implements JSObject {
  external double get latitude;
  external double get longitude;
  external double get accuracy;
}

extension type _GeolocationPositionError(JSObject _) implements JSObject {
  external int get code;
}

CustomerGeolocationService createPlatformCustomerGeolocationService() {
  return const _WebCustomerGeolocationService();
}

class _WebCustomerGeolocationService implements CustomerGeolocationService {
  const _WebCustomerGeolocationService();

  static const int _permissionDeniedCode = 1;

  @override
  Future<CustomerLocationCapture> requestCurrentLocation() {
    final Completer<CustomerLocationCapture> completer =
        Completer<CustomerLocationCapture>();

    void onSuccess(_GeolocationPosition position) {
      final _GeolocationCoordinates coordinates = position.coords;
      if (!completer.isCompleted) {
        completer.complete(
          CustomerLocationCapture.granted(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            accuracyMeters: coordinates.accuracy,
            capturedAt: DateTime.now().toUtc(),
          ),
        );
      }
    }

    void onError(_GeolocationPositionError error) {
      if (!completer.isCompleted) {
        completer.complete(
          error.code == _permissionDeniedCode
              ? const CustomerLocationCapture.denied()
              : const CustomerLocationCapture.unavailable(),
        );
      }
    }

    try {
      _navigator.geolocation.getCurrentPosition(
        onSuccess.toJS,
        onError.toJS,
      );
    } on Object {
      if (!completer.isCompleted) {
        completer.complete(const CustomerLocationCapture.unavailable());
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => const CustomerLocationCapture.unavailable(),
    );
  }
}
