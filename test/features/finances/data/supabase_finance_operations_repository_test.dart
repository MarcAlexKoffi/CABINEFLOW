import 'dart:convert';
import 'dart:io';
import 'package:cabine_flow/features/finances/data/repositories/supabase_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseFinanceOperationsRepository repository;
  final calls = <({String path, Map<String, dynamic> body})>[];
  Object? result = 'synthetic-operation';
  int status = 200;
  Future<Object?> Function(Map<String, dynamic>)? page;
  setUp(() async {
    calls.clear();
    result = 'synthetic-operation';
    status = 200;
    page = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      final body = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      calls.add((path: request.uri.path, body: body));
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = status;
      request.response.write(
        jsonEncode(
          status == 200
              ? (page == null ? result : await page!(body))
              : <String, dynamic>{'code': '42501', 'message': 'ADMIN_REQUIRED'},
        ),
      );
      await request.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'synthetic-public-key',
    );
    repository = SupabaseFinanceOperationsRepository(client: client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'retrying a draft retains its key while a new intention gets a new key',
    () async {
      final draft = FinanceExpenseDraft(
        category: FinanceExpenseCategory.transport,
        amount: 1500,
        description: 'Mission',
        channel: FinancePaymentChannel.cash,
      );
      await repository.recordExpense(draft: draft, staffId: '', staffName: '');
      await repository.recordExpense(draft: draft, staffId: '', staffName: '');
      await repository.recordExpense(
        draft: FinanceExpenseDraft(
          category: FinanceExpenseCategory.transport,
          amount: 1500,
          description: 'Mission',
          channel: FinancePaymentChannel.cash,
        ),
        staffId: '',
        staffName: '',
      );
      expect(
        calls[0].body['p_operation_key'],
        calls[1].body['p_operation_key'],
      );
      expect(
        calls[0].body['p_operation_key'],
        isNot(calls[2].body['p_operation_key']),
      );
    },
  );

  test(
    'credit authorizes the real order through the canonical server transaction',
    () async {
      final order = QueueOrder(
        id: 'o1',
        reference: 'O-1',
        clientName: 'Client',
        clientWhatsappPhone: '0700000000',
        network: MobileNetwork.moov,
        beneficiaryPhone: '0700000000',
        operationType: OrderOperationType.unitTransfer,
        offerLabel: 'Crédit',
        amount: 5000,
        createdAt: DateTime.utc(2026, 11, 1),
        status: QueueOrderStatus.awaitingPayment,
      );
      repository = SupabaseFinanceOperationsRepository(
        client: client,
        loadOrder: (_) async => order,
      );
      await repository.createCustomerCredit(
        draft: const CustomerCreditDraft(
          orderId: 'o1',
          orderReference: 'O-1',
          clientName: 'Client',
          clientWhatsappPhone: '0700000000',
          amount: 5000,
        ),
        staffId: 'ignored',
        staffName: 'ignored',
      );
      expect(
        calls.single.path,
        '/rest/v1/rpc/izytel_finance_authorize_credit_order',
      );
      expect(
        calls.single.body['p_payload']['original_order_status'],
        'awaitingPayment',
      );
      calls.clear();
      await expectLater(
        repository.createCustomerCredit(
          draft: const CustomerCreditDraft(
            orderId: 'o1',
            orderReference: 'O-1',
            clientName: 'Client',
            clientWhatsappPhone: '',
            amount: 1,
          ),
          staffId: '',
          staffName: '',
        ),
        throwsStateError,
      );
      expect(calls, isEmpty);
    },
  );

  test(
    'closing normalizes the mobile day and sends only counted cash, not client totals',
    () async {
      const draft = DailyFinancialClosingDraft(
        dateKey: '20261101',
        clientReceipts: 999,
        successfulOrdersCount: 999,
        successfulOrdersAmount: 999,
        supplierRechargePrincipal: 999,
        supplierRechargeBonus: 999,
        supplierRechargeReceived: 999,
        supplierPayments: 999,
        creditsCreated: 999,
        creditSettlements: 999,
        customerReceivables: 999,
        expenses: 999,
        refunds: 999,
        commissionsEarned: 999,
        commissionsPaid: 999,
        orangeAvailable: 999,
        orangeCommitted: 999,
        mtnAvailable: 999,
        mtnCommitted: 999,
        moovAvailable: 999,
        moovCommitted: 999,
        supplierDebt: 999,
        commissionDebt: 999,
        waveTheoreticalBalance: 999,
        waveActualBalance: 12500,
        estimatedProfit: 999,
        waveDifferenceNote: 'Comptage réel',
      );
      await repository.createDailyClosing(
        draft: draft,
        staffId: 'ignored',
        staffName: 'ignored',
      );
      expect(calls.single.path, '/rest/v1/rpc/izytel_finance_create_closing');
      expect(calls.single.body['p_payload'], {
        'date_key': '2026-11-01',
        'wave_actual_balance': 12500,
        'wave_difference_note': 'Comptage réel',
      });
    },
  );

  test(
    'mobile expenses use canonical server command and never a Firestore mirror',
    () async {
      final id = await repository.recordExpense(
        draft: const FinanceExpenseDraft(
          category: FinanceExpenseCategory.transport,
          amount: 1500,
          description: 'Mission',
          channel: FinancePaymentChannel.wave,
        ),
        staffId: 'untrusted-client-actor',
        staffName: 'Client name',
      );
      expect(id, 'synthetic-operation');
      expect(
        calls.single.path,
        '/rest/v1/rpc/izytel_finance_record_expense_once',
      );
      expect(calls.single.body['p_amount'], 1500);
      expect(calls.single.body.containsKey('p_staff_id'), false);
    },
  );
  test(
    'mobile Wave adjustment is the same privileged RPC as Back-office',
    () async {
      await repository.setWaveOpeningBalance(
        amount: 12500,
        staffId: 'ignored',
        staffName: 'ignored',
        note: 'Counted',
      );
      expect(calls.single.path, '/rest/v1/rpc/izytel_finance_set_wave_opening');
      expect(calls.single.body, {'p_amount': 12500, 'p_note': 'Counted'});
    },
  );
  test(
    'credit settlement stays in canonical ledger with supplied reference',
    () async {
      await repository.settleCustomerCredit(
        creditId: 'credit-1',
        amount: 2500,
        channel: FinancePaymentChannel.cash,
        reference: 'REF-1',
        staffId: 'ignored',
        staffName: 'ignored',
      );
      expect(calls.single.path, '/rest/v1/rpc/izytel_finance_settle_credit');
      expect(calls.single.body['p_reference'], 'REF-1');
      expect(calls.single.body['p_channel'], 'cash');
    },
  );
  test('pagination returns every row beyond the API page limit', () async {
    page = (body) async {
      final after = int.tryParse(body['p_after']?.toString() ?? '') ?? -1;
      return List.generate(
        after < 0 ? 250 : 3,
        (i) => {'id': (after + i + 1).toString().padLeft(4, '0'), 'amount': 1},
      );
    };
    final rows = await repository.fetchRows('expenses');
    expect(rows.length, 253);
    expect(calls.length, 2);
    expect(calls.last.body['p_after'], '0249');
  });
  test(
    'permission errors propagate and are never presented as an empty register',
    () async {
      status = 403;
      await expectLater(
        repository.fetchRows('expenses'),
        throwsA(isA<PostgrestException>()),
      );
      expect(calls.length, 1);
    },
  );
  test('malformed pagination response fails explicitly', () async {
    result = {'unexpected': 'shape'};
    await expectLater(repository.fetchRows('credits'), throwsStateError);
  });
  test(
    'Wave refuses a server without exact aggregates instead of summing a truncated history',
    () async {
      // fetchSnapshot requests both snapshot and partner snapshot.
      result = <String, dynamic>{};
      await expectLater(repository.fetchWaveSnapshot(), throwsStateError);
    },
  );
  test(
    'Wave uses exact server aggregates even with empty history arrays',
    () async {
      result = <String, dynamic>{
        'wave_opening': {
          'opening_balance': 10000,
          'effective_at': '2026-11-01T00:00:00Z',
        },
        'wave_totals': {
          'client_payments': 1000000,
          'credit_settlements': 5000,
          'supplier_payments': 1000,
          'expenses': 2000,
          'refunds': 3000,
          'commission_payouts': 4000,
        },
      };
      final wave = await repository.fetchWaveSnapshot();
      expect(wave.theoreticalBalance, 1005000);
      expect(wave.incoming, 1005000);
      expect(wave.outgoing, 10000);
    },
  );
  test('canonical rows retain money, references and server dates', () {
    final expense = FinanceSqlMapper.expense({
      'id': 'e1',
      'category': 'fees',
      'amount': 125,
      'description': 'Frais',
      'payment_channel': 'bank',
      'payment_reference': 'B1',
      'spent_at': '2026-11-01T01:00:00Z',
      'created_by_uid': 'server-actor',
      'created_by_name': 'Admin',
    });
    expect(expense.amount, 125);
    expect(expense.channel, FinancePaymentChannel.bank);
    expect(expense.reference, 'B1');
    expect(expense.createdBy, 'server-actor');
    expect(
      () => FinanceSqlMapper.expense({'id': 'broken'}),
      throwsFormatException,
    );
  });
}
