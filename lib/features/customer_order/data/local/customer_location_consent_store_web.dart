// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:cabine_flow/features/customer_order/domain/repositories/customer_location_consent_store.dart';

CustomerLocationConsentStore createPlatformCustomerLocationConsentStore() {
  return const _WebCustomerLocationConsentStore();
}

class _WebCustomerLocationConsentStore
    implements CustomerLocationConsentStore {
  const _WebCustomerLocationConsentStore();

  static const String _storageKey = 'izytel.customer.location.granted.v1';
  static const String _grantedValue = 'granted';

  @override
  bool get hasGrantedConsent =>
      html.window.localStorage[_storageKey] == _grantedValue;

  @override
  void markGrantedConsent() {
    html.window.localStorage[_storageKey] = _grantedValue;
  }

  @override
  void clearGrantedConsent() {
    html.window.localStorage.remove(_storageKey);
  }
}
