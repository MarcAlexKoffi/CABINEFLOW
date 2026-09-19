import 'dart:async';

import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registre unifie des comptes IzyTel pour le back-office.
///
/// Les comptes Staff restent canoniques dans Firestore `users`. Les Cabinistes
/// restent canoniques dans Supabase `partner_accounts`; ils sont fusionnes ici
/// uniquement pour l'affichage Admin, sans les inscrire dans le registre Staff.
class FirestoreBackofficeUserRepository implements BackofficeUserRepository {
  FirestoreBackofficeUserRepository({
    FirebaseFirestore? firestore,
    SupabaseClient? supabaseClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _supabaseClient = supabaseClient;

  final FirebaseFirestore _firestore;
  final SupabaseClient? _supabaseClient;

  @override
  Stream<List<BackofficeUserAccount>> watchUsers() {
    final Stream<List<BackofficeUserAccount>> staffStream = _firestore.collection('users').snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDocument).toList(growable: false));

    final SupabaseClient? client = _supabaseClient ??
        (SupabaseBootstrap.isInitialized ? Supabase.instance.client : null);
    if (client == null) {
      return staffStream.map(_sorted);
    }

    late final StreamController<List<BackofficeUserAccount>> controller;
    StreamSubscription<List<BackofficeUserAccount>>? staffSubscription;
    StreamSubscription<List<Map<String, dynamic>>>? partnerSubscription;
    List<BackofficeUserAccount> staff = const <BackofficeUserAccount>[];
    List<BackofficeUserAccount> partners = const <BackofficeUserAccount>[];
    bool staffReady = false;
    bool partnersReady = false;

    void emit() {
      if (!staffReady && !partnersReady) return;
      final Map<String, BackofficeUserAccount> merged =
          <String, BackofficeUserAccount>{};
      for (final BackofficeUserAccount account in staff) {
        merged[account.id] = account;
      }
      // Le profil Cabiniste gagne sur un document Firestore pending/legacy du
      // meme UID afin que l'Admin voie le role operationnel reel.
      for (final BackofficeUserAccount account in partners) {
        merged[account.id] = account;
      }
      controller.add(_sorted(merged.values.toList(growable: false)));
    }

    controller = StreamController<List<BackofficeUserAccount>>.broadcast(
      onListen: () {
        staffSubscription = staffStream.listen(
          (List<BackofficeUserAccount> value) {
            staff = value;
            staffReady = true;
            emit();
          },
          onError: controller.addError,
        );
        partnerSubscription = client
            .from('partner_accounts')
            .stream(primaryKey: const <String>['id'])
            .order('created_at')
            .listen(
              (List<Map<String, dynamic>> rows) {
                partners = rows
                    .map(_fromPartnerRow)
                    .toList(growable: false);
                partnersReady = true;
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                // Une panne Supabase ne masque jamais le registre Staff.
                partnersReady = true;
                partners = const <BackofficeUserAccount>[];
                emit();
              },
            );
      },
      onCancel: () async {
        await staffSubscription?.cancel();
        await partnerSubscription?.cancel();
      },
    );

    return controller.stream;
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

  BackofficeUserAccount _fromPartnerRow(Map<String, dynamic> data) {
    final String firebaseUid = _string(data['firebase_uid']);
    final String partnerId = _string(data['id']);
    return BackofficeUserAccount(
      id: firebaseUid.isEmpty ? 'partner:$partnerId' : firebaseUid,
      name: _string(data['display_name'], fallback: 'Cabiniste IzyTel'),
      email: '',
      phoneNumber: _string(data['phone_number']),
      role: BackofficeAccountRole.cabiniste,
      isActive: _string(data['status']).toLowerCase() == 'active',
      createdAt: _dateTime(data['created_at']),
      updatedAt: _dateTime(data['updated_at']),
      lastActivityAt: _dateTime(data['last_seen_at']),
    );
  }

  List<BackofficeUserAccount> _sorted(List<BackofficeUserAccount> accounts) {
    final List<BackofficeUserAccount> result =
        List<BackofficeUserAccount>.from(accounts)..sort(_compareAccounts);
    return List<BackofficeUserAccount>.unmodifiable(result);
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
      case BackofficeAccountRole.cabiniste:
        return 4;
      case BackofficeAccountRole.operator:
        return 5;
      case BackofficeAccountRole.unknown:
        return 6;
    }
  }

  String _string(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }
}
