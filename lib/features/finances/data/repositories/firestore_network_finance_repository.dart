import 'package:cabine_flow/features/agents/domain/models/agent_models.dart';
import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/network_finance_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreNetworkFinanceRepository implements NetworkFinanceRepository {
  FirestoreNetworkFinanceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('networkTransactions');

  @override
  Stream<List<NetworkTransaction>> watchTransactions() {
    return _transactions
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          final List<NetworkTransaction> transactions = snapshot.docs
              .map(_fromDocument)
              .whereType<NetworkTransaction>()
              .toList(growable: false);
          return List<NetworkTransaction>.unmodifiable(transactions);
        });
  }

  NetworkTransaction? _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final AgentNetwork? network = _network(data['network']);
    final NetworkTransactionDirection? direction = _direction(
      data['direction'],
    );
    final NetworkTransactionType? type = _type(data['type']);
    final DateTime? createdAt = _date(data['createdAt']);
    final int amount = _int(data['amount']);
    if (network == null ||
        direction == null ||
        type == null ||
        createdAt == null ||
        amount <= 0) {
      return null;
    }

    return NetworkTransaction(
      id: document.id,
      network: network,
      direction: direction,
      type: type,
      amount: amount,
      capacityBefore: _int(data['capacityBefore']),
      capacityAfter: _int(data['capacityAfter']),
      agentId: _nullableString(data['agentId']),
      agentName: _nullableString(data['agentName']),
      orderId: _nullableString(data['orderId']),
      orderReference: _nullableString(data['orderReference']),
      createdBy: _string(data['createdBy']),
      createdByRole: _string(data['createdByRole']),
      createdAt: createdAt,
    );
  }

  AgentNetwork? _network(Object? value) {
    if (value is! String) return null;
    for (final AgentNetwork network in AgentNetwork.values) {
      if (network.firestoreValue == value) return network;
    }
    return null;
  }

  NetworkTransactionDirection? _direction(Object? value) {
    if (value is! String) return null;
    for (final NetworkTransactionDirection direction
        in NetworkTransactionDirection.values) {
      if (direction.name == value) return direction;
    }
    return null;
  }

  NetworkTransactionType? _type(Object? value) {
    if (value is! String) return null;
    for (final NetworkTransactionType type in NetworkTransactionType.values) {
      if (type.name == value) return type;
    }
    return null;
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _string(Object? value) {
    if (value is String) return value.trim();
    return '';
  }

  String? _nullableString(Object? value) {
    final String valueAsString = _string(value);
    return valueAsString.isEmpty ? null : valueAsString;
  }

  DateTime? _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
