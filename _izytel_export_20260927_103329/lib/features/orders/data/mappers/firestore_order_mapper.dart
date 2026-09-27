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
      createdAt: _readHistoricalCreatedAt(data),
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
      lastAssignmentRefusedAgentId: _readNullableString(
        data['lastAssignmentRefusedAgentId'],
      ),
      autoAssignmentRefusedAgentIds: _readStringList(
        data['autoAssignmentRefusedAgentIds'],
      ),
      manualAssignmentRequired: _readBool(data['manualAssignmentRequired']),
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

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .whereType<String>()
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final String token = _normalizedToken(value);
    if (token == 'true' || token == '1' || token == 'yes') return true;
    return false;
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final String compact = value.trim().replaceAll(RegExp(r'\s+'), '');
      return int.tryParse(compact) ?? double.tryParse(compact)?.toInt() ?? 0;
    }
    return 0;
  }

  static DateTime _readHistoricalCreatedAt(Map<String, dynamic> data) {
    final DateTime? direct = _readDate(data['createdAt']);
    if (direct != null) return direct;

    final List<DateTime> candidates = <DateTime?>[
      _readDate(data['paymentRequestSentAt']),
      _readDate(data['paymentDeclaredAt']),
      _readDate(data['paidAt']),
      _readDate(data['paymentConfirmedAt']),
      _readDate(data['assignedAt']),
      _readDate(data['takenAt']),
      _readDate(data['completedAt']),
      _readDate(data['expiredAt']),
    ].whereType<DateTime>().toList(growable: false);

    if (candidates.isNotEmpty) {
      candidates.sort();
      return candidates.first;
    }

    // Anciennes lignes vraiment incompletes : une date stable vaut mieux que
    // DateTime.now(), qui faisait "rajeunir" la commande a chaque lecture.
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      final String text = value.trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    if (value is num) {
      final int raw = value.toInt();
      if (raw == 0) return null;
      // Les anciens imports ont pu stocker un epoch en secondes ou en ms.
      final int millis = raw.abs() < 100000000000 ? raw * 1000 : raw;
      try {
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      } on RangeError {
        return null;
      }
    }

    return null;
  }

  static String _normalizedToken(Object? value) {
    if (value is! String) return '';
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
  }

  static T? _enumByNormalizedName<T extends Enum>(
    Iterable<T> values,
    Object? value,
  ) {
    final String token = _normalizedToken(value);
    if (token.isEmpty) return null;
    for (final T item in values) {
      if (_normalizedToken(item.name) == token) return item;
    }
    return null;
  }

  static MobileNetwork _readNetwork(Object? value) {
    final String token = _normalizedToken(value);
    if (token.startsWith('moov')) return MobileNetwork.moov;
    return _enumByNormalizedName(MobileNetwork.values, value) ??
        MobileNetwork.orange;
  }

  static OrderOperationType _readOperationType(Object? value) {
    return _enumByNormalizedName(OrderOperationType.values, value) ??
        OrderOperationType.other;
  }

  static OrderSource _readSource(Object? value) {
    return _enumByNormalizedName(OrderSource.values, value) ??
        OrderSource.operatorApp;
  }

  static QueueOrderStatus _readStatus(Object? value) {
    return _enumByNormalizedName(QueueOrderStatus.values, value) ??
        QueueOrderStatus.awaitingPayment;
  }

  static OrderPaymentStatus _readPaymentStatus(Object? value) {
    return _enumByNormalizedName(OrderPaymentStatus.values, value) ??
        OrderPaymentStatus.pending;
  }

  static OrderFailureReason? _readFailureReason(Object? value) {
    if (_normalizedToken(value).isEmpty) return null;
    return _enumByNormalizedName(OrderFailureReason.values, value) ??
        OrderFailureReason.other;
  }

  static OrderAssignmentMode? _readAssignmentMode(Object? value) {
    return _enumByNormalizedName(OrderAssignmentMode.values, value);
  }

  static OrderAssignmentStatus _readAssignmentStatus(Object? value) {
    return _enumByNormalizedName(OrderAssignmentStatus.values, value) ??
        OrderAssignmentStatus.unassigned;
  }

  static CustomerConfirmationStatus? _readConfirmationStatus(Object? value) {
    return _enumByNormalizedName(CustomerConfirmationStatus.values, value);
  }

  static String? _cleanNullable(String? value) {
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }
}
