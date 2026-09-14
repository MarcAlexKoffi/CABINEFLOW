import 'package:url_launcher/url_launcher.dart';

class BackofficeWhatsAppService {
  const BackofficeWhatsAppService._();

  static String normalizePhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('225')) {
      return digits;
    }
    if (digits.startsWith('0')) {
      return '225$digits';
    }
    return digits;
  }

  static Future<bool> openMessage({
    required String phone,
    required String message,
  }) async {
    final String normalized = normalizePhone(phone);
    if (normalized.isEmpty) {
      return false;
    }
    final Uri uri = Uri.https('wa.me', '/$normalized', <String, String>{
      'text': message,
    });
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
