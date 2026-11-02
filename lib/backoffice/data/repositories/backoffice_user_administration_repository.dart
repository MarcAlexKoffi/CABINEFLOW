import 'dart:convert';
import 'dart:math';

import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UserAdminZone {
  const UserAdminZone(this.id, this.name, {this.managerUid});
  final String id;
  final String name;
  final String? managerUid;
}

class UserAdminDetails {
  const UserAdminDetails({
    this.zoneIds = const [],
    this.authorizedNetworks = const [],
    this.email,
  });
  final List<String> zoneIds;
  final List<String> authorizedNetworks;
  final String? email;
}

class UserAdminException implements Exception {
  const UserAdminException(
    this.code, {
    this.operationId,
    this.requiresRepair = false,
  });
  final String code;
  final String? operationId;
  final bool requiresRepair;
  @override
  String toString() =>
      '$message${operationId == null ? '' : ' Référence : $operationId'}';
  String get message => switch (code) {
    'EMAIL_ALREADY_EXISTS' => 'Cet e-mail est déjà utilisé.',
    'EMAIL_REQUIRED' =>
      'Ce compte ne possède pas d’e-mail de connexion exploitable. Faites vérifier son identité.',
    'LAST_ADMIN' => 'Le dernier Administrateur actif doit être conservé.',
    'SELF_ADMIN_OPERATION_FORBIDDEN' =>
      'Un Administrateur ne modifie pas son propre accès depuis cette page.',
    'REFERENCES_NOT_VERIFIED' =>
      'La suppression est bloquée : les références historiques ne sont pas entièrement vérifiées. Utilisez la désactivation.',
    'ZONE_OCCUPIED' =>
      'Une zone sélectionnée est déjà attribuée à un autre Manager.',
    'ACCOUNT_CONFLICT' => 'Un compte métier existe déjà pour cet utilisateur.',
    'ADMIN_OPERATION_PENDING' =>
      'Une opération administrative est en attente de vérification. Contactez le support.',
    'OPERATION_REQUIRES_REPAIR' =>
      'Une opération est incomplète et nécessite une vérification du support. Ne créez pas une seconde opération.',
    'OPERATION_RESULT_UNKNOWN' =>
      'Le résultat n’est pas confirmé. Consultez l’historique avant toute nouvelle action.',
    'IDEMPOTENCY_CONFLICT' =>
      'Cette tentative ne correspond plus à la demande initiale. Faites vérifier sa référence.',
    'AUTH_REQUIRED' || 'ADMIN_REQUIRED' =>
      'Une session Administrateur active est nécessaire. Reconnectez-vous.',
    'INVALID_RESPONSE' =>
      'La réponse du serveur est invalide. Vérifiez l’opération avant de recommencer.',
    _ => 'L’opération n’a pas abouti ($code).',
  };
}

abstract class BackofficeUserAdministration {
  Future<List<UserAdminZone>> loadZones();
  Future<UserAdminDetails> loadDetails(BackofficeUserAccount user);
  Future<Map<String, dynamic>> send(Map<String, dynamic> command);
}

class BackofficeUserAdministrationRepository
    implements BackofficeUserAdministration {
  BackofficeUserAdministrationRepository({
    http.Client? httpClient,
    SupabaseClient? supabaseClient,
    Future<String?> Function()? tokenProvider,
    Uri? endpoint,
  }) : _http = httpClient ?? http.Client(),
       _supabase = supabaseClient,
       _token =
           tokenProvider ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken(true) ??
               Future<String?>.value()),
       _endpoint =
           endpoint ??
           Uri.parse('${SupabaseBootstrap.url}/functions/v1/izytel-user-admin');

  final http.Client _http;
  final SupabaseClient? _supabase;
  final Future<String?> Function() _token;
  final Uri _endpoint;
  SupabaseClient get _client => _supabase ?? Supabase.instance.client;

  static String newRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  @override
  Future<Map<String, dynamic>> send(Map<String, dynamic> command) async {
    final token = await _token();
    if (token == null || token.trim().isEmpty) {
      throw const UserAdminException('AUTH_REQUIRED');
    }
    final response = await _http
        .post(
          _endpoint,
          headers: {
            'Authorization': 'Bearer $token',
            'apikey': SupabaseBootstrap.publishableKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(command),
        )
        .timeout(const Duration(seconds: 40));
    Map<String, dynamic> result;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw const FormatException();
      result = Map<String, dynamic>.from(decoded);
    } on FormatException {
      throw const UserAdminException('INVALID_RESPONSE');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['ok'] != true) {
      throw UserAdminException(
        result['error']?.toString() ?? 'ADMIN_OPERATION_FAILED',
        operationId: result['operationId']?.toString(),
        requiresRepair: result['requiresRepair'] == true,
      );
    }
    return result;
  }

  @override
  Future<List<UserAdminZone>> loadZones() async {
    final rows = await _client
        .from('territory_zones')
        .select('id,name,manager_id')
        .eq('is_active', true)
        .order('name');
    return rows
        .map(
          (r) => UserAdminZone(
            r['id'].toString(),
            r['name'].toString(),
            managerUid: r['manager_id'] as String?,
          ),
        )
        .toList();
  }

  @override
  Future<UserAdminDetails> loadDetails(BackofficeUserAccount user) async {
    final response = await send({
      'action': 'details',
      'uid': user.id,
      'requestId': newRequestId(),
    });
    final account = response['account'];
    if (account is! Map || account['uid'] != user.id) {
      throw const UserAdminException('INVALID_RESPONSE');
    }
    final email = account['email'] as String?;
    if (user.role == BackofficeAccountRole.manager) {
      final rows = await _client
          .from('territory_zones')
          .select('id')
          .eq('manager_id', user.id);
      return UserAdminDetails(
        email: email,
        zoneIds: rows.map((r) => r['id'].toString()).toList(),
      );
    }
    if (user.role == BackofficeAccountRole.agent ||
        user.role == BackofficeAccountRole.cabiniste) {
      final partner = user.role == BackofficeAccountRole.cabiniste;
      final row = await _client
          .from(partner ? 'partner_accounts' : 'phase5_agent_capacities')
          .select('zone_ids,authorized_networks')
          .eq(partner ? 'firebase_uid' : 'agent_id', user.id)
          .maybeSingle();
      if (row == null) {
        throw StateError(
          'Le profil métier est introuvable. Vérifiez ce compte avant modification.',
        );
      }
      return UserAdminDetails(
        email: email,
        zoneIds: _strings(row['zone_ids']),
        authorizedNetworks: _strings(row['authorized_networks']),
      );
    }
    return UserAdminDetails(email: email);
  }

  static List<String> _strings(Object? value) =>
      value is List ? value.map((v) => v.toString()).toList() : const [];
}
