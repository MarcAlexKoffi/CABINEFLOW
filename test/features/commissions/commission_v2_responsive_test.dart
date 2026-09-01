import 'package:cabine_flow/features/commissions/domain/models/commission_v2_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_v2_repository.dart';
import 'package:cabine_flow/features/commissions/presentation/pages/commission_v2_dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Commissions V2 Admin reste rendable à 320x568', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CommissionV2DashboardPage(
          scope: CommissionV2Scope.adminAll,
          repository: _FakeCommissionV2Repository(_snapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commissions V2'), findsOneWidget);
    expect(find.text('Synthèse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Commissions V2 Agent reste rendable à 320x568', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: CommissionV2DashboardPage(
          scope: CommissionV2Scope.agentSelf,
          agentId: 'agent-a',
          agentName: 'Agent Alpha',
          repository: _FakeCommissionV2Repository(_snapshot()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes commissions'), findsOneWidget);
    expect(find.text('Mon compte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCommissionV2Repository implements CommissionV2Repository {
  _FakeCommissionV2Repository(this.snapshot);

  final CommissionV2Snapshot snapshot;

  @override
  Stream<CommissionV2Snapshot> watchAdmin() => Stream.value(snapshot);

  @override
  Stream<CommissionV2Snapshot> watchAdminAgent(String agentId) =>
      Stream.value(snapshot);

  @override
  Stream<CommissionV2Snapshot> watchAgent(String agentId) =>
      Stream.value(snapshot);
}

CommissionV2Snapshot _snapshot() {
  return CommissionV2Snapshot(
    commissions: <CommissionV2Entry>[
      CommissionV2Entry(
        id: 'order-a',
        orderId: 'order-a',
        orderReference: 'CF-20260901-TEST',
        agentId: 'agent-a',
        agentName: 'Agent Alpha',
        network: 'orange',
        orderAmount: 1000,
        commissionAmount: 10,
        policyId: 'fixed-10-v1',
        policyType: 'fixedPerSuccessfulTransaction',
        rate: 10,
        earnedAt: DateTime.now(),
      ),
    ],
    payouts: <CommissionPayoutV2Entry>[],
    accounts: const <CommissionAccountV2>[
      CommissionAccountV2(
        agentId: 'agent-a',
        agentName: 'Agent Alpha',
        earnedTotal: 10,
        paidTotal: 0,
        earnedTransactions: 1,
      ),
    ],
  );
}
