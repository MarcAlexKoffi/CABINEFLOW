import 'dart:convert';

import 'package:cabine_flow/app/data/repositories/supabase_agent_issue_repository.dart';
import 'package:cabine_flow/app/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/app/data/repositories/supabase_shared_order_queue_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'queue decodes the total and sends the stable cursor for the next page',
    () async {
      final cursors = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/rest/v1/rpc/izytel_shared_available_page');
          final parameters = jsonDecode(request.body) as Map<String, dynamic>;
          cursors.add(parameters);
          final second = parameters['p_after_order_id'] != null;
          final row = {
            'order_id': second ? 'last' : 'first',
            'order_reference': 'TEST',
            'zone_id': 'zone-test',
            'network': 'orange',
            'operation_type': 'unitTransfer',
            'offer_label': 'Test',
            'amount': 200,
            'beneficiary_masked': '•••• 0000',
            'available_at': '2026-11-20T00:00:00Z',
            'assignment_version': 0,
            'can_accept': true,
          };
          return http.Response(
            jsonEncode({
              'orders': [row],
              'total_count': 109,
              'enabled': true,
              'server_now': '2026-11-20T00:00:01Z',
              'next_cursor': second
                  ? null
                  : {
                      'available_at': row['available_at'],
                      'order_id': row['order_id'],
                    },
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      try {
        final repository = SupabaseSharedOrderQueueRepository(client: client);
        final first = await repository.fetchAvailableOrders();
        expect(first.totalCount, 109);
        expect(first.orders.length, 1);
        final last = await repository.fetchAvailableOrders(
          after: first.nextCursor,
        );
        expect(last.orders.single.id, 'last');
        expect(last.nextCursor, isNull);
        expect(cursors.last['p_after_order_id'], 'first');
        expect(
          cursors.last['p_after_available_at'],
          '2026-11-20T00:00:00.000Z',
        );
      } finally {
        await client.dispose();
      }
    },
  );
  test(
    'Agent and Manager operational reads decode the Data API payloads',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final table = request.url.pathSegments.last;
          final payload = switch (table) {
            'agent_issues' => [
              {
                'id': 'issue-test',
                'agent_id': 'agent-test',
                'description': 'Signalement test',
                'created_at': '2026-11-20T00:00:00Z',
                'status': 'open',
                'type': 'other',
              },
            ],
            'phase5_commissions' => [
              {
                'order_id': 'order-test',
                'agent_id': 'agent-test',
                'network': 'orange',
                'order_amount': 200,
                'commission_amount': 10,
                'earned_at': '2026-11-20T00:00:00Z',
              },
            ],
            'phase5_commission_accounts' => [
              {
                'agent_id': 'agent-test',
                'earned_total': 40,
                'paid_total': 0,
                'earned_transactions': 4,
                'updated_at': '2026-11-20T00:00:00Z',
              },
            ],
            'phase5_network_movements' => [
              {
                'id': 'move-test',
                'agent_id': 'agent-test',
                'network': 'orange',
                'amount': 200,
                'occurred_at': '2026-11-20T00:00:00Z',
              },
            ],
            'phase5_agent_commission_summary' => [
              {
                'earned_total': 40,
                'paid_total': 0,
                'balance': 40,
                'earned_transactions': 4,
                'earned_this_month': 40,
              },
            ],
            _ => <Object>[],
          };
          return http.Response(
            jsonEncode(payload),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      try {
        final finance = SupabasePhase5FinanceRepository(client: client);
        final issues = SupabaseAgentIssueRepository(client: client);
        expect(
          (await issues.watchAgentIssues('agent-test').first).single.id,
          'issue-test',
        );
        expect(
          (await issues.watchAllAgentIssues().first).single.id,
          'issue-test',
        );
        for (final agentId in ['agent-test', null]) {
          expect(
            (await finance.fetchCommissions(
              agentId: agentId,
            )).single.commissionAmount,
            10,
          );
          expect(
            (await finance.fetchCommissionAccounts(
              agentId: agentId,
            )).single.earnedTransactions,
            4,
          );
          expect(
            (await finance.fetchNetworkMovements(
              agentId: agentId,
            )).single.amount,
            200,
          );
          expect(
            await finance.fetchCommissionPayouts(agentId: agentId),
            isEmpty,
          );
        }
        expect((await finance.fetchAgentCommissionSummary()).balance, 40);
        expect(
          requests
              .where((uri) => uri.path.endsWith('phase5_commissions'))
              .first
              .queryParameters['agent_id'],
          'eq.agent-test',
        );
      } finally {
        await client.dispose();
      }
    },
  );
}
