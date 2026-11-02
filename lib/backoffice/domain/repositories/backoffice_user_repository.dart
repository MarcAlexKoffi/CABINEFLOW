import 'package:cabine_flow/backoffice/domain/models/backoffice_user_account.dart';
import 'package:cabine_flow/core/resilience/backend_failure_policy.dart';

enum BackofficeUserRegistrySource { firestore, supabase }

class BackofficeUserRegistryException implements Exception {
  const BackofficeUserRegistryException({
    required this.source,
    this.partial = false,
    this.kind = BackendFailureKind.unknown,
    this.code = 'unknown',
  });

  final BackofficeUserRegistrySource source;
  final bool partial;
  final BackendFailureKind kind;
  final String code;
}

abstract class BackofficeUserRepository {
  Stream<List<BackofficeUserAccount>> watchUsers();
}
