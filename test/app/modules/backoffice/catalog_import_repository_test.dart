import 'dart:convert';
import 'dart:typed_data';
import 'package:cabine_flow/app/data/repositories/supabase_admin_offer_repository.dart';
import 'package:cabine_flow/app/domain/entities/offers/catalog_import.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final job = {
    'id': '00000000-0000-4000-8000-000000000001',
    'status': 'preview',
    'total': 4,
    'cursor': 0,
  };
  test(
    'read-only staff or old server gets only the public catalogue projection',
    () async {
      final paths = <String>[];
      final client = SupabaseClient(
        'https://catalog.test',
        'public-test-key',
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('izytel_catalog_offers_admin')) {
            return http.Response(
              jsonEncode({'code': '42501', 'message': 'ADMIN_REQUIRED'}),
              403,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'public-id',
                'network': 'orange',
                'service': 'internetSubscription',
                'operation_type': 'internetSubscription',
                'title': 'Public offer',
                'catalog_label': 'Public offer',
                'selling_price': 1000,
                'is_active': true,
                'details': [],
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final rows = await SupabaseAdminOfferRepository(
        client: client,
      ).fetchOffers();
      expect(rows.single.id, 'public-id');
      expect(rows.single.deliveryProof, isNull);
      expect(paths, [
        '/rest/v1/rpc/izytel_catalog_offers_admin',
        '/rest/v1/catalog_offers',
      ]);
    },
  );
  test(
    'maps old catalogue rows and structured metadata without breaking old IDs',
    () async {
      final client = SupabaseClient(
        'https://catalog.test',
        'public-test-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'id': 'old-id',
                'network': 'orange',
                'service': 'internetSubscription',
                'operation_type': 'internetSubscription',
                'title': '10 Go',
                'catalog_label': 'Orange 10 Go',
                'selling_price': 2500,
                'is_active': true,
                'details': [],
              },
              {
                'id': 'existing-technical-id',
                'network': 'mtn',
                'service': 'calls',
                'operation_type': 'mixedBundle',
                'title': 'Mix',
                'catalog_label': 'Mix',
                'selling_price': 500,
                'is_active': false,
                'details': [],
                'offer_code': 'MT-MIX-001',
                'catalog_status': 'BROUILLON',
                'catalog_version': 7,
                'code_confirmed': true,
                'family_code': 'MIX',
                'catalog_data': {'volume_data': '1.5', 'unite_data': 'GO'},
              },
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      final rows = await SupabaseAdminOfferRepository(
        client: client,
      ).fetchOffers();
      expect(rows[0].id, 'old-id');
      expect(rows[0].stableCode, 'old-id');
      expect(rows[0].statusLabel, 'Active');
      expect(rows[1].id, 'existing-technical-id');
      expect(rows[1].stableCode, 'MT-MIX-001');
      expect(rows[1].statusLabel, 'Brouillon');
      expect(rows[1].catalogVersion, 7);
      expect(rows[1].importData!['volume_data'], '1.5');
    },
  );
  test(
    'file is sent once to server with Firebase bearer, bytes and same retry ID',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://catalog.test',
        'public-test-key',
        httpClient: MockClient((request) async {
          calls.add(request);
          return http.Response(
            jsonEncode({'id': job['id']}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseAdminOfferRepository(
        client: client,
        authToken: () async => 'firebase-test-token',
      );
      final bytes = Uint8List.fromList([80, 75, 3, 4]);
      for (var i = 0; i < 2; i++) {
        expect(
          await repo.prepareImport(
            bytes: bytes,
            fileName: 'offres.xlsx',
            requestId: job['id'] as String,
          ),
          job['id'],
        );
      }
      expect(calls, hasLength(2));
      for (final call in calls) {
        expect(call.url.path, '/functions/v1/izytel-catalog-import');
        expect(
          call.headers['Authorization'] ?? call.headers['authorization'],
          'Bearer firebase-test-token',
        );
        final body = jsonDecode(call.body) as Map;
        expect(body['contentBase64'], base64Encode(bytes));
        expect(body['requestId'], job['id']);
        expect(body.containsKey('role'), false);
      }
    },
  );
  test(
    'RPCs preserve offset, filter, explicit partial consent, versions and importId',
    () async {
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://catalog.test',
        'public-test-key',
        httpClient: MockClient((request) async {
          calls.add(request);
          final result = request.url.path.endsWith('bulk_prepare')
              ? job['id']
              : {
                  'job': job,
                  'summary': {'create': 4, 'error': 0},
                  'lines': [],
                  'filteredTotal': 4,
                };
          return http.Response(
            jsonEncode(result),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final repo = SupabaseAdminOfferRepository(client: client);
      final page = await repo.importPage(
        job['id'] as String,
        offset: 20,
        filter: 'error',
      );
      expect(page.total, 4);
      expect(jsonDecode(calls.last.body), {
        'p_id': job['id'],
        'p_offset': 20,
        'p_filter': 'error',
      });
      await repo.confirmImport(page.id, allowPartial: true);
      expect(jsonDecode(calls.last.body), {
        'p_id': job['id'],
        'p_allow_partial': true,
      });
      await repo.applyImportBatch(page.id);
      expect(calls.last.url.path.endsWith('izytel_catalog_import_apply'), true);
      await repo.restoreImport(page.id);
      expect(
        calls.last.url.path.endsWith('izytel_catalog_import_restore'),
        true,
      );
      await repo.prepareBulk(
        requestId: page.id,
        operation: 'priority',
        value: '2',
        items: [
          {'id': 'existing-id', 'version': 7},
        ],
      );
      expect(catalogMap(jsonDecode(calls.last.body))['p_changes'], {
        'operation': 'priority',
        'value': '2',
        'items': [
          {'id': 'existing-id', 'version': 7},
        ],
      });
    },
  );
  test('oversized files are rejected without any HTTP request', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://catalog.test',
      'public-test-key',
      httpClient: MockClient((_) async {
        calls++;
        throw StateError('Unexpected request');
      }),
    );
    addTearDown(client.dispose);
    final repo = SupabaseAdminOfferRepository(
      client: client,
      authToken: () async => null,
    );
    await expectLater(
      repo.prepareImport(
        bytes: Uint8List(5 * 1024 * 1024 + 1),
        fileName: 'large.xlsx',
        requestId: job['id'] as String,
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });
  test(
    'CSV neutralizes formulas, keeps decimal units; configuration filters by operator',
    () {
      final csv = catalogCsv([
        {
          'code_offre': 'OR-1',
          'nom_affiche': '=HYPERLINK("x")',
          'volume_data': '1.5',
          'unite_data': 'GO',
        },
      ]);
      expect(csv, contains("'=HYPERLINK"));
      expect(csv, contains('"1.5";"GO"'));
      expect(catalogImportHeaders, hasLength(22));
      final config = CatalogImportConfiguration({
        'settings': {'version': 3, 'verification_max_age_days': null},
        'families': [
          {'network': 'ORANGE', 'code': 'OZEN', 'enabled': true},
          {'network': 'MTN', 'code': 'CCHIC', 'enabled': true},
          {'network': 'ORANGE', 'code': 'OLD', 'enabled': false},
        ],
      });
      expect(config.familiesFor('orange'), ['OZEN']);
      expect(config.verificationDays, isNull);
    },
  );
}
