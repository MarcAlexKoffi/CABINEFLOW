import 'dart:convert';
import 'dart:io';

import 'package:cabine_flow/backoffice/data/repositories/supabase_backoffice_finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseBackofficeFinanceRepository repository;
  final Map<String, int> statuses = <String, int>{};
  final List<String> calls = <String>[];

  setUp(() async {
    statuses.clear();
    calls.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((HttpRequest request) async {
      await utf8.decoder.bind(request).join();
      calls.add(request.uri.path);
      final int status = statuses[request.uri.path] ?? 200;
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json;
      if (status == 200) {
        if (request.uri.path.endsWith('izytel_finance_snapshot')) {
          request.response.write(
            jsonEncode(<String, dynamic>{
              'generated_at': '2026-11-01T15:46:00Z',
              'wave_totals': <String, dynamic>{'client_payments': 2500},
              'expenses': <Map<String, dynamic>>[],
            }),
          );
        } else {
          request.response.write(
            jsonEncode(<String, dynamic>{
              'summary': <String, dynamic>{'balanceDue': 75},
              'partners': <Map<String, dynamic>>[],
            }),
          );
        }
      } else {
        request.response.write(
          jsonEncode(<String, dynamic>{
            'code': '42501',
            'message': 'ADMIN_REQUIRED',
          }),
        );
      }
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
    );
    repository = SupabaseBackofficeFinanceRepository(client: client);
  });

  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test('loads the primary and cabiniste snapshots in parallel', () async {
    final snapshot = await repository.fetchSnapshot();

    expect(snapshot.waveTotals?['client_payments'], 2500);
    expect(snapshot.cabinisteDebt, 75);
    expect(snapshot.partialIssueCode, isNull);
    expect(calls, hasLength(2));
  });

  test(
    'keeps primary finance data when the secondary snapshot fails',
    () async {
      statuses['/rest/v1/rpc/izytel_admin_cabiniste_finance_snapshot'] = 403;

      final snapshot = await repository.fetchSnapshot();

      expect(snapshot.waveTotals?['client_payments'], 2500);
      expect(snapshot.cabinisteFinance, isEmpty);
      expect(snapshot.partialIssueCode, 'postgrest:42501');
      expect(snapshot.partialIssueKind, 'forbidden');
    },
  );

  test('never hides a failure of the primary finance snapshot', () async {
    statuses['/rest/v1/rpc/izytel_finance_snapshot'] = 403;

    await expectLater(
      repository.fetchSnapshot(),
      throwsA(
        isA<PostgrestException>().having(
          (PostgrestException error) => error.code,
          'code',
          '42501',
        ),
      ),
    );
  });
}
