abstract class CustomerLocationConsentStore {
  bool get hasGrantedConsent;

  void markGrantedConsent();

  void clearGrantedConsent();
}
