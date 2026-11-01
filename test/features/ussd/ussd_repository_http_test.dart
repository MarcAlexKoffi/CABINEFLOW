import 'dart:convert';
import 'dart:io';
import 'package:cabine_flow/features/ussd/data/supabase_ussd_repository.dart';
import 'package:cabine_flow/features/ussd/domain/ussd_engine.dart';
import 'package:cabine_flow/features/orders/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ussd_test_doubles.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  final calls = <({String path, Map<String, dynamic> body})>[];
  int responseStatus = 200;
  dynamic response;
  bool missingUssd = false;
  String? authorization;
  setUp(() async {
    calls.clear();
    responseStatus = 200;
    missingUssd = false;
    authorization = null;
    response = {'status': 'unavailable', 'reason': 'no_rule'};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
      accessToken: () async => 'synthetic-firebase-token',
    );
    server.listen((request) async {
      authorization = request.headers.value(HttpHeaders.authorizationHeader);
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
      expect(authorization, 'Bearer synthetic-firebase-token');
    },
  );
  test(
    'missing Firebase identity becomes an explicit session error with no retry',
    () async {
      responseStatus = 401;
      response = {'code': '42501', 'message': 'USSD_AUTH_REQUIRED'};
      await expectLater(
        SupabaseUssdRepository(client: client).configuration(),
        throwsA(
          isA<UssdValidationException>().having(
            (e) => e.code,
            'code',
            'authentication_required',
          ),
        ),
      );
      expect(calls.length, 1);
    },
  );
  test(
    'malformed configuration fails in the read Future for an explicit retry state',
    () async {
      response = {'rules': [], 'families': 'invalid-shape', 'offers': []};
      await expectLater(
        SupabaseUssdRepository(client: client).configuration(),
        throwsA(isA<FormatException>()),
      );
    },
  );
  test(
    'malformed available context is rejected before rendering the card',
    () async {
      final config = await UssdTestRepository().configuration();
      final rule = Map<String, dynamic>.from(
        (config['rules'] as List).first as Map,
      )..['status'] = 'active';
      response = {
        'status': 'available',
        'reason': '',
        'rule': rule,
        'code': '*999#',
        'context': {'network': 42},
      };
      await expectLater(
        SupabaseUssdRepository(client: client).resolve('synthetic-order'),
        throwsA(isA<FormatException>()),
      );
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
    'save normalizes human variables and omits legacy order purpose',
    () async {
      response = 'synthetic-rule';
      await SupabaseUssdRepository(client: client).saveRule({
        'purpose': 'order',
        'ussd_template': '*410*numéro*montant*code_secret#',
      });
      final payload = calls.single.body['p_payload'] as Map;
      expect(
        payload['ussd_template'],
        '*410*{{msisdn_local}}*{{amount}}*{{secret_code}}#',
      );
      expect(payload.containsKey('purpose'), isFalse);
    },
  );
  test('balance saves retain their explicit purpose', () async {
    response = 'synthetic-rule';
    await SupabaseUssdRepository(client: client).saveRule({
      'purpose': 'balance',
      'service': null,
      'ussd_template': '*414*code secret#',
    });
    final payload = calls.single.body['p_payload'] as Map;
    expect(payload['purpose'], 'balance');
    expect(payload['service'], isNull);
    expect(payload['ussd_template'], '*414*{{secret_code}}#');
  });
  test(
    'rule deletion sends the stable ID and confirmed version only',
    () async {
      response = null;
      final rule = syntheticResolution().rule!;
      await SupabaseUssdRepository(client: client).deleteRule(rule);
      expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_delete_rule');
      expect(calls.single.body, {
        'p_rule_id': rule.id,
        'p_expected_version': rule.version,
      });
      expect(authorization, 'Bearer synthetic-firebase-token');
    },
  );
  test('family deletion sends only its stable ID', () async {
    response = null;
    await SupabaseUssdRepository(
      client: client,
    ).deleteFamily('synthetic-family');
    expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_delete_family');
    expect(calls.single.body, {'p_family_id': 'synthetic-family'});
  });
  test('binding deletion preserves optimistic version checking', () async {
    response = null;
    await SupabaseUssdRepository(
      client: client,
    ).deleteBinding('synthetic-offer', 7);
    expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_delete_binding');
    expect(calls.single.body, {
      'p_offer_id': 'synthetic-offer',
      'p_expected_version': 7,
    });
  });
  test(
    'deletion rejection is propagated once without an automatic retry',
    () async {
      responseStatus = 403;
      response = {'message': 'USSD_ADMIN_REQUIRED', 'code': '42501'};
      await expectLater(
        SupabaseUssdRepository(
          client: client,
        ).deleteRule(syntheticResolution().rule!),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls.length, 1);
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
