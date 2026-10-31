import 'dart:convert';
import 'dart:io';
import 'package:cabine_flow/features/ussd/data/supabase_ussd_repository.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  final calls = <({String path, Map<String, dynamic> body})>[];
  int responseStatus = 200;
  dynamic response;
  bool missingUssd = false;
  setUp(() async {
    calls.clear();
    responseStatus = 200;
    missingUssd = false;
    response = {'status': 'unavailable', 'reason': 'no_rule'};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
      accessToken: () async => 'synthetic-firebase-token',
    );
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      calls.add((
        path: request.uri.path,
        body: raw.isEmpty
            ? {}
            : Map<String, dynamic>.from(jsonDecode(raw) as Map),
      ));
      request.response.statusCode =
          request.uri.path.endsWith('phase3_sync_order')
          ? 200
          : missingUssd
          ? 404
          : responseStatus;
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.endsWith('phase3_sync_order')) {
        request.response.write(
          jsonEncode({
            'order_id': 'synthetic-order',
            'order_reference': 'TEST-1',
            'network': 'moov',
            'amount': 1000,
            'source': 'operatorApp',
            'client_name': 'Client fictif',
            'beneficiary_phone': '0101010101',
            'operation_type': 'internetSubscription',
            'offer_label': 'Offre fictive',
            'payment_status': 'confirmed',
            'assignment_state': 'waiting',
            'firebase_created_at': '2026-10-31T00:00:00Z',
            'updated_at': '2026-10-31T00:00:00Z',
          }),
        );
      } else {
        request.response.write(
          jsonEncode(
            missingUssd
                ? {'code': 'PGRST202', 'message': 'synthetic RPC not installed'}
                : response,
          ),
        );
      }
      await request.response.close();
    });
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  test(
    'resolver calls only the authorized order RPC, no catalogue-wide client query',
    () async {
      final result = await SupabaseUssdRepository(
        client: client,
      ).resolve('synthetic-order');
      expect(result.available, isFalse);
      expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_resolve');
      expect(calls.single.body, {'p_order_id': 'synthetic-order'});
    },
  );
  test(
    'permission errors are propagated without retry or successful empty fallback',
    () async {
      responseStatus = 403;
      response = {'message': 'synthetic denied', 'code': '42501'};
      await expectLater(
        SupabaseUssdRepository(client: client).resolve('synthetic-order'),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls.length, 1);
    },
  );
  test(
    'admin saves cannot supply an actor UID or activate a draft through payload',
    () async {
      response = 'synthetic-rule';
      await SupabaseUssdRepository(
        client: client,
      ).saveRule({'ussd_template': '*999#'});
      expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_save_rule');
      expect(
        calls.single.body.keys,
        unorderedEquals(['p_rule_id', 'p_expected_version', 'p_payload']),
      );
    },
  );
  test(
    'missing USSD backend does not fail existing order synchronization',
    () async {
      missingUssd = true;
      final order = QueueOrder(
        id: 'synthetic-order',
        reference: 'TEST-1',
        clientName: 'Client fictif',
        clientWhatsappPhone: '',
        network: MobileNetwork.moov,
        beneficiaryPhone: '0101010101',
        operationType: OrderOperationType.internetSubscription,
        offerLabel: 'Offre fictive',
        amount: 1000,
        createdAt: DateTime.utc(2026, 10, 31),
        status: QueueOrderStatus.paidReady,
        paymentStatus: OrderPaymentStatus.confirmed,
        offerId: 'stable-offer-id',
      );
      final result = await SupabasePhase4AssignmentRepository(
        client: client,
      ).syncOrder(order);
      expect(result.orderId, 'synthetic-order');
      expect(calls.length, 2);
      expect(calls.first.body.containsKey('p_offer_id'), isFalse);
      expect(
        calls.last.path,
        '/rest/v1/rpc/izytel_ussd_register_order_context',
      );
      expect(calls.last.body, {
        'p_order_id': 'synthetic-order',
        'p_offer_id': 'stable-offer-id',
      });
    },
  );
  test(
    'legacy orders without stable offer ID make no optional USSD write',
    () async {
      final order = QueueOrder(
        id: 'synthetic-order',
        reference: 'TEST-1',
        clientName: 'Client fictif',
        clientWhatsappPhone: '',
        network: MobileNetwork.moov,
        beneficiaryPhone: '0101010101',
        operationType: OrderOperationType.internetSubscription,
        offerLabel: 'Offre fictive',
        amount: 1000,
        createdAt: DateTime.utc(2026, 10, 31),
        status: QueueOrderStatus.paidReady,
        paymentStatus: OrderPaymentStatus.confirmed,
      );
      await SupabasePhase4AssignmentRepository(client: client).syncOrder(order);
      expect(calls.length, 1);
    },
  );
}
