import 'dart:async';

import 'package:cabine_flow/app/domain/entities/backoffice/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/app/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/app/modules/backoffice/views/finances/backoffice_finance_page.dart';
import 'package:cabine_flow/app/theme/backoffice_theme.dart';
import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:cabine_flow/app/data/repositories/fake_orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FinanceReads implements BackofficeFinanceRepository {
  final streams = <StreamController<BackofficeFinanceSnapshot>>[];
  final periods = <Completer<Map<String, dynamic>>>[];

  @override
  Future<Map<String, dynamic>> fetchPeriodHistory({
    required String module,
    required DateTime start,
    required DateTime end,
  }) {
    final request = Completer<Map<String, dynamic>>();
    periods.add(request);
    return request.future;
  }

  @override
  Stream<BackofficeFinanceSnapshot> watchSnapshot() {
    final controller = StreamController<BackofficeFinanceSnapshot>();
    streams.add(controller);
    return controller.stream;
  }

  // Writes are deliberately unavailable in this read/recovery fixture.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('read-only fixture');
}

BackofficeFinanceSnapshot _snapshot() => BackofficeFinanceSnapshot.fromJson({
  'generated_at': '2026-11-01T23:29:15Z',
  'wave_opening': {'opening_balance': 250000},
  'wave_totals': <String, dynamic>{},
  'committed_capacities': {'orange': 58222},
  'agent_capacities': [
    {'orange_capacity': 163900},
  ],
});

Future<_FinanceReads> _open(
  WidgetTester tester, {
  BackofficeFinanceModule module = BackofficeFinanceModule.waveCash,
}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _FinanceReads();
  await tester.pumpWidget(
    MaterialApp(
      theme: BackofficeTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: BackofficeFinancePage(
            user: const AppUser(
              id: 'synthetic-admin',
              name: 'Admin',
              phoneNumber: '',
              role: UserRole.administrator,
            ),
            repository: repository,
            ordersRepository: FakeOrdersRepository(isTest: true),
            module: module,
          ),
        ),
      ),
    ),
  );
  return repository;
}

void main() {
  testWidgets(
    'a finance update refreshes the selected period without replacing data by zeros',
    (tester) async {
      final repository = await _open(
        tester,
        module: BackofficeFinanceModule.expenses,
      );
      repository.streams.single.add(_snapshot());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aujourd’hui'));
      await tester.pump();
      expect(repository.periods, hasLength(1));
      repository.periods[0].complete({
        'expenses': [],
        'totals': {
          'expenses': 14707,
          'expenses_count': 2101,
          'expenses_wave': 300,
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('14 707 F'), findsOneWidget);
      expect(find.text('2101 dépense(s)'), findsOneWidget);
      repository.streams.single.add(_snapshot());
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.periods, hasLength(2));
      expect(find.text('14 707 F'), findsOneWidget);
      repository.periods[1].complete({
        'expenses': [],
        'totals': {
          'expenses': 15007,
          'expenses_count': 2102,
          'expenses_wave': 600,
        },
      });
      await tester.pumpAndSettle();
      expect(find.text('15 007 F'), findsOneWidget);
      expect(find.text('14 707 F'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(repository.streams.single.close());
      await tester.pump();
    },
  );
  testWidgets(
    'a temporary failure retains data and a successful read clears the warning',
    (tester) async {
      final repository = await _open(tester);
      repository.streams.single.add(_snapshot());
      await tester.pumpAndSettle();
      expect(find.textContaining('Dernière lecture réussie'), findsOneWidget);
      repository.streams.single.addError(TimeoutException('synthetic timeout'));
      await tester.pumpAndSettle();
      expect(find.text('Données financières indisponibles'), findsNothing);
      expect(find.textContaining('Code : TimeoutException'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      repository.streams.single.add(_snapshot());
      await tester.pumpAndSettle();
      expect(find.textContaining('Code : TimeoutException'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(repository.streams.single.close());
      await tester.pump();
    },
  );

  testWidgets('a real retry recreates a failed stream', (tester) async {
    final repository = await _open(tester);
    repository.streams.single.add(_snapshot());
    repository.streams.single.addError(TimeoutException('synthetic timeout'));
    unawaited(repository.streams.single.close());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Réessayer'));
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(repository.streams, hasLength(2));
    repository.streams.last.add(_snapshot());
    await tester.pumpAndSettle();
    expect(find.textContaining('Code : TimeoutException'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(repository.streams.last.close());
    await tester.pump();
  });

  testWidgets(
    'a permission refusal hides cached balances and never retries automatically',
    (tester) async {
      final repository = await _open(tester);
      repository.streams.single.add(_snapshot());
      await tester.pumpAndSettle();
      repository.streams.single.addError(
        const PostgrestException(message: 'ADMIN_REQUIRED', code: '42501'),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Données financières indisponibles'), findsOneWidget);
      expect(find.textContaining('Dernière lecture réussie'), findsNothing);
      expect(repository.streams, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(repository.streams.single.close());
      await tester.pump();
    },
  );
}
