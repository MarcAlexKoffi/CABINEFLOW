import 'dart:async';

import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/backoffice/domain/repositories/backoffice_user_repository.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:cabine_flow/core/diagnostics/izytel_log.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final Stream<List<BackofficeUserAccount>> staffStream = _firestore
        .collection('users')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(_fromDocument).toList(growable: false),
        );

    final SupabaseClient? client =
        _supabaseClient ??
        (SupabaseBootstrap.isInitialized ? Supabase.instance.client : null);
    if (client == null) {
      return staffStream.map(_sorted);
    }

    late final StreamController<List<BackofficeUserAccount>> controller;
    StreamSubscription<List<BackofficeUserAccount>>? staffSubscription;
    StreamSubscription<List<Map<String, dynamic>>>? partnerSubscription;
    StreamSubscription<List<Map<String, dynamic>>>? capacitySubscription;
    StreamSubscription<List<Map<String, dynamic>>>? zoneSubscription;
    List<BackofficeUserAccount> staff = const <BackofficeUserAccount>[];
    List<BackofficeUserAccount> partners = const <BackofficeUserAccount>[];
    bool staffReady = false;
    bool partnersReady = false;
    List<Map<String, dynamic>> capacities = const [];
    List<Map<String, dynamic>> zones = const [];
    Object? pendingEnrichmentError;
    StackTrace? pendingEnrichmentStackTrace;

    void emit() {
      if (!staffReady && !partnersReady) return;
      final enriched = staff.map((account) {
        if (account.role == BackofficeAccountRole.manager) {
          return account.withBusinessDetails(
            zoneIds: zones
                .where((z) => z['manager_id'] == account.id)
                .map((z) => z['id'].toString())
                .toList(),
          );
        }
        if (account.role == BackofficeAccountRole.agent) {
          for (final capacity in capacities) {
            if (capacity['agent_id'] == account.id) {
              return account.withBusinessDetails(
                zoneIds: _strings(capacity['zone_ids']),
                authorizedNetworks: _strings(capacity['authorized_networks']),
              );
            }
          }
        }
        return account;
      }).toList();
      controller.add(_sorted(mergeAccounts(enriched, partners)));
    }

    void reportEnrichmentError(Object error, StackTrace stackTrace) {
      IzyTelLog.backendError(
        'BackofficeUsers.supabase',
        error,
        stackTrace: stackTrace,
      );
      pendingEnrichmentError = error;
      pendingEnrichmentStackTrace = stackTrace;
      if (!staffReady) return;
      emit();
      controller.addError(
        BackofficeUserRegistryException(
          source: BackofficeUserRegistrySource.supabase,
          partial: true,
          kind: BackendFailurePolicy.classify(error),
          code: BackendFailurePolicy.safeCode(error),
        ),
        stackTrace,
      );
      pendingEnrichmentError = null;
      pendingEnrichmentStackTrace = null;
    }

    Future<void> startSupabaseStreams() async {
      try {
        final String? token = await FirebaseAuth.instance.currentUser
            ?.getIdToken()
            .timeout(const Duration(seconds: 5));
        if (token == null || token.trim().isEmpty) {
          throw FirebaseException(
            plugin: 'firebase_auth',
            code: 'unauthenticated',
          );
        }
        await client.realtime
            .setAuth(token)
            .timeout(const Duration(seconds: 5));
        if (!controller.hasListener) return;

        partnerSubscription = client
            .from('partner_accounts')
            .stream(primaryKey: const <String>['id'])
            .order('created_at')
            .listen(
              (List<Map<String, dynamic>> rows) {
                partners = rows.map(_fromPartnerRow).toList(growable: false);
                partnersReady = true;
                emit();
              },
              onError: (Object error, StackTrace stackTrace) {
                // Une panne Supabase ne masque jamais le registre Staff.
                partnersReady = true;
                reportEnrichmentError(error, stackTrace);
              },
            );
        capacitySubscription = client
            .from('phase5_agent_capacities')
            .stream(primaryKey: const ['agent_id'])
            .listen((rows) {
              capacities = rows;
              emit();
            }, onError: reportEnrichmentError);
        zoneSubscription = client
            .from('territory_zones')
            .stream(primaryKey: const ['id'])
            .listen((rows) {
              zones = rows;
              emit();
            }, onError: reportEnrichmentError);
      } catch (error, stackTrace) {
        partnersReady = true;
        reportEnrichmentError(error, stackTrace);
      }
    }

    controller = StreamController<List<BackofficeUserAccount>>.broadcast(
      onListen: () {
        staffSubscription = staffStream.listen(
          (List<BackofficeUserAccount> value) {
            staff = value;
            staffReady = true;
            emit();
            if (pendingEnrichmentError != null) {
              final Object error = pendingEnrichmentError!;
              controller.addError(
                BackofficeUserRegistryException(
                  source: BackofficeUserRegistrySource.supabase,
                  partial: true,
                  kind: BackendFailurePolicy.classify(error),
                  code: BackendFailurePolicy.safeCode(error),
                ),
                pendingEnrichmentStackTrace,
              );
              pendingEnrichmentError = null;
              pendingEnrichmentStackTrace = null;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            IzyTelLog.backendError(
              'BackofficeUsers.firestore',
              error,
              stackTrace: stackTrace,
            );
            controller.addError(
              BackofficeUserRegistryException(
                source: BackofficeUserRegistrySource.firestore,
                kind: BackendFailurePolicy.classify(error),
                code: BackendFailurePolicy.safeCode(error),
              ),
              stackTrace,
            );
          },
        );
        unawaited(startSupabaseStreams());
      },
      onCancel: () async {
        await staffSubscription?.cancel();
        await partnerSubscription?.cancel();
        await capacitySubscription?.cancel();
        await zoneSubscription?.cancel();
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
      zoneIds: _strings(data['zoneIds']),
      authorizedNetworks: _strings(data['authorizedNetworks']),
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
      zoneIds: _strings(data['zone_ids']),
      authorizedNetworks: _strings(data['authorized_networks']),
    );
  }

  static List<String> _strings(Object? value) =>
      value is List ? value.map((v) => v.toString()).toList() : const [];

  static List<BackofficeUserAccount> mergeAccounts(
    List<BackofficeUserAccount> staff,
    List<BackofficeUserAccount> partners,
  ) {
    final merged = {for (final account in staff) account.id: account};
    for (final partner in partners) {
      final account = merged[partner.id];
      final staffRole =
          account != null &&
          [
            BackofficeAccountRole.administrator,
            BackofficeAccountRole.manager,
            BackofficeAccountRole.agent,
          ].contains(account.role);
      if (staffRole && !partner.isActive) continue;
      if (account != null &&
          staffRole &&
          account.isActive &&
          partner.isActive) {
        merged[partner.id] = account.withBusinessDetails(hasRoleConflict: true);
      } else {
        merged[partner.id] = partner;
      }
    }
    return merged.values.toList(growable: false);
  }

  List<BackofficeUserAccount> _sorted(List<BackofficeUserAccount> accounts) {
    final List<BackofficeUserAccount> result = List<BackofficeUserAccount>.from(
      accounts,
    )..sort(_compareAccounts);
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
