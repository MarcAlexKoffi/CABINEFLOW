import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreOrderMapper {
  const FirestoreOrderMapper._();

  static QueueOrder fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return QueueOrder(
      id: id,
      reference: _readString(data, 'reference', fallback: id),
      source: _readSource(data['source']),
      customerAuthUid: _readNullableString(data['customerAuthUid']),
      clientName: _readString(data, 'clientName', fallback: 'Client'),
      clientWhatsappPhone: _readString(
        data,
        'clientWhatsappPhone',
        fallback: '',
      ),
      network: _readNetwork(data['network']),
      beneficiaryPhone: _readString(data, 'beneficiaryPhone', fallback: ''),
      operationType: _readOperationType(data['operationType']),
      offerLabel: _readString(
        data,
        'offerLabel',
        fallback: 'Offre non renseignée',
      ),
      amount: _readInt(data['amount']),
      originalWhatsappMessage: _readNullableString(
        data['originalWhatsappMessage'],
      ),
      internalNotes: _readNullableString(data['internalNotes']),
      createdAt: _readDate(data['createdAt']) ?? DateTime.now(),
      paidAt: _readDate(data['paidAt']),
      paymentRequestSentAt: _readDate(data['paymentRequestSentAt']),
      paymentDeclaredAt: _readDate(data['paymentDeclaredAt']),
      paymentPayerName: _readNullableString(data['paymentPayerName']),
      paymentPayerPhone: _readNullableString(data['paymentPayerPhone']),
      paymentApproximateTime: _readNullableString(
        data['paymentApproximateTime'],
      ),
      paymentDeclaredReference: _readNullableString(
        data['paymentDeclaredReference'],
      ),
      paymentConfirmedAt: _readDate(data['paymentConfirmedAt']),
      expiresAt: _readDate(data['expiresAt']),
      expiredAt: _readDate(data['expiredAt']),
      paymentReference: _readNullableString(data['paymentReference']),
      status: _readStatus(data['status']),
      paymentStatus: _readPaymentStatus(data['paymentStatus']),
      takenByUserId: _readNullableString(data['takenByUserId']),
      takenAt: _readDate(data['takenAt']),
      completedAt: _readDate(data['completedAt']),
      failureReason: _readFailureReason(data['failureReason']),
      observation: _readNullableString(data['observation']),
      customerConfirmationStatus: _readConfirmationStatus(
        data['customerConfirmationStatus'],
      ),
      customerConfirmationCompletedAt: _readDate(
        data['customerConfirmationCompletedAt'],
      ),
      assignedAgentId: _readNullableString(data['assignedAgentId']),
      assignedAgentName: _readNullableString(data['assignedAgentName']),
      assignedByUserId: _readNullableString(data['assignedByUserId']),
      assignedAt: _readDate(data['assignedAt']),
      assignmentMode: _readAssignmentMode(data['assignmentMode']),
      assignmentStatus: _readAssignmentStatus(data['assignmentStatus']),
      lastAssignmentRefusalReason: _readNullableString(
        data['lastAssignmentRefusalReason'],
      ),
      lastAssignmentRefusedAt: _readDate(data['lastAssignmentRefusedAt']),
      lastHoldReason: _readNullableString(data['lastHoldReason']),
      lastHeldAt: _readDate(data['lastHeldAt']),
      lastResumedAt: _readDate(data['lastResumedAt']),
    );
  }

  static Map<String, dynamic> operatorOrderCreationData({
    required String reference,
    required String clientName,
    required String clientWhatsappPhone,
    required MobileNetwork network,
    required String beneficiaryPhone,
    required OrderOperationType operationType,
    required String offerLabel,
    required int amount,
    String? offerId,
    bool isCustomOffer = true,
    String? originalWhatsappMessage,
    String? internalNotes,
    required DateTime expiresAt,
  }) {
    return <String, dynamic>{
      'schemaVersion': 1,
      'reference': reference,
      'source': OrderSource.operatorApp.name,
      'customerAuthUid': null,
      'clientName': clientName.trim(),
      'clientWhatsappPhone': clientWhatsappPhone.trim(),
      'service': _serviceForOperationType(operationType),
      'network': network.name,
      'operationType': operationType.name,
      'offerId': _cleanNullable(offerId),
      'offerLabel': offerLabel.trim(),
      'isCustomOffer': isCustomOffer,
      'amount': amount,
      'beneficiaryPhone': beneficiaryPhone.trim(),
      'status': QueueOrderStatus.awaitingPayment.name,
      'paymentStatus': OrderPaymentStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'paymentRequestSentAt': null,
      'paymentDeclaredAt': null,
      'paymentPayerName': null,
      'paymentPayerPhone': null,
      'paymentApproximateTime': null,
      'paymentDeclaredReference': null,
      'expiresAt': Timestamp.fromDate(expiresAt.toUtc()),
      'expiredAt': null,
      'paymentConfirmedAt': null,
      'paidAt': null,
      'paymentReference': null,
      'originalWhatsappMessage': _cleanNullable(originalWhatsappMessage),
      'internalNotes': _cleanNullable(internalNotes),
      'takenByUserId': null,
      'takenAt': null,
      'completedAt': null,
      'failureReason': null,
      'observation': null,
      'customerConfirmationStatus': CustomerConfirmationStatus.pending.name,
      'customerConfirmationCompletedAt': null,
    };
  }

  static String _serviceForOperationType(OrderOperationType operationType) {
    switch (operationType) {
      case OrderOperationType.unitTransfer:
        return 'unitTransfer';
      case OrderOperationType.internetSubscription:
        return 'internetSubscription';
      case OrderOperationType.callBundle:
      case OrderOperationType.mixedBundle:
        return 'calls';
      case OrderOperationType.other:
        return 'other';
    }
  }

  static String _readString(
    Map<String, dynamic> data,
    String key, {
    required String fallback,
  }) {
    final Object? value = data[key];

    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }

    return fallback;
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) {
      return null;
    }

    final String cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return 0;
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  static MobileNetwork _readNetwork(Object? value) {
    return MobileNetwork.values.firstWhere(
      (MobileNetwork item) => item.name == value,
      orElse: () => MobileNetwork.orange,
    );
  }

  static OrderOperationType _readOperationType(Object? value) {
    return OrderOperationType.values.firstWhere(
      (OrderOperationType item) => item.name == value,
      orElse: () => OrderOperationType.other,
    );
  }

  static OrderSource _readSource(Object? value) {
    return OrderSource.values.firstWhere(
      (OrderSource item) => item.name == value,
      orElse: () => OrderSource.operatorApp,
    );
  }

  static QueueOrderStatus _readStatus(Object? value) {
    return QueueOrderStatus.values.firstWhere(
      (QueueOrderStatus item) => item.name == value,
      orElse: () => QueueOrderStatus.awaitingPayment,
    );
  }

  static OrderPaymentStatus _readPaymentStatus(Object? value) {
    return OrderPaymentStatus.values.firstWhere(
      (OrderPaymentStatus item) => item.name == value,
      orElse: () => OrderPaymentStatus.pending,
    );
  }

  static OrderFailureReason? _readFailureReason(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    for (final OrderFailureReason reason in OrderFailureReason.values) {
      if (reason.name == value) {
        return reason;
      }
    }

    return OrderFailureReason.other;
  }

  static OrderAssignmentMode? _readAssignmentMode(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    for (final OrderAssignmentMode mode in OrderAssignmentMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }

    return null;
  }

  static OrderAssignmentStatus _readAssignmentStatus(Object? value) {
    if (value is! String || value.isEmpty) {
      return OrderAssignmentStatus.unassigned;
    }

    for (final OrderAssignmentStatus status in OrderAssignmentStatus.values) {
      if (status.name == value) {
        return status;
      }
    }

    return OrderAssignmentStatus.unassigned;
  }

  static CustomerConfirmationStatus? _readConfirmationStatus(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    for (final CustomerConfirmationStatus status
        in CustomerConfirmationStatus.values) {
      if (status.name == value) {
        return status;
      }
    }

    return null;
  }

  static String? _cleanNullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
