import 'package:cabine_flow/core/theme/app_theme.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cabine_flow/features/orders/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/features/orders/presentation/pages/shared_agent_orders_page.dart';
import 'package:cabine_flow/features/orders/presentation/view_models/shared_order_queue_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'shared_order_queue_test.dart' as fixtures;

void main() {
  test(
    'an acknowledged claim cannot reappear from an older read, but a new assignment cycle can',
    () async {
      final repo = fixtures.QueueFake();
      await repo.prepare();
      final vm = SharedOrderQueueViewModel(repo)..start();
      await Future<void>.delayed(Duration.zero);
      final old = repo.snapshot;
      expect(await vm.claim(repo.available), isNotNull);
      expect(vm.orders, isEmpty);
      repo.controller.add(old);
      expect(vm.orders, isEmpty);
      final item = repo.available;
      final newCycle = AvailableSharedOrder(
        id: item.id,
        reference: item.reference,
        zoneId: item.zoneId,
        network: item.network,
        offerLabel: item.offerLabel,
        service: item.service,
        amount: item.amount,
        beneficiaryMasked: item.beneficiaryMasked,
        availableAt: item.availableAt,
        version: item.version + 1,
        canAccept: true,
      );
      repo.controller.add(
        SharedQueueSnapshot(
          orders: [newCycle],
          serverNow: old.serverNow.add(const Duration(seconds: 1)),
          enabled: true,
        ),
      );
      expect(vm.orders.single.version, 1);
      repo.controller.add(old);
      expect(vm.orders.single.version, 1);
      vm.dispose();
      await repo.controller.close();
    },
  );

  test(
    'a queue signal removes a command taken elsewhere without manual refresh',
    () async {
      final repo = fixtures.QueueFake();
      await repo.prepare();
      final vm = SharedOrderQueueViewModel(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(vm.orders, hasLength(1));
      repo.controller.add(
        SharedQueueSnapshot(
          orders: const [],
          serverNow: repo.snapshot.serverNow.add(const Duration(seconds: 1)),
          enabled: true,
        ),
      );
      expect(vm.orders, isEmpty);
      vm.dispose();
      await repo.controller.close();
    },
  );

  testWidgets(
    'Agent explicitly starts and confirms success without a photo and leaves no available row',
    (tester) async {
      final repo = fixtures.QueueFake();
      await repo.prepare();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SharedAgentOrdersPage(
            user: fixtures.agent,
            ordersRepository: repo,
            sharedRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepter et traiter'));
      await tester.pumpAndSettle();
      expect(find.text('Preuve'), findsNothing);
      await tester.tap(find.text('Démarrer le traitement'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marquer comme réussie'));
      await tester.pumpAndSettle();
      expect(find.text('Confirmer la réussite'), findsOneWidget);
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();
      final order = (await repo.fetchAssignedOrders(
        agentId: fixtures.agent.id,
      )).first;
      expect(order.status, QueueOrderStatus.completed);
      expect(await repo.fetchOrderProof(orderId: order.id), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Accepter et traiter'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await repo.controller.close();
    },
  );
}
