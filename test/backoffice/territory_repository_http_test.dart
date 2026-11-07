import 'dart:convert';
import 'package:cabine_flow/backoffice/data/repositories/supabase_territory_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Territorial reads stay GET; explicit reconciliation never calls legacy provisioning',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'public-test',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/rpc/izytel_sync_manager_profiles')) {
            return http.Response('1', 200, request: request);
          }
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('territory_zones')
                  ? [
                      {
                        'id': 'zone',
                        'name': 'Zone test',
                        'city': 'Abidjan',
                        'region': 'Lagunes',
                        'is_active': true,
                        'latitude': 5.3,
                        'longitude': -4.0,
                      },
                    ]
                  : [
                      {
                        'firebase_uid': 'manager',
                        'display_name': 'Manager test',
                        'is_active': true,
                        'is_available': false,
                      },
                    ],
            ),
            200,
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = SupabaseTerritoryRepository(client: client);
      expect((await repository.fetchZones()).single.isPositioned, true);
      expect((await repository.fetchManagers()).single.isAvailable, false);
      expect(requests.map((x) => x.method), everyElement('GET'));
      expect(await repository.syncManagersFromStaffRegistry(), 1);
      expect(
        requests.last.url.path,
        '/rest/v1/rpc/izytel_sync_manager_profiles',
      );
      expect(requests.length, 3);
    },
  );

  test(
    'A refused territorial read is surfaced rather than replaced by an empty directory',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'public-test',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"code":"42501","message":"forbidden"}',
            403,
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseTerritoryRepository(client: client).fetchManagers(),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        SupabaseTerritoryRepository(client: client).fetchZones(),
        throwsA(isA<PostgrestException>()),
      );
    },
  );
}
