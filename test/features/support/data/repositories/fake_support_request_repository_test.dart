import 'package:cabine_flow/features/support/data/repositories/fake_support_request_repository.dart';
import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('crée une demande 10D rattachée à la bonne commande', () async {
    final FakeSupportRequestRepository repository =
        FakeSupportRequestRepository();
    addTearDown(repository.dispose);

    final SupportRequest created = await repository.create(
      orderId: 'order-12345678',
      orderReference: 'CF-20260827-TEST01',
      type: SupportRequestType.wrongAmount,
      description: 'Le montant reçu ne correspond pas.',
    );

    expect(created.orderId, 'order-12345678');
    expect(created.orderReference, 'CF-20260827-TEST01');
    expect(created.type, SupportRequestType.wrongAmount);
    expect(created.status, SupportRequestStatus.newRequest);

    final List<SupportRequest> watched = await repository
        .watchForOrder(orderId: 'order-12345678')
        .first;
    expect(watched, hasLength(1));
    expect(watched.single.id, created.id);
  });

  test('isole les demandes de deux commandes différentes', () async {
    final FakeSupportRequestRepository repository =
        FakeSupportRequestRepository();
    addTearDown(repository.dispose);

    await repository.create(
      orderId: 'order-A-12345678',
      orderReference: 'CF-20260827-AAAAAA',
      type: SupportRequestType.transactionFailed,
      description: '',
    );
    await repository.create(
      orderId: 'order-B-12345678',
      orderReference: 'CF-20260827-BBBBBB',
      type: SupportRequestType.other,
      description: 'Autre problème',
    );

    final List<SupportRequest> orderA = await repository
        .watchForOrder(orderId: 'order-A-12345678')
        .first;
    expect(orderA, hasLength(1));
    expect(orderA.single.orderReference, 'CF-20260827-AAAAAA');
  });

  test('expose les nouvelles demandes dans la supervision Admin', () async {
    final FakeSupportRequestRepository repository =
        FakeSupportRequestRepository();
    addTearDown(repository.dispose);

    await repository.create(
      orderId: 'order-A-12345678',
      orderReference: 'CF-20260827-AAAAAA',
      type: SupportRequestType.paymentNotRecognized,
      description: '',
    );
    await repository.create(
      orderId: 'order-B-12345678',
      orderReference: 'CF-20260827-BBBBBB',
      type: SupportRequestType.wrongNumber,
      description: 'Le numéro affiché n’est pas le bon.',
    );

    final List<SupportRequest> requests = await repository
        .watchNewRequests()
        .first;

    expect(requests, hasLength(2));
  });

  test(
    'une demande traitée quitte la file active mais reste dans l historique',
    () async {
      final FakeSupportRequestRepository repository =
          FakeSupportRequestRepository();
      addTearDown(repository.dispose);

      final SupportRequest created = await repository.create(
        orderId: 'order-A-12345678',
        orderReference: 'CF-20260827-AAAAAA',
        type: SupportRequestType.paymentNotRecognized,
        description: '',
      );

      await repository.takeInCharge(
        requestId: created.id,
        staffId: 'admin-1',
        staffName: 'Marc',
      );
      await repository.resolve(
        requestId: created.id,
        staffId: 'admin-1',
        staffName: 'Marc',
        resolutionNote: 'Paiement retrouvé et vérifié.',
      );

      final List<SupportRequest> newRequests = await repository
          .watchNewRequests()
          .first;
      final List<SupportRequest> allRequests = await repository
          .watchAllRequests()
          .first;

      expect(newRequests, isEmpty);
      expect(allRequests, hasLength(1));
      expect(allRequests.single.status, SupportRequestStatus.resolved);
      expect(
        allRequests.single.resolutionNote,
        'Paiement retrouvé et vérifié.',
      );
      expect(allRequests.single.resolvedByName, 'Marc');
    },
  );

  test(
    'trace la notification WhatsApp puis la fermeture sans supprimer la demande',
    () async {
      final FakeSupportRequestRepository repository =
          FakeSupportRequestRepository();
      addTearDown(repository.dispose);

      final SupportRequest created = await repository.create(
        orderId: 'order-A-12345678',
        orderReference: 'CF-20260827-AAAAAA',
        type: SupportRequestType.wrongAmount,
        description: '',
      );
      await repository.takeInCharge(
        requestId: created.id,
        staffId: 'admin-1',
        staffName: 'Marc',
      );
      await repository.resolve(
        requestId: created.id,
        staffId: 'admin-1',
        staffName: 'Marc',
        resolutionNote: 'Montant vérifié.',
      );
      await repository.markCustomerNotified(requestId: created.id);
      await repository.close(requestId: created.id);

      final SupportRequest request =
          (await repository.watchAllRequests().first).single;
      expect(request.status, SupportRequestStatus.closed);
      expect(request.customerNotifiedAt, isNotNull);
      expect(request.notificationChannel, 'whatsapp');
      expect(request.closedAt, isNotNull);
    },
  );

  test('exige une description quand le motif est Autre', () async {
    final FakeSupportRequestRepository repository =
        FakeSupportRequestRepository();
    addTearDown(repository.dispose);

    await expectLater(
      repository.create(
        orderId: 'order-12345678',
        orderReference: 'CF-20260827-TEST01',
        type: SupportRequestType.other,
        description: '  ',
      ),
      throwsArgumentError,
    );
  });
}
