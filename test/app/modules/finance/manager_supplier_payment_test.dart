import 'dart:async';
import 'dart:convert';
import 'package:cabine_flow/app/data/repositories/fake_agent_repository.dart';
import 'package:cabine_flow/app/data/repositories/fake_finance_operations_repository.dart';
import 'package:cabine_flow/app/data/repositories/manager_read_only_finance_operations_repository.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/domain/entities/finance/finance_operations_models.dart';
import 'package:cabine_flow/app/modules/finance/views/supplier_finance_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const manager = AppUser(
  id: 'manager',
  name: 'Manager',
  phoneNumber: '',
  role: UserRole.manager,
);
final date = DateTime(2026, 11, 18);
final supplier = FinanceSupplier(
  id: 's1',
  name: 'Fournisseur test',
  phoneNumber: '',
  isActive: true,
  createdAt: date,
  createdBy: 'manager',
  createdByName: 'Manager',
  updatedAt: date,
);
SupplierAccount account([int paid = 2000]) => SupplierAccount(
  supplierId: 's1',
  supplierName: supplier.name,
  totalOwed: 10000,
  totalPaid: paid,
  totalRecharged: 10400,
  rechargeCount: 1,
  createdAt: date,
  updatedAt: date,
);

class _Finance extends FakeFinanceOperationsRepository {
  final accounts = StreamController<List<SupplierAccount>>.broadcast();
  int watches = 0;
  SupplierPaymentDraft? payment;
  @override
  Stream<List<FinanceSupplier>> watchSuppliers() => Stream.value([supplier]);
  @override
  Stream<List<SupplierAccount>> watchSupplierAccounts() {
    watches++;
    return accounts.stream;
  }

  @override
  Future<String> recordSupplierPayment({
    required SupplierPaymentDraft draft,
    required String staffId,
    required String staffName,
  }) async {
    payment = draft;
    return 'payment';
  }
}

Future<void> _show(WidgetTester tester, _Finance finance) async {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: SupplierFinancePage(
        user: manager,
        repository: finance,
        agentRepository: FakeAgentRepository(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester, _Finance finance) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await finance.accounts.close();
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets(
    'supplier amounts remain visible after timeout and recover without logout',
    (tester) async {
      final finance = _Finance();
      await _show(tester, finance);
      expect(find.text('—'), findsNWidgets(3));
      finance.accounts.add([account()]);
      await tester.pumpAndSettle();
      expect(find.text('10 400 F'), findsOneWidget);
      expect(find.text('8 000 F'), findsOneWidget);
      finance.accounts.addError(TimeoutException('fixture'));
      await tester.pumpAndSettle();
      expect(find.text('10 400 F'), findsOneWidget);
      expect(find.text('8 000 F'), findsOneWidget);
      expect(find.text('0 F'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Régler'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(finance.watches, 2);
      expect(find.text('8 000 F'), findsOneWidget);
      finance.accounts.add([account(5000)]);
      await tester.pumpAndSettle();
      expect(find.text('5 000 F'), findsNWidgets(2));
      expect(find.text('Réessayer'), findsNothing);
      await _close(tester, finance);
    },
  );
  testWidgets(
    'a denied financial read hides amounts instead of fabricating zero balances',
    (tester) async {
      final finance = _Finance();
      await _show(tester, finance);
      finance.accounts.add([account()]);
      await tester.pumpAndSettle();
      finance.accounts.addError(
        const PostgrestException(message: 'denied', code: '42501'),
      );
      await tester.pumpAndSettle();
      expect(find.text(supplier.name), findsOneWidget);
      expect(find.text('8 000 F'), findsNothing);
      expect(find.text('0 F'), findsNothing);
      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('Réessayer'), findsOneWidget);
      await _close(tester, finance);
    },
  );
  testWidgets(
    'a successful empty account read represents a genuinely new supplier',
    (tester) async {
      final finance = _Finance();
      await _show(tester, finance);
      finance.accounts.add([account()]);
      await tester.pumpAndSettle();
      finance.accounts.add([]);
      await tester.pumpAndSettle();
      expect(find.text('0 F'), findsNWidgets(3));
      await _close(tester, finance);
    },
  );
  testWidgets('manager can enter and record a supplier settlement', (
    tester,
  ) async {
    final finance = _Finance();
    await _show(tester, finance);
    finance.accounts.add([account()]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Régler'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Montant'), '3000');
    await tester.enterText(
      find.widgetWithText(TextField, 'Référence du règlement'),
      'wave-123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Régler').last);
    await tester.pumpAndSettle();
    expect(finance.payment?.supplierId, 's1');
    expect(finance.payment?.amount, 3000);
    expect(finance.payment?.reference, 'wave-123');
    await _close(tester, finance);
  });
  test(
    'manager settlement uses one operation key for retries and propagates refusals',
    () async {
      final bodies = <Map<String, dynamic>>[];
      var fail = true;
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'fixture-key',
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/rest/v1/rpc/phase5_record_supplier_payment',
          );
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            fail
                ? jsonEncode({
                    'code': '42501',
                    'message': 'SUPPLIER_SCOPE_DENIED',
                  })
                : jsonEncode('payment'),
            fail ? 403 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = ManagerReadOnlyFinanceOperationsRepository(
        client: client,
      );
      const draft = SupplierPaymentDraft(
        supplierId: 's1',
        supplierName: 'Supplier',
        amount: 3000,
        channel: FinancePaymentChannel.wave,
        reference: ' wave-123 ',
      );
      await expectLater(
        repository.recordSupplierPayment(
          draft: draft,
          staffId: 'manager',
          staffName: 'Manager',
        ),
        throwsA(isA<PostgrestException>()),
      );
      fail = false;
      expect(
        await repository.recordSupplierPayment(
          draft: draft,
          staffId: 'manager',
          staffName: 'Manager',
        ),
        'payment',
      );
      expect(bodies[0]['p_operation_key'], isNotEmpty);
      expect(bodies[1], bodies[0]);
      expect(bodies[0]['p_reference'], 'wave-123');
      expect(bodies[0]['p_legacy_id'], isNull);
    },
  );
}
