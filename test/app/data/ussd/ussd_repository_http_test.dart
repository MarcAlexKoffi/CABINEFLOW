import 'dart:convert';
import 'dart:io';
import 'package:cabine_flow/app/data/repositories/supabase_ussd_repository.dart';
import 'package:cabine_flow/app/domain/policies/ussd/ussd_engine.dart';
import 'package:cabine_flow/app/data/repositories/supabase_phase4_assignment_repository.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../support/ussd_test_doubles.dart';

Map<String, dynamic> assignmentRow() => {
  'order_id': 'synthetic-order',
  'order_reference': 'TEST-1',
  'network': 'moov',
  'amount': 1000,
  'assignment_version': 7,
  'assignment_route': 'shared',
  'assignment_state': 'waiting',
  'order_status': 'paidReady',
  'source': 'operatorApp',
  'operation_type': 'internetSubscription',
  'payment_status': 'confirmed',
  'updated_at': '2026-11-19T00:00:00Z',
  'firebase_created_at': '2026-11-19T00:00:00Z',
};

void main() {
  late HttpServer server;
  late SupabaseClient client;
  final calls = <({String path, Map<String, dynamic> body})>[];
  int responseStatus = 200;
  dynamic response;
  bool missingUssd = false;
  String? authorization;
  String? executionHeader;
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
      executionHeader = request.headers.value('x-izytel-execution-key');
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
                : request.uri.path.endsWith('izytel_begin_order_execution') &&
                      response is Map
                ? {
                    ...response as Map,
                    'ready':
                        calls
                            .where(
                              (c) => c.path.endsWith(
                                'izytel_begin_order_execution',
                              ),
                            )
                            .length >
                        1,
                  }
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
    'USSD no-execution confirmation is sent explicitly in the preparation RPC context',
    () async {
      final repository = SupabaseUssdRepository(
        executionKey: () async => 'synthetic-device-execution-key',
        client: client,
      );
      final resolution = syntheticResolution();
      await repository.prepare('synthetic-order', resolution, 'first');
      expect(
        (calls.last.body['p_context'] as Map).containsKey(
          '_ussd_not_executed_confirmed',
        ),
        isFalse,
      );
      await repository.prepare(
        'synthetic-order',
        resolution,
        'retry',
        confirmNotExecuted: true,
      );
      expect(calls.last.body['p_context'], {
        ...resolution.context,
        '_ussd_not_executed_confirmed': true,
      });
    },
  );
  test(
    'resolver calls only the authorized order RPC, no catalogue-wide client query',
    () async {
      final result = await SupabaseUssdRepository(
        executionKey: () async => 'synthetic-device-execution-key',
        client: client,
      ).resolve('synthetic-order');
      expect(result.available, isFalse);
      expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_resolve');
      expect(calls.single.body, {'p_order_id': 'synthetic-order'});
      expect(authorization, 'Bearer synthetic-firebase-token');
      expect(executionHeader, 'synthetic-device-execution-key');
    },
  );
  test(
    'execution waits for server readiness and keeps the same request key and version',
    () async {
      final key = 'a' * 64;
      response = {
        'retry_after_ms': 1,
        'order': {
          'order_id': 'synthetic-order',
          'order_reference': 'TEST-1',
          'network': 'moov',
          'amount': 1000,
          'assignment_version': 7,
          'assignment_state': 'accepted',
          'assigned_agent_id': 'test-agent',
          'order_status': 'inProgress',
          'source': 'operatorApp',
          'operation_type': 'internetSubscription',
          'payment_status': 'confirmed',
          'updated_at': '2026-11-19T00:00:00Z',
          'firebase_created_at': '2026-11-19T00:00:00Z',
        },
      };
      final repository = SupabasePhase4AssignmentRepository(
        client: client,
        executionKey: () async => key,
      );
      final started = await repository.startProcessing(
        'synthetic-order',
        expectedVersion: 7,
      );
      expect(started.assignmentVersion, 7);
      expect(started.orderStatus, QueueOrderStatus.inProgress);
      expect(calls.length, 2);
      for (final call in calls) {
        expect(call.path, '/rest/v1/rpc/izytel_begin_order_execution');
        expect(call.body, {
          'p_order_id': 'synthetic-order',
          'p_expected_version': 7,
          'p_request_id': key,
        });
      }
      expect(executionHeader, key);
    },
  );
  test(
    'missing Firebase identity becomes an explicit session error with no retry',
    () async {
      responseStatus = 401;
      response = {'code': '42501', 'message': 'USSD_AUTH_REQUIRED'};
      await expectLater(
        SupabaseUssdRepository(
          executionKey: () async => 'synthetic-device-execution-key',
          client: client,
        ).configuration(),
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
    'requeue retries keep the key until the server confirms the result',
    () async {
      final operations = <String>[];
      final finished = <String>[];
      final key = 'c' * 64;
      final repository = SupabasePhase4AssignmentRepository(
        client: client,
        operationKey: (operation) async {
          operations.add(operation);
          return key;
        },
        finishOperation: (operation) async {
          finished.add(operation);
        },
      );
      responseStatus = 500;
      response = {'code': 'XX000', 'message': 'synthetic interrupted response'};
      await expectLater(
        repository.returnToQueue(' synthetic-order ', 'Zone'),
        throwsA(isA<PostgrestException>()),
      );
      expect(finished, isEmpty);
      responseStatus = 200;
      response = assignmentRow();
      final result = await repository.returnToQueue('synthetic-order', 'Zone');
      expect(result.assignmentRoute, 'shared');
      expect(operations, [
        'requeue.synthetic-order',
        'requeue.synthetic-order',
      ]);
      expect(finished, ['requeue.synthetic-order']);
      expect(calls, hasLength(2));
      for (final call in calls) {
        expect(call.path, '/rest/v1/rpc/izytel_return_order_to_queue');
        expect(call.body, {
          'p_order_id': 'synthetic-order',
          'p_reason': 'Zone',
          'p_request_id': key,
        });
      }
    },
  );

  test(
    'a requeue response for another order never clears the retry key',
    () async {
      final finished = <String>[];
      response = assignmentRow()..['order_id'] = 'another-order';
      final repository = SupabasePhase4AssignmentRepository(
        client: client,
        operationKey: (_) async => 'c' * 64,
        finishOperation: (operation) async {
          finished.add(operation);
        },
      );
      await expectLater(
        repository.returnToQueue('synthetic-order', 'Zone'),
        throwsA(isA<FormatException>()),
      );
      expect(finished, isEmpty);
    },
  );

  test(
    'replaying a requeue after another acceptance requires a refresh',
    () async {
      response = assignmentRow()
        ..['assignment_state'] = 'accepted'
        ..['assigned_agent_id'] = 'another-agent';
      final repository = SupabasePhase4AssignmentRepository(
        client: client,
        operationKey: (_) async => 'c' * 64,
        finishOperation: (_) async {},
      );
      await expectLater(
        repository.returnToQueue('synthetic-order', 'Zone'),
        throwsA(isA<StateError>()),
      );
      expect(calls, hasLength(1));
    },
  );

  for (final invalid in [
    {'order_id': 'another-order'},
    {'assignment_version': 6},
    {'order_status': 'failed'},
  ]) {
    test('an inconsistent execution response is rejected: $invalid', () async {
      response = {
        'retry_after_ms': 1,
        'order': assignmentRow()
          ..['assignment_state'] = 'accepted'
          ..['order_status'] = 'inProgress'
          ..addAll(invalid),
      };
      await expectLater(
        SupabasePhase4AssignmentRepository(
          client: client,
          executionKey: () async => 'a' * 64,
        ).startProcessing('synthetic-order', expectedVersion: 7),
        throwsA(isA<FormatException>()),
      );
    });
  }
  test(
    'malformed configuration fails in the read Future for an explicit retry state',
    () async {
      response = {'rules': [], 'families': 'invalid-shape', 'offers': []};
      await expectLater(
        SupabaseUssdRepository(
          executionKey: () async => 'synthetic-device-execution-key',
          client: client,
        ).configuration(),
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
        SupabaseUssdRepository(
          executionKey: () async => 'synthetic-device-execution-key',
          client: client,
        ).resolve('synthetic-order'),
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
        SupabaseUssdRepository(
          executionKey: () async => 'synthetic-device-execution-key',
          client: client,
        ).resolve('synthetic-order'),
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
        executionKey: () async => 'synthetic-device-execution-key',
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
      await SupabaseUssdRepository(
        executionKey: () async => 'synthetic-device-execution-key',
        client: client,
      ).saveRule({
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
    await SupabaseUssdRepository(
      executionKey: () async => 'synthetic-device-execution-key',
      client: client,
    ).saveRule({
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
      await SupabaseUssdRepository(
        executionKey: () async => 'synthetic-device-execution-key',
        client: client,
      ).deleteRule(rule);
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
      executionKey: () async => 'synthetic-device-execution-key',
      client: client,
    ).deleteFamily('synthetic-family');
    expect(calls.single.path, '/rest/v1/rpc/izytel_ussd_delete_family');
    expect(calls.single.body, {'p_family_id': 'synthetic-family'});
  });
  test('binding deletion preserves optimistic version checking', () async {
    response = null;
    await SupabaseUssdRepository(
      executionKey: () async => 'synthetic-device-execution-key',
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
          executionKey: () async => 'synthetic-device-execution-key',
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
