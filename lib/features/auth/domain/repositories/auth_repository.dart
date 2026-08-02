import 'package:cabine_flow/features/auth/domain/models/auth_login_result.dart';

abstract class AuthRepository {
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  });

  Future<AuthLoginResult> refreshCurrentAccess();

  Future<void> logout();
}
