import 'package:cabine_flow/features/auth/domain/models/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> login({
    required String identifier,
    required String password,
  });
}
