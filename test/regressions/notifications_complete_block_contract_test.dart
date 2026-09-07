import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registre FCM utilise Supabase sans ecriture Firestore', () {
    final String source = File(
      'lib/core/notifications/izytel_notification_device_registry.dart',
    ).readAsStringSync();

    expect(source, contains('izytel_register_notification_device'));
    expect(source, contains('izytel_deactivate_notification_device'));
    expect(source, contains('FirebaseMessagingBootstrap.tokenChanges'));
    expect(source, isNot(contains('cloud_firestore')));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('FIREBASE_SERVICE_ACCOUNT_JSON')));
  });

  test('navigation notification est branchee Agent et Manager', () {
    final String shell = File(
      'lib/features/navigation/presentation/pages/main_shell_page.dart',
    ).readAsStringSync();
    final String agentOrders = File(
      'lib/features/orders/presentation/pages/agent_orders_page.dart',
    ).readAsStringSync();

    expect(shell, contains('FirebaseMessagingBootstrap.openedPayloads.listen'));
    expect(shell, contains("payload.type == 'order_manual_required'"));
    expect(shell, contains("payload.type == 'agent_issue_new'"));
    expect(shell, contains("payload.type == 'agent_issue_resolved'"));
    expect(shell, contains('IzyTelNotificationDeviceRegistry.deactivateCurrentDevice'));
    expect(agentOrders, contains('notificationOrderRequest'));
    expect(agentOrders, contains('_openNotificationOrderIfAvailable'));
  });

  test('backend notification reste isole des regles Firestore', () {
    final String migration = File(
      'supabase/migrations/20260906_izytel_notifications_block.sql',
    ).readAsStringSync();
    final String edge = File(
      'supabase/functions/izytel-notification-dispatch/index.ts',
    ).readAsStringSync();

    expect(migration, contains('izytel_notification_devices'));
    expect(migration, contains('izytel_notification_outbox'));
    expect(migration, contains('trg_izytel_phase4_notifications'));
    expect(migration, contains('trg_izytel_agent_issue_notifications'));
    expect(migration, contains('pg_net'));
    expect(migration, isNot(contains('firestore.rules')));
    expect(migration, isNot(contains('FirebaseFirestore')));

    expect(edge, contains('FIREBASE_SERVICE_ACCOUNT_JSON'));
    expect(edge, contains('firebase.messaging'));
    expect(edge, contains('dispatch_nonce'));
    expect(edge, isNot(contains('private_key":')));
  });
}
