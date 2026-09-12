import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  group('Phase 3 - stabilisation technique', () {
    test('les fallbacks backend ne masquent que les pannes transitoires', () {
      final String policy = source(
        'lib/core/resilience/backend_failure_policy.dart',
      );
      final String orders = source(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );
      final String phase4 = source(
        'lib/features/orders/data/repositories/supabase_phase4_assignment_repository.dart',
      );
      final String phase5 = source(
        'lib/features/finances/data/repositories/supabase_phase5_finance_repository.dart',
      );

      expect(policy, contains("'unavailable'"));
      expect(policy, contains("'PGRST000'"));
      expect(policy, isNot(contains("'permission-denied',")));
      expect(policy, isNot(contains("'42501'")));

      expect(orders, contains('BackendFailurePolicy.canRetryRead(error)'));
      expect(phase4, contains('BackendFailurePolicy.canRetryRead(error)'));
      expect(phase5, contains('BackendFailurePolicy.canRetryRead(error)'));
    });

    test('les logs sensibles ne recopient plus les valeurs metier', () {
      final String logger = source(
        'lib/core/diagnostics/izytel_log.dart',
      );
      final String messaging = source(
        'lib/core/notifications/firebase_messaging_bootstrap.dart',
      );
      final String devices = source(
        'lib/core/notifications/izytel_notification_device_registry.dart',
      );
      final String wave = source(
        'lib/features/payments/presentation/pages/send_wave_link_page.dart',
      );
      final String payments = source(
        'lib/features/payments/presentation/view_models/payments_view_model.dart',
      );

      // Le marqueur historique reste present pour les contrats Phase 1/M5,
      // mais jamais la valeur brute du token.
      expect(messaging, contains('[FCM][token]'));
      expect(messaging, isNot(contains(r'[FCM][token] $_currentToken')));
      expect(messaging, isNot(contains(r'order=${payload.order')));
      expect(devices, isNot(contains(r'uid=$currentUid')));
      expect(wave, isNot(contains('MESSAGE WAVE')));
      expect(payments, isNot(contains("debugPrint('[Payments]")));

      // Un logger ne doit jamais pouvoir casser un flux metier. En particulier,
      // debugPrintStack peut lever une assertion sur certaines traces
      // asynchrones produites par flutter_test/package:stack_trace.
      expect(logger, isNot(contains('debugPrintStack(')));
      expect(logger, contains('Le diagnostic ne doit jamais interrompre'));
    });

    test('le mapper historique ne rajeunit plus les anciennes commandes', () {
      final String mapper = source(
        'lib/features/orders/data/mappers/firestore_order_mapper.dart',
      );

      expect(mapper, contains('_readHistoricalCreatedAt(data)'));
      expect(mapper, contains('DateTime.tryParse(text)'));
      expect(mapper, contains('_enumByNormalizedName'));
      expect(mapper, contains('DateTime.fromMillisecondsSinceEpoch'));
      expect(mapper, isNot(contains('?? DateTime.now()')));
    });

    test('les correctifs de compilation du bloc 1 restent verrouilles', () {
      final String mapper = source(
        'lib/features/orders/data/mappers/firestore_order_mapper.dart',
      );
      final String orders = source(
        'lib/features/orders/data/repositories/firestore_orders_repository.dart',
      );

      expect(mapper, contains('final List<DateTime> candidates = <DateTime?>['));
      expect(orders, contains("import 'dart:typed_data';"));
    });

    test('la Phase 3 ne modifie pas les contrats visuels ou les roles', () {
      final String app = source('lib/app/app.dart');
      final String orders = source(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      expect(app, contains('HybridOrdersRepository'));
      expect(app, contains('HybridDashboardRepository'));
      expect(orders, contains('enableNativeAutoAssignment: false'));
    });
  });
}
