import 'dart:convert';
import 'dart:io';

import 'package:cabine_flow/app/data/repositories/supabase_customer_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_order_draft.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_service.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  var bonusUnavailable = false;
  var projectionReads = 0;
  setUp(() async {
    bonusUnavailable = false;
    projectionReads = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/rest/v1/rpc/izytel_public_offer_bonuses') {
        projectionReads++;
        final now = DateTime.now().toUtc();
        request.response.statusCode = bonusUnavailable ? 503 : 200;
        request.response.write(
          jsonEncode(
            bonusUnavailable
                ? {'code': 'PGRST000', 'message': 'synthetic unavailable'}
                : {
                    'server_now': now.toIso8601String(),
                    'promotions': [
                      {
                        'offer_id': 'stable-cchic',
                        'base_volume_mb': 750,
                        'total_volume_mb': 2250,
                        'bonus_kind': 'percentage',
                        'bonus_value': 200,
                        'valid_until': now
                            .add(const Duration(seconds: 30))
                            .toIso8601String(),
                      },
                    ],
                  },
          ),
        );
      } else {
        expect(request.method, 'GET');
        request.response.write(
          jsonEncode([
            {
              'id': 'stable-cchic',
              'network': 'mtn',
              'service': 'calls',
              'operation_type': 'mixedBundle',
              'category': 'cchic',
              'title': 'C’CHIC test',
              'catalog_label': 'C’CHIC',
              'selling_price': 800,
              'details': ['750 Mo'],
            },
          ]),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'reload reads a fresh server projection and preserves canonical order type',
    () async {
      final repo = SupabaseCustomerOfferRepository(client: client);
      for (var i = 0; i < 2; i++) {
        final offer = (await repo.fetchOffers(
          service: CustomerService.calls,
          network: MobileNetwork.mtn,
        )).single;
        expect(offer.category, 'cchic');
        expect(offer.amount, 800);
        expect(offer.details, ['750 Mo']);
        expect(offer.displayDetails, contains('Volume total : 2,25 Go'));
        expect(
          CustomerOrderDraft(
            service: CustomerService.calls,
            offer: offer,
          ).operationType,
          OrderOperationType.mixedBundle,
        );
      }
      expect(projectionReads, 2);
    },
  );

  test(
    'a failed refresh removes the previous bonus and retains the base catalogue',
    () async {
      final repo = SupabaseCustomerOfferRepository(client: client);
      expect(
        (await repo.fetchOffers(
          service: CustomerService.calls,
          network: MobileNetwork.mtn,
        )).single.bonus,
        isNotNull,
      );
      bonusUnavailable = true;
      final offer = (await repo.fetchOffers(
        service: CustomerService.calls,
        network: MobileNetwork.mtn,
      )).single;
      expect(offer.bonus, isNull);
      expect(offer.displayBadge, isNull);
      expect(offer.displayDetails, ['750 Mo']);
      expect(offer.amount, 800);
    },
  );
}
