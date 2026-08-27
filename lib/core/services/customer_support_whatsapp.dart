import 'package:url_launcher/url_launcher.dart';

class CustomerSupportWhatsApp {
  const CustomerSupportWhatsApp._();

  static const String displayPhone = '+225 01 52 36 82 90';
  static const String _waPhone = '2250152368290';

  static Uri buildUri({String? orderReference}) {
    final String reference = orderReference?.trim().toUpperCase() ?? '';
    final String message = reference.isEmpty
        ? 'Bonjour, j’ai besoin d’aide sur IzyTel.'
        : 'Bonjour, j’ai besoin d’aide concernant ma commande $reference sur IzyTel.';

    return Uri.https('wa.me', '/$_waPhone', <String, String>{'text': message});
  }

  static Future<bool> open({String? orderReference}) {
    return launchUrl(
      buildUri(orderReference: orderReference),
      mode: LaunchMode.externalApplication,
    );
  }
}
