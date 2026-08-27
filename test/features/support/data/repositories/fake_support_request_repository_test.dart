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
    expect(
      requests.map((SupportRequest request) => request.orderReference),
      containsAll(<String>['CF-20260827-AAAAAA', 'CF-20260827-BBBBBB']),
    );
  });

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
