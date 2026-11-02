import 'dart:async';

import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_finance_repository.dart';
import 'package:cabine_flow/backoffice/presentation/pages/finances/backoffice_finance_page.dart';
import 'package:cabine_flow/backoffice/presentation/theme/backoffice_theme.dart';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/orders/data/repositories/fake_orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FinanceReads implements BackofficeFinanceRepository {
  final streams = <StreamController<BackofficeFinanceSnapshot>>[];

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

Future<_FinanceReads> _open(WidgetTester tester) async {
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
            module: BackofficeFinanceModule.waveCash,
          ),
        ),
      ),
    ),
  );
  return repository;
}

void main() {
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
