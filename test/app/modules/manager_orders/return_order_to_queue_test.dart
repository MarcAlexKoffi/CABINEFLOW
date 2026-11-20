import 'package:cabine_flow/app/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/order_requeue_repository.dart';
import 'package:cabine_flow/app/modules/manager_orders/widgets/return_order_to_queue.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RequeueFake implements OrderRequeueRepository {
  RequeueFake(this.order);
  final QueueOrder order;
  int requeues = 0, verifications = 0;
  bool uncertain = false;
  String? reason;
  @override
  Future<QueueOrder> returnOrderToQueue({
    required String orderId,
    required String reason,
  }) async {
    requeues++;
    if (uncertain) throw StateError('EXECUTION_REQUIRES_MANAGER_VERIFICATION');
    this.reason = reason;
    return order.copyWith(
      clearAgentAssignment: true,
      status: QueueOrderStatus.paidReady,
    );
  }

  @override
  Future<void> verifyOrderNotExecuted({
    required String orderId,
    required String reason,
    required int assignmentVersion,
  }) async {
    verifications++;
    uncertain = false;
  }
}

void main() {
  for (final uncertain in [false, true]) {
    testWidgets(
      'return to shared queue, uncertain=$uncertain: explicit reason and verification',
      (tester) async {
        final order = (await FakeOrdersRepository(
          isTest: true,
        ).fetchPaidQueue()).first;
        final repository = RequeueFake(order)..uncertain = uncertain;
        QueueOrder? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    result = await returnOrderToSharedQueue(
                      context,
                      repository,
                      order,
                    );
                  },
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ouvrir'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'Réorganisation de la zone',
        );
        await tester.tap(find.text('Remettre dans la file'));
        await tester.pumpAndSettle();
        if (uncertain) {
          expect(repository.verifications, 0);
          expect(result, isNull);
          expect(
            find.text('Vérification préalable obligatoire'),
            findsOneWidget,
          );
          await tester.enterText(
            find.byType(TextFormField),
            'Agent et opérateur contactés : aucun transfert effectué',
          );
          await tester.tap(find.text('J’ai vérifié : aucune exécution'));
          await tester.pumpAndSettle();
          expect(repository.verifications, 1);
        }
        expect(result!.assignedAgentId, isNull);
        expect(repository.reason, 'Réorganisation de la zone');
        expect(repository.requeues, uncertain ? 2 : 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
