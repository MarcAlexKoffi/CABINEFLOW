import 'package:cabine_flow/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('une erreur asynchrone du profil est convertie lors du login', () async {
    final auth = _Auth();
    final repository = FirebaseAuthRepository(
      firebaseAuth: auth,
      firestore: _Store(),
    );
    final result = await repository.login(
      identifier: 'test@example.invalid',
      password: 'test',
    );
    expect(result.status, AuthLoginStatus.unavailable);
    expect(auth.signOuts, 1);
  });

  test(
    'restaurer la session retourne une erreur au lieu de bloquer le Splash',
    () async {
      final auth = _Auth();
      final repository = FirebaseAuthRepository(
        firebaseAuth: auth,
        firestore: _Store(),
      );
      final result = await repository.refreshCurrentAccess();
      expect(result.status, AuthLoginStatus.unavailable);
      expect(auth.signOuts, 0);
    },
  );
}

class _Auth implements FirebaseAuth {
  int signOuts = 0;
  @override
  User get currentUser => _User();
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => _Credential();
  @override
  Future<void> signOut() async {
    signOuts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  String get uid => 'test-uid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  @override
  User get user => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store implements FirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Intentional SDK doubles confined to this test; no production subclassing.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => _Document();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Document implements DocumentReference<Map<String, dynamic>> {
  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
