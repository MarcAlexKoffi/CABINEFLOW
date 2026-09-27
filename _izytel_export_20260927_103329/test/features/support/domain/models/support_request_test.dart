import 'package:cabine_flow/features/support/domain/models/support_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les six motifs 10D conservent leur valeur Firestore', () {
    expect(
      SupportRequestType.values.map(
        (SupportRequestType type) => type.storageValue,
      ),
      <String>[
        'paymentNotRecognized',
        'completedButNotReceived',
        'wrongAmount',
        'wrongNumber',
        'transactionFailed',
        'other',
      ],
    );
  });

  test('les statuts support sont lisibles depuis Firestore', () {
    expect(
      SupportRequestStatusX.fromStorage('new'),
      SupportRequestStatus.newRequest,
    );
    expect(
      SupportRequestStatusX.fromStorage('inProgress'),
      SupportRequestStatus.inProgress,
    );
    expect(
      SupportRequestStatusX.fromStorage('resolved'),
      SupportRequestStatus.resolved,
    );
  });
}
