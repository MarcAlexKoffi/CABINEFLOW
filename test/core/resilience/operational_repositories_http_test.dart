import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cabine_flow/features/customer_order/data/repositories/supabase_customer_offer_repository.dart';
import 'package:cabine_flow/features/customer_order/domain/models/customer_service.dart';
import 'package:cabine_flow/features/messaging/data/repositories/supabase_customer_messaging_repository.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/support/data/repositories/supabase_support_request_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

void main() {
  late HttpServer server;
  late SupabaseClient client;
  final requests = <Uri>[];
  var status = 200;
  List<Map<String, Object?>> rows = [];

  setUp(() async {
    requests.clear();
    status = 200;
    rows = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (!request.uri.path.startsWith('/rest/v1/')) {
        request.response.statusCode = 503;
        await request.response.close();
        return;
      }
      requests.add(request.uri);
      expect(
        request.method,
        'GET',
        reason: 'Reads must never mutate server data',
      );
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = status;
      request.response.write(
        jsonEncode(
          status == 200
              ? rows
              : {
                  'code': status == 403 ? '42501' : 'PGRST000',
                  'message': 'test failure',
                },
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
    );
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'catalogue: les requetes ciblent les offres actives et chaque reseau/type',
    () async {
      final repository = SupabaseCustomerOfferRepository(client: client);
      for (final network in MobileNetwork.values) {
        for (final service in [
          CustomerService.internetSubscription,
          CustomerService.calls,
        ]) {
          rows = [_offer(network.name, service.name)];
          final values = await repository.fetchOffers(
            service: service,
            network: network,
          );
          expect(values.single.network, network);
          expect(values.single.title, 'Offre test');
          expect(requests.last.queryParameters['is_active'], 'eq.true');
          expect(
            requests.last.queryParameters['network'],
            'eq.${network.name}',
          );
          expect(
            requests.last.queryParameters['service'],
            'eq.${service.name}',
          );
        }
      }
    },
  );

  test(
    'catalogue: erreur HTTP puis nouvel abonnement reussi, sans donnees fictives',
    () async {
      final repository = SupabaseCustomerOfferRepository(client: client);
      status = 503;
      await expectLater(
        repository.watchAllOffers().first,
        throwsA(isA<PostgrestException>()),
      );
      status = 200;
      rows = [_offer('moov', 'calls')];
      final values = await repository.watchAllOffers().first;
      expect(values.single.id, 'offer-moov-calls');
    },
  );

  test('un refus SQL est remonte, jamais converti en catalogue vide', () async {
    status = 403;
    final repository = SupabaseCustomerOfferRepository(client: client);
    await expectLater(
      repository.watchAllOffers().first,
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
  });

  test(
    'messagerie: attend la session restauree et filtre le client courant',
    () async {
      rows = [_conversation()];
      final repository = SupabaseCustomerMessagingRepository(
        client: client,
        firebaseAuth: _RestoringAuth(),
      );
      final values = await repository.watchCustomerConversations().first;
      expect(values.single.id, 'conversation-test');
      expect(
        requests.last.queryParameters['customer_auth_uid'],
        'eq.customer-test',
      );
    },
  );

  test(
    'messagerie Manager et messages: lecture canonique meme sans WebSocket',
    () async {
      final repository = SupabaseCustomerMessagingRepository(
        client: client,
        firebaseAuth: _RestoringAuth(),
      );
      rows = [_conversation()];
      expect(
        (await repository.watchManagerInbox().first).single.id,
        'conversation-test',
      );
      expect(
        requests.last.queryParameters.containsKey('customer_auth_uid'),
        isFalse,
      );
      rows = [
        {
          'id': 'message-test',
          'conversation_id': 'conversation-test',
          'body': 'Message test',
          'sender_type': 'manager',
          'created_at': '2026-10-30T10:00:00Z',
        },
      ];
      expect(
        (await repository
                .watchMessages(conversationId: 'conversation-test')
                .first)
            .single
            .body,
        'Message test',
      );
      expect(
        requests.last.queryParameters['conversation_id'],
        'eq.conversation-test',
      );
    },
  );

  test(
    'support: absence de donnees et refus sont deux resultats distincts',
    () async {
      final repository = SupabaseSupportRequestRepository(client: client);
      expect(await repository.watchAllRequests().first, isEmpty);
      status = 403;
      await expectLater(
        repository.watchAllRequests().first,
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}

Map<String, Object?> _offer(String network, String service) => {
  'id': 'offer-$network-$service',
  'network': network,
  'service': service,
  'title': 'Offre test',
  'catalog_label': 'Catalogue test',
  'selling_price': 500,
  'details': ['Test'],
};
Map<String, Object?> _conversation() => {
  'id': 'conversation-test',
  'customer_auth_uid': 'customer-test',
  'status': 'open',
  'last_message_at': '2026-10-30T10:00:00Z',
  'created_at': '2026-10-30T10:00:00Z',
  'updated_at': '2026-10-30T10:00:00Z',
};

class _RestoringAuth implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() async* {
    yield null;
    yield _Customer();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Customer implements User {
  @override
  String get uid => 'customer-test';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
