enum CustomerLocationStatus { notRequested, granted, denied, unavailable }

class CustomerOrderContextDraft {
  const CustomerOrderContextDraft({
    this.sourceCode,
    this.locationStatus = CustomerLocationStatus.notRequested,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.locationCapturedAt,
  });

  final String? sourceCode;
  final CustomerLocationStatus locationStatus;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? locationCapturedAt;

  bool get hasLocation =>
      locationStatus == CustomerLocationStatus.granted &&
      latitude != null &&
      longitude != null;

  CustomerOrderContextDraft copyWith({
    String? sourceCode,
    CustomerLocationStatus? locationStatus,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    DateTime? locationCapturedAt,
    bool clearSourceCode = false,
    bool clearLocation = false,
  }) {
    return CustomerOrderContextDraft(
      sourceCode: clearSourceCode ? null : sourceCode ?? this.sourceCode,
      locationStatus: locationStatus ?? this.locationStatus,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      accuracyMeters: clearLocation ? null : accuracyMeters ?? this.accuracyMeters,
      locationCapturedAt: clearLocation
          ? null
          : locationCapturedAt ?? this.locationCapturedAt,
    );
  }
}
