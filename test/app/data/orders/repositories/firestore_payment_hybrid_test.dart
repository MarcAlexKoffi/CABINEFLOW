import 'package:cabine_flow/app/data/repositories/firestore_orders_repository.dart';
import 'package:cabine_flow/app/domain/entities/orders/queue_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'staff';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  @override
  User get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _Snapshot(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async => _Snapshot(
    id,
    path.startsWith('users/')
        ? {'role': store.role, 'isActive': true}
        : store.order,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.store, this.path);
  final _Store store;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(store, '${this.path}/${path ?? 'event'}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.store);
  final _Store store;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => (await (reference as _Document).get()) as DocumentSnapshot<T>;
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    store.writes[reference.path] = Map<String, dynamic>.from(data);
    return this;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    if (reference.path.startsWith('autoAssignmentQueue/')) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    store.writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements FirebaseFirestore {
  _Store({this.role = 'admin'});
  final String role;
  final writes = <String, Map<String, dynamic>>{};
  final order = <String, dynamic>{
    'reference': 'CF-20261117-FIXTURE',
    'source': 'customerWeb',
    'network': 'orange',
    'amount': 10000,
    'clientName': 'Client',
    'beneficiaryPhone': '+2250700000000',
    'offerLabel': '15 GO',
    'operationType': 'internetSubscription',
    'status': 'paymentToVerify',
    'paymentStatus': 'declared',
    'createdAt': Timestamp.fromDate(DateTime(2026, 11, 17)),
  };
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => transactionHandler(_Transaction(this));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final role in ['admin', 'manager']) {
    test(
      'hybrid $role confirms atomically when the retired native queue is denied',
      () async {
        final store = _Store(role: role);
        final repository = FirestoreOrdersRepository(
          firestore: store,
          firebaseAuth: _Auth(),
          enableNativeAutoAssignment: false,
        );
        final result = await repository.confirmPayment(
          orderId: 'order',
          paidAt: DateTime(2026, 11, 17),
          paymentReference: 'PAY-FIXTURE',
        );
        expect(result.paymentStatus, OrderPaymentStatus.confirmed);
        expect(
          store.writes.keys,
          unorderedEquals(['orders/order', 'orderEvents/event']),
        );
        expect(
          store.writes['orders/order']!['paymentConfirmedAt'],
          isA<FieldValue>(),
        );
        expect(store.writes['orderEvents/event']!['actorRole'], role);
        expect(store.writes['orderEvents/event']!['type'], 'PAYMENT_CONFIRMED');
      },
    );
  }
  test(
    'native engine still requires its queue in the confirmation transaction',
    () async {
      final store = _Store();
      final repository = FirestoreOrdersRepository(
        firestore: store,
        firebaseAuth: _Auth(),
      );
      await expectLater(
        repository.confirmPayment(
          orderId: 'order',
          paidAt: DateTime(2026, 11, 17),
        ),
        throwsA(
          isA<FirebaseException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );
  test('a non-staff account cannot confirm payments', () async {
    final store = _Store(role: 'customer');
    final repository = FirestoreOrdersRepository(
      firestore: store,
      firebaseAuth: _Auth(),
      enableNativeAutoAssignment: false,
    );
    await expectLater(
      repository.confirmPayment(
        orderId: 'order',
        paidAt: DateTime(2026, 11, 17),
      ),
      throwsStateError,
    );
    expect(store.writes, isEmpty);
  });
}
// The SDK interfaces are replaced only at the transaction test boundary.
// ignore_for_file: subtype_of_sealed_class
