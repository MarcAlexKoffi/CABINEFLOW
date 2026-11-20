import 'dart:async';
import 'package:cabine_flow/app/domain/repositories/shared_order_queue_repository.dart';
import 'package:cabine_flow/app/modules/agent_orders/controllers/shared_order_queue_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'shared_order_queue_test.dart' show QueueFake;

class _PagedQueue extends QueueFake {
  final cursors = <SharedQueueCursor?>[];
  Completer<SharedQueueSnapshot>? pending;
  @override
  Future<SharedQueueSnapshot> fetchAvailableOrders({
    SharedQueueCursor? after,
  }) async {
    cursors.add(after);
    if (pending != null) return pending!.future;
    return SharedQueueSnapshot(
      orders: after == null
          ? [available]
          : [
              AvailableSharedOrder.fromJson({
                'order_id': 'last',
                'order_reference': 'LAST',
                'zone_id': 'test-zone',
                'network': 'orange',
                'operation_type': 'unitTransfer',
                'offer_label': 'Dernière commande',
                'amount': 200,
                'beneficiary_masked': '••••',
                'available_at': '2026-11-20T00:00:00Z',
                'assignment_version': 0,
                'can_accept': true,
              }),
            ],
      totalCount: 109,
      serverNow: DateTime.utc(2026, 11, 20),
      enabled: true,
      nextCursor: after == null
          ? SharedQueueCursor(
              availableAt: available.availableAt,
              orderId: available.id,
            )
          : null,
    );
  }

  @override
  Stream<SharedQueueSnapshot> watchAvailableOrders({
    SharedQueueCursor? after,
  }) async* {
    yield await fetchAvailableOrders(after: after);
  }
}

void main() {
  test(
    'next/previous pages keep the total and reject a late response from another page',
    () async {
      final repo = _PagedQueue();
      await repo.prepare();
      final vm = SharedOrderQueueViewModel(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(vm.totalCount, 109);
      expect(vm.hasNextPage, isTrue);
      repo.pending = Completer();
      final oldRead = vm.refresh();
      final oldPending = repo.pending!;
      repo.pending = null;
      vm.nextPage();
      await Future<void>.delayed(Duration.zero);
      expect(vm.pageNumber, 2);
      expect(vm.orders.single.id, 'last');
      expect(vm.totalCount, 109);
      expect(vm.hasPreviousPage, isTrue);
      expect(vm.hasNextPage, isFalse);
      oldPending.complete(repo.snapshot);
      await oldRead;
      expect(vm.orders.single.id, 'last');
      vm.previousPage();
      await Future<void>.delayed(Duration.zero);
      expect(vm.pageNumber, 1);
      expect(vm.orders.single.id, repo.available.id);
      expect(repo.cursors[2]?.orderId, repo.available.id);
      vm.dispose();
      await repo.controller.close();
    },
  );
}
