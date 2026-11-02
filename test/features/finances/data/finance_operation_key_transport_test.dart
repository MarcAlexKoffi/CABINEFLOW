import 'dart:convert';
import 'dart:io';
import 'package:cabine_flow/backoffice/data/repositories/supabase_backoffice_finance_repository.dart';
import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/finance_operations_models.dart';
import 'package:cabine_flow/features/finances/data/repositories/manager_read_only_finance_operations_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_supplier_registry_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late SupabaseBackofficeFinanceRepository repository;
  final calls = <({String path, Map<String, dynamic> body})>[];
  setUp(() async {
    calls.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      calls.add((
        path: request.uri.path,
        body: Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map,
        ),
      ));
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode('synthetic-id'));
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'synthetic-key');
    repository = SupabaseBackofficeFinanceRepository(client: client);
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  test('manager recharge preserves its intention key on retry', () async {
    final manager = ManagerReadOnlyFinanceOperationsRepository(
      client: client,
      phase5Repository: SupabasePhase5FinanceRepository(client: client),
      supplierRepository: SupabaseSupplierRegistryRepository(client: client),
    );
    final draft = SupplierRechargeDraft(
      supplierId: 's1',
      supplierName: 'Fournisseur',
      agentId: 'a1',
      agentName: 'Agent',
      network: AgentNetwork.moov,
      principalAmount: 100,
      bonusAmount: 5,
      amountOwed: 100,
    );
    await manager.recordSupplierRecharge(
      draft: draft,
      staffId: 'manager',
      staffName: 'Manager',
    );
    await manager.recordSupplierRecharge(
      draft: draft,
      staffId: 'manager',
      staffName: 'Manager',
    );
    expect(calls[0].body['p_operation_key'], isNotNull);
    expect(calls[0].body['p_operation_key'], calls[1].body['p_operation_key']);
  });
  test(
    'explicit recharge intention survives repeated transport calls',
    () async {
      Future<String> send() => repository.recordSupplierRecharge(
        operationKey: 'recharge-intent',
        supplierId: 's1',
        agentId: 'a1',
        agentName: 'Agent',
        network: 'orange',
        principal: 100,
        bonus: 5,
        amountOwed: 100,
        staffName: 'Admin',
      );
      await send();
      await send();
      expect(
        calls.map((v) => v.body['p_operation_key']),
        everyElement('recharge-intent'),
      );
    },
  );
  test('expense uses receipt RPC and separates distinct intentions', () async {
    Future<String> send({String? key}) => repository.recordExpense(
      operationKey: key,
      category: 'fees',
      amount: 20,
      description: 'Fees',
      channel: 'cash',
    );
    await send(key: 'expense-intent');
    await send(key: 'expense-intent');
    expect(
      calls.map((v) => v.path),
      everyElement('/rest/v1/rpc/izytel_finance_record_expense_once'),
    );
    expect(
      calls.map((v) => v.body['p_operation_key']),
      everyElement('expense-intent'),
    );
    calls.clear();
    await send();
    await send();
    expect(
      calls[0].body['p_operation_key'],
      isNot(calls[1].body['p_operation_key']),
    );
  });
}
