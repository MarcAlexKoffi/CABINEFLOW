import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Lecture du registre de comptes IzyTel pour le back-office.
///
/// BO-1 reste volontairement en lecture seule : la creation d'un compte
/// Firebase Auth et la synchronisation des roles staff Supabase doivent passer
/// par une action serveur adminisee, et non par un SDK client Web.
class FirestoreBackofficeUserRepository implements BackofficeUserRepository {
  FirestoreBackofficeUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Stream<List<BackofficeUserAccount>> watchUsers() {
    return _firestore.collection('users').snapshots().map((snapshot) {
      final List<BackofficeUserAccount> accounts = snapshot.docs
          .map((doc) => _fromDocument(doc))
          .toList(growable: false)
        ..sort(_compareAccounts);
      return List<BackofficeUserAccount>.unmodifiable(accounts);
    });
  }

  BackofficeUserAccount _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data();
    final String roleRaw = _string(data['role'], fallback: 'pending');

    return BackofficeUserAccount(
      id: document.id,
      name: _string(data['name'], fallback: 'Utilisateur IzyTel'),
      email: _string(data['email']),
      phoneNumber: _string(data['phoneNumber']),
      role: BackofficeAccountRoleX.fromBackend(roleRaw),
      isActive: data['isActive'] == true,
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
      lastActivityAt:
          _dateTime(data['lastLoginAt']) ?? _dateTime(data['lastSeenAt']),
    );
  }

  int _compareAccounts(
    BackofficeUserAccount first,
    BackofficeUserAccount second,
  ) {
    final int firstRank = _roleRank(first.role);
    final int secondRank = _roleRank(second.role);
    if (firstRank != secondRank) return firstRank.compareTo(secondRank);
    return first.name.toLowerCase().compareTo(second.name.toLowerCase());
  }

  int _roleRank(BackofficeAccountRole role) {
    switch (role) {
      case BackofficeAccountRole.pending:
        return 0;
      case BackofficeAccountRole.administrator:
        return 1;
      case BackofficeAccountRole.manager:
        return 2;
      case BackofficeAccountRole.agent:
        return 3;
      case BackofficeAccountRole.operator:
        return 4;
      case BackofficeAccountRole.unknown:
        return 5;
    }
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
