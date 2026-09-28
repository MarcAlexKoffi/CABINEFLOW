import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WC7 - navigation, notifications messagerie et performance Agent', () {
    test('messagerie: Retour Android suit une vraie pile Flutter', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();
      final String messaging = File(
        'lib/features/messaging/presentation/pages/customer_messaging_page.dart',
      ).readAsStringSync();

      expect(flow, contains('_pushMessagingRoute'));
      expect(flow, contains("RouteSettings(name: '/customer/messaging')"));
      expect(flow, contains('MaterialPageRoute<void>('));
      expect(flow, contains('Navigator.of(routeContext).maybePop()'));
      expect(messaging, contains("RouteSettings(name: '/customer/messaging/new')"));
      expect(messaging, contains("'/customer/messaging/conversation/"));
      expect(messaging, isNot(contains('PopScope(')));
    });

    test('messagerie: chaque message client declenche une notification Manager', () {
      final String migration = File(
        'supabase/migrations/20260927182335_wc7_customer_manager_messaging_notifications.sql',
      ).readAsStringSync();
      final String payload = File(
        'lib/core/notifications/izytel_notification_payload.dart',
      ).readAsStringSync();
      final String shell = File(
        'lib/features/navigation/presentation/pages/main_shell_page.dart',
      ).readAsStringSync();
      final String staffMessaging = File(
        'lib/features/messaging/presentation/pages/staff_customer_messaging_page.dart',
      ).readAsStringSync();

      expect(migration, contains('trg_wc7_customer_message_notification'));
      expect(migration, contains('customer_message_new'));
      expect(migration, contains('manager_message_new'));
      expect(migration, contains('private.enqueue_izytel_notification'));
      expect(migration, contains("'conversationId'"));
      expect(payload, contains('conversationId'));
      expect(payload, contains('targetsConversation'));
      expect(shell, contains("payload.type == 'customer_message_new'"));
      expect(shell, contains('initialConversationId: payload.conversationId'));
      expect(staffMessaging, contains('initialConversationId'));
      expect(staffMessaging, contains('_openInitialConversationIfAvailable'));
    });

    test('client Web: reponse Manager remonte aussi en notification in-app', () {
      final String flow = File(
        'lib/features/customer_order/presentation/pages/customer_order_flow_page.dart',
      ).readAsStringSync();

      expect(flow, contains('_startCustomerMessagingAlerts'));
      expect(flow, contains('CustomerMessageSenderType.manager'));
      expect(flow, contains('IzyTel vous a répondu'));
    });

    test('Agent: Realtime remplace le polling 3 s et les switches sont optimistes', () {
      final String repository = File(
        'lib/features/agents/data/repositories/supabase_agent_operations_repository.dart',
      ).readAsStringSync();
      final String realtimeMigration = File(
        'supabase/migrations/20260927182349_wc7_agent_operations_realtime.sql',
      ).readAsStringSync();
      final String activity = File(
        'lib/features/agents/presentation/view_models/agent_activity_view_model.dart',
      ).readAsStringSync();

      expect(repository, contains('.stream(primaryKey:'));
      expect(repository, contains('_syncRealtimeAuth'));
      expect(repository, contains('fallbackPollInterval = Duration(seconds: 30)'));
      expect(repository, isNot(contains('pollInterval = Duration(seconds: 3)')));
      expect(realtimeMigration, contains('alter publication supabase_realtime'));
      expect(realtimeMigration, contains('phase5_agent_capacities'));
      expect(activity, contains('Mise a jour optimiste'));
      expect(activity, contains('profile = previous.copyWith('));
      expect(activity, contains('profile = previous;'));
    });

    test('profil Agent: les medias ne gardent plus tout l ecran en chargement', () {
      final String profile = File(
        'lib/features/agents/presentation/pages/agent_personal_profile_page.dart',
      ).readAsStringSync();

      expect(profile, contains('_loadMediaInBackground'));
      expect(profile, contains('unawaited(_loadMediaInBackground'));
      expect(profile, contains('timeout(const Duration(seconds: 12))'));
      expect(profile, contains('timeout(const Duration(seconds: 8))'));
      expect(profile, contains('setState(() => _isLoading = false)'));
    });
  });
}
