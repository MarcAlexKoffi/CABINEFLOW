import 'package:cabine_flow/features/refunds/domain/models/refund_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'les statuts de remboursement utilisent les valeurs Firestore attendues',
    () {
      expect(RefundStatus.pendingApproval.storageValue, 'pendingApproval');
      expect(RefundStatus.approved.storageValue, 'approved');
      expect(RefundStatus.refunded.storageValue, 'refunded');
      expect(RefundStatus.reconciled.storageValue, 'reconciled');
      expect(RefundStatus.rejected.storageValue, 'rejected');
    },
  );

  test('distingue les remboursements actifs de l historique', () {
    expect(RefundStatus.pendingApproval.isActive, isTrue);
    expect(RefundStatus.approved.isActive, isTrue);
    expect(RefundStatus.refunded.isHistory, isTrue);
    expect(RefundStatus.reconciled.isHistory, isTrue);
    expect(RefundStatus.rejected.isHistory, isTrue);
  });

  test('les raisons ont des valeurs de stockage stables', () {
    expect(RefundReason.serviceNotReceived.storageValue, 'serviceNotReceived');
    expect(RefundReason.transactionFailed.storageValue, 'transactionFailed');
    expect(RefundReason.wrongAmount.storageValue, 'wrongAmount');
    expect(RefundReason.wrongNumber.storageValue, 'wrongNumber');
  });
}
