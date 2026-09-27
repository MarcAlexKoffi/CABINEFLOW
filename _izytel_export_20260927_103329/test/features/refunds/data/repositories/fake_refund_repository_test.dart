import 'package:cabine_flow/features/refunds/data/repositories/fake_refund_repository.dart';
import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RefundCreationRequest request({int amount = 1000}) {
    return RefundCreationRequest(
      orderId: 'order-12345678',
      orderReference: 'CF-20260828-ABCDEF',
      supportRequestId: 'support-12345678',
      supportRequestType: 'completedButNotReceived',
      supportRequestDescription: 'Commande terminée mais rien reçu.',
      customerAuthUid: 'customer-1',
      clientName: 'Client Test',
      clientWhatsappPhone: '+2250102030405',
      originalAmount: 1000,
      amount: amount,
      reason: RefundReason.serviceNotReceived,
      reasonNote: 'Service non reçu après vérification.',
      paymentChannel: 'wave',
      originalPaymentReference: 'WAVE-ORIGINAL-1',
    );
  }

  test('cycle complet validation remboursement rapprochement', () async {
    final FakeRefundRepository repository = FakeRefundRepository();
    addTearDown(repository.dispose);

    final RefundCase created = await repository.create(
      request: request(),
      staffId: 'admin-1',
      staffName: 'Marc Alex',
    );
    expect(created.status, RefundStatus.pendingApproval);

    await repository.approve(
      orderId: created.orderId,
      staffId: 'admin-1',
      staffName: 'Marc Alex',
    );
    expect(
      (await repository.watchForOrder(orderId: created.orderId).first)!.status,
      RefundStatus.approved,
    );

    await repository.markRefunded(
      orderId: created.orderId,
      staffId: 'admin-1',
      staffName: 'Marc Alex',
      refundReference: 'WAVE-REFUND-1',
    );
    RefundCase value = (await repository
        .watchForOrder(orderId: created.orderId)
        .first)!;
    expect(value.status, RefundStatus.refunded);
    expect(value.refundReference, 'WAVE-REFUND-1');

    await repository.markCustomerNotified(
      orderId: created.orderId,
      staffId: 'admin-1',
      staffName: 'Marc Alex',
    );
    value = (await repository.watchForOrder(orderId: created.orderId).first)!;
    expect(value.customerWasNotified, isTrue);

    await repository.reconcile(
      orderId: created.orderId,
      staffId: 'admin-1',
      staffName: 'Marc Alex',
    );
    value = (await repository.watchForOrder(orderId: created.orderId).first)!;
    expect(value.status, RefundStatus.reconciled);
    expect(value.reconciledAt, isNotNull);
  });

  test('empêche un deuxième remboursement sur la même commande', () async {
    final FakeRefundRepository repository = FakeRefundRepository();
    addTearDown(repository.dispose);

    await repository.create(
      request: request(),
      staffId: 'admin-1',
      staffName: 'Marc Alex',
    );

    await expectLater(
      repository.create(
        request: request(),
        staffId: 'admin-2',
        staffName: 'Autre Admin',
      ),
      throwsStateError,
    );
  });

  test('refuse un montant supérieur à la commande', () async {
    final FakeRefundRepository repository = FakeRefundRepository();
    addTearDown(repository.dispose);

    await expectLater(
      repository.create(
        request: request(amount: 1500),
        staffId: 'admin-1',
        staffName: 'Marc Alex',
      ),
      throwsArgumentError,
    );
  });

  test('le rejet reste dans l historique avec son motif', () async {
    final FakeRefundRepository repository = FakeRefundRepository();
    addTearDown(repository.dispose);

    final RefundCase created = await repository.create(
      request: request(),
      staffId: 'admin-1',
      staffName: 'Marc Alex',
    );
    await repository.reject(
      orderId: created.orderId,
      staffId: 'admin-1',
      staffName: 'Marc Alex',
      reason: 'La transaction a finalement été reçue par le client.',
    );

    final RefundCase value = (await repository
        .watchForOrder(orderId: created.orderId)
        .first)!;
    expect(value.status, RefundStatus.rejected);
    expect(value.rejectionReason, contains('finalement'));
  });
}
