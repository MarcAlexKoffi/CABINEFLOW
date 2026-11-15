enum OrderEventType {
  orderCreated('ORDER_CREATED'),
  paymentDeclared('PAYMENT_DECLARED'),
  paymentConfirmed('PAYMENT_CONFIRMED'),
  creditAuthorized('CREDIT_AUTHORIZED'),
  assigned('ASSIGNED'),
  assignmentAccepted('ASSIGNMENT_ACCEPTED'),
  assignmentRefused('ASSIGNMENT_REFUSED'),
  processingStarted('PROCESSING_STARTED'),
  putOnHold('PUT_ON_HOLD'),
  processingResumed('PROCESSING_RESUMED'),
  proofAdded('PROOF_ADDED'),
  processingSucceeded('PROCESSING_SUCCEEDED'),
  processingFailed('PROCESSING_FAILED'),
  reassignmentRequested('REASSIGNMENT_REQUESTED'),
  customerContacted('CUSTOMER_CONTACTED');

  const OrderEventType(this.value);

  final String value;
}

class OrderEvent {
  const OrderEvent({
    required this.id,
    required this.orderId,
    required this.orderReference,
    required this.type,
    required this.actorId,
    required this.actorRole,
    required this.createdAt,
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String orderId;
  final String orderReference;
  final OrderEventType type;
  final String actorId;
  final String actorRole;
  final DateTime createdAt;
  final Map<String, Object?> metadata;
}
