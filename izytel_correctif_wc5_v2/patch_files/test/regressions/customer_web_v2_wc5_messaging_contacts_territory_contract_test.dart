import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC5 - messagerie unique, contacts frequents et routage territorial', () {
    test('identification client ne demande plus WhatsApp et utilise Signo Serge', () {
      final String source = File(
        'lib/features/customer_order/presentation/pages/customer_identification_page.dart',
      ).readAsStringSync();
      expect(source, contains("hintText: 'Signo Serge'"));
      expect(source, isNot(contains('Numéro WhatsApp')));
      expect(source, isNot(contains('WhatsappPhoneNumber.validate')));
      expect(source, contains('Ouvrir la messagerie IzyTel'));
    });

    test('contacts frequents utilisent le couple nom et numero et remplissent sans avancer', () {
      final String viewModel = File(
        'lib/features/customer_order/presentation/view_models/customer_order_view_model.dart',
      ).readAsStringSync();
      final String page = File(
        'lib/features/customer_order/presentation/pages/customer_beneficiary_page.dart',
      ).readAsStringSync();
      expect(viewModel, contains('suggestedBeneficiaryContacts'));
      expect(viewModel, contains("'${r'$'}{cleanedName.toLowerCase()}|${r'$'}{beneficiary.normalized}'"));
      expect(viewModel, contains('keys.take(6)'));
      expect(page, contains('Numéros fréquents'));
      expect(page, contains('contact.phoneNumber.displayValue'));
      expect(page, contains('Le contact frequent remplit uniquement le numero beneficiaire'));
    });

    test('aucun circuit wa.me ne subsiste dans le code applicatif actif', () {
      final Directory lib = Directory('lib');
      final List<File> offenders = <File>[];
      for (final FileSystemEntity entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final String source = entity.readAsStringSync();
        if (source.contains('wa.me') ||
            source.contains('CustomerSupportWhatsApp') ||
            source.contains('BackofficeWhatsAppService')) {
          offenders.add(entity);
        }
      }
      expect(offenders.map((File file) => file.path).toList(), isEmpty);
    });

    test('SQL impose zone commune pour Agent et Cabiniste', () {
      final String sql = File(
        'supabase/wc5_territorial_routing_messaging_and_contacts.sql',
      ).readAsStringSync();
      expect(sql, contains('t.zone_id=any(c.zone_ids)'));
      expect(sql, contains('t.zone_id=any(a.zone_ids)'));
      expect(sql, contains('private.izytel_wc5_zone_for_location'));
      expect(sql, contains('private.izytel_wc5_fallback_zone_id'));
      expect(sql, contains('is_central_fallback'));
      expect(sql, contains('coverage_radius_km'));
    });

    test('messagerie est affectee au Manager de la zone et non a un Manager global', () {
      final String sql = File(
        'supabase/wc5_territorial_routing_messaging_and_contacts.sql',
      ).readAsStringSync();
      expect(sql, contains('conversation_row.zone_id'));
      expect(sql, contains('private.izytel_wc5_manager_owns_zone'));
      expect(sql, contains('assigned_manager_uid'));
      expect(sql, contains('z.manager_id'));
      expect(sql, contains('izytel_wc5_create_conversation'));
    });

    test('commandes terminees notifient automatiquement via IzyTel', () {
      final String sql = File(
        'supabase/wc5_territorial_routing_messaging_and_contacts.sql',
      ).readAsStringSync();
      final String agentPage = File(
        'lib/features/orders/presentation/pages/orders_page.dart',
      ).readAsStringSync();
      final String delivery = File(
        'lib/features/messaging/data/services/customer_messaging_delivery_service.dart',
      ).readAsStringSync();
      expect(sql, contains('izytel_wc5_completed_order_message'));
      expect(sql, contains("new.order_status = 'completed'"));
      expect(sql, contains('izytel_wc5_emit_customer_system_message'));
      expect(sql, contains('izytel_wc5_notify_completed_order'));
      expect(agentPage, contains('notifyCompletedOrder('));
      expect(agentPage, isNot(contains('.notifyOrder(')));
      expect(delivery, contains("'izytel_wc5_notify_completed_order'"));
    });
  });
}
