import 'package:cabine_flow/features/orders/domain/models/order_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('les types orderEvents utilisent les valeurs Firestore prévues', () {
    expect(OrderEventType.orderCreated.value, 'ORDER_CREATED');
    expect(OrderEventType.assignmentAccepted.value, 'ASSIGNMENT_ACCEPTED');
    expect(OrderEventType.proofAdded.value, 'PROOF_ADDED');
    expect(OrderEventType.processingSucceeded.value, 'PROCESSING_SUCCEEDED');
    expect(OrderEventType.processingFailed.value, 'PROCESSING_FAILED');
  });
}
