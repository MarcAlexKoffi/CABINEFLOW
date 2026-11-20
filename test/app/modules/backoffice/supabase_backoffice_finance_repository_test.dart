import 'dart:convert';
import 'dart:io';

import 'package:cabine_flow/app/data/repositories/supabase_backoffice_finance_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseBackofficeFinanceRepository repository;
  final Map<String, int> statuses = <String, int>{};
  final List<String> calls = <String>[];
  bool incomplete = false;

  setUp(() async {
    statuses.clear();
    calls.clear();
    incomplete = false;
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
              if (!incomplete) 'global_totals': <String, dynamic>{},
              'day_totals': <String, dynamic>{},
              'cabiniste_finance': {
                'summary': {'balanceDue': 75},
                'partners': [],
              },
            }),
          );
        } else {
          request.response.write(
            jsonEncode(<String, dynamic>{
              'totals': <String, dynamic>{
                'expenses': 14707,
                'expenses_count': 2101,
              },
              'expenses': [],
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

  test(
    'balances and Cabiniste liability come from a single consistent RPC',
    () async {
      final snapshot = await repository.fetchSnapshot();

      expect(snapshot.waveTotals?['client_payments'], 2500);
      expect(snapshot.cabinisteDebt, 75);
      expect(snapshot.partialIssueCode, isNull);
      expect(calls, ['/rest/v1/rpc/izytel_finance_snapshot']);
    },
  );

  test(
    'never displays an incomplete consolidated snapshot as zero liability',
    () async {
      incomplete = true;
      await expectLater(repository.fetchSnapshot(), throwsStateError);
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

  test(
    'period history transports exact totals independently of its detail window',
    () async {
      final period = await repository.fetchPeriodHistory(
        module: 'expenses',
        start: DateTime.utc(2026, 11, 2),
        end: DateTime.utc(2026, 11, 3),
      );
      expect(period['totals']['expenses'], 14707);
      expect(period['totals']['expenses_count'], 2101);
      expect(calls, ['/rest/v1/rpc/izytel_bo75_finance_period_history']);
    },
  );
}
