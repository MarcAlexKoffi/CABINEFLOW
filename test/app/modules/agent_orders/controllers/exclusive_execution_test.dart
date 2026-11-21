import 'dart:async';
import 'package:cabine_flow/app/data/repositories/fake_orders_repository.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cabine_flow/app/domain/repositories/order_requeue_repository.dart';
import 'package:cabine_flow/app/modules/agent_orders/controllers/agent_orders_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class ExecutionFake extends FakeOrdersRepository
    implements OrderExecutionAuthorizationRepository {
  ExecutionFake() : super(isTest: true);
  int calls = 0;
  Completer<QueueOrder>? response;
  bool offlineAtConfirmation = false;
  Object? confirmationError;
  @override
  Future<QueueOrder> authorizeAgentExecution(QueueOrder order) async {
    calls++;
    if (calls > 1 && confirmationError != null) throw confirmationError!;
    if (calls > 1 && offlineAtConfirmation) {
      throw TimeoutException('synthetic offline');
    }
    return response?.future ??
        Future.value(order.copyWith(status: QueueOrderStatus.inProgress));
  }
}

Future<
  ({ExecutionFake repository, AgentOrdersViewModel model, QueueOrder order})
>
setup() async {
  final repository = ExecutionFake();
  final order = (await repository.fetchPaidQueue()).first.copyWith(
    assignedAgentId: 'test-agent',
    assignmentStatus: OrderAssignmentStatus.accepted,
    assignmentVersion: 1,
    status: QueueOrderStatus.paidReady,
  );
  final model = AgentOrdersViewModel(
    agentId: 'test-agent',
    ordersRepository: repository,
  );
  model.includeClaimedOrder(order);
  return (repository: repository, model: model, order: order);
}

void main() {
  testWidgets(
    'fast server still requires five seconds; double click sends one start',
    (tester) async {
      final s = await setup();
      final result = s.model.startProcessing(s.order);
      expect(await s.model.startProcessing(s.order), isFalse);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(s.model.canOpenProcessing(s.order), isFalse);
      expect(s.repository.calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(await result, isTrue);
      expect(s.model.canOpenProcessing(s.order), isTrue);
      expect(
        s.repository.calls,
        2,
      ); // idempotent online confirmation after animation
      s.model.dispose();
    },
  );

  testWidgets('five seconds cannot unlock a pending server response', (
    tester,
  ) async {
    final s = await setup();
    s.repository.response = Completer<QueueOrder>();
    final result = s.model.startProcessing(s.order);
    await tester.pump(const Duration(seconds: 6));
    expect(s.model.canOpenProcessing(s.order), isFalse);
    expect(s.model.busyOrderId, s.order.id);
    s.repository.response!.complete(
      s.order.copyWith(status: QueueOrderStatus.inProgress),
    );
    await tester.pump();
    expect(await result, isTrue);
    s.model.dispose();
  });

  testWidgets(
    'lost Internet at end of preparation keeps reservation and allows retry',
    (tester) async {
      final s = await setup();
      s.repository.offlineAtConfirmation = true;
      final result = s.model.startProcessing(s.order);
      await tester.pump(const Duration(seconds: 5));
      expect(await result, isFalse);
      expect(s.model.canOpenProcessing(s.order), isFalse);
      expect(s.model.orderById(s.order.id)!.assignedAgentId, 'test-agent');
      expect(s.model.errorMessage, contains('Connexion interrompue'));
      s.repository.offlineAtConfirmation = false;
      final retry = s.model.startProcessing(s.order);
      await tester.pump(const Duration(seconds: 5));
      expect(await retry, isTrue);
      s.model.dispose();
    },
  );

  testWidgets(
    'denied authorization and direct inProgress navigation stay closed',
    (tester) async {
      final s = await setup();
      expect(
        s.model.canOpenProcessing(
          s.order.copyWith(status: QueueOrderStatus.inProgress),
        ),
        isFalse,
      );
      s.repository.response = Completer<QueueOrder>();
      final result = s.model.startProcessing(s.order);
      s.repository.response!.completeError(
        StateError('synthetic authorization denied'),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(await result, isFalse);
      expect(s.model.canOpenProcessing(s.order), isFalse);
      s.model.dispose();
    },
  );

  testWidgets('a network rejection keeps the reservation and permits retry', (
    tester,
  ) async {
    final s = await setup();
    s.repository.confirmationError = http.ClientException('Failed to fetch');
    final first = s.model.startProcessing(s.order);
    await tester.pump(const Duration(seconds: 5));
    expect(await first, isFalse);
    expect(s.model.errorMessage, contains('Connexion interrompue'));
    expect(s.model.canOpenProcessing(s.order), isFalse);
    expect(s.model.orderById(s.order.id)!.assignedAgentId, 'test-agent');
    s.repository.confirmationError = null;
    final retry = s.model.startProcessing(s.order);
    await tester.pump(const Duration(seconds: 5));
    expect(await retry, isTrue);
    s.model.dispose();
  });

  testWidgets('an assignment changed during preparation cannot be reopened', (
    tester,
  ) async {
    final s = await setup();
    s.repository.response = Completer<QueueOrder>();
    final result = s.model.startProcessing(s.order);
    s.model.includeClaimedOrder(s.order.copyWith(assignmentVersion: 2));
    s.repository.response!.complete(
      s.order.copyWith(status: QueueOrderStatus.inProgress),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(await result, isFalse);
    expect(s.model.orderById(s.order.id)!.assignmentVersion, 2);
    expect(s.model.canOpenProcessing(s.order), isFalse);
    s.model.dispose();
  });

  testWidgets('a response owned by another Agent never opens processing', (
    tester,
  ) async {
    final s = await setup();
    s.repository.response = Completer<QueueOrder>()
      ..complete(
        s.order.copyWith(
          status: QueueOrderStatus.inProgress,
          assignedAgentId: 'another-agent',
        ),
      );
    final result = s.model.startProcessing(s.order);
    await tester.pump(const Duration(seconds: 5));
    expect(await result, isFalse);
    expect(s.model.canOpenProcessing(s.order), isFalse);
    s.model.dispose();
  });

  testWidgets('leaving during preparation never opens a disposed screen', (
    tester,
  ) async {
    final s = await setup();
    final result = s.model.startProcessing(s.order);
    s.model.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(await result, isFalse);
    expect(s.repository.calls, 1);
    expect(s.model.canOpenProcessing(s.order), isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final status in [
    QueueOrderStatus.failed,
    QueueOrderStatus.completed,
    QueueOrderStatus.refundPending,
    QueueOrderStatus.refunded,
    QueueOrderStatus.cancelled,
  ]) {
    testWidgets('a $status order closes processing, even via a stale route', (
      tester,
    ) async {
      final s = await setup();
      final started = s.model.startProcessing(s.order);
      await tester.pump(const Duration(seconds: 5));
      expect(await started, isTrue);
      expect(s.model.canOpenProcessing(s.order), isTrue);
      s.model.includeClaimedOrder(s.order.copyWith(status: status));
      expect(s.model.canOpenProcessing(s.order), isFalse);
      expect(s.model.inProgressOrders, isEmpty);
      expect(
        await s.model.startProcessing(s.model.orderById(s.order.id)!),
        isFalse,
      );
      s.model.dispose();
    });
  }
}
