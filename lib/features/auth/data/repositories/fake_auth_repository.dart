import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  const FakeAuthRepository();

  @override
  Future<AppUser?> login({
    required String identifier,
    required String password,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));

    final String normalizedIdentifier = identifier.trim().toLowerCase();

    final bool isValidIdentifier =
        normalizedIdentifier == 'marc' || normalizedIdentifier == '0700000000';

    final bool isValidPassword = password == '1234';

    if (!isValidIdentifier || !isValidPassword) {
      return null;
    }

    return const AppUser(
      id: 'USR-001',
      name: 'Marc Alex',
      phoneNumber: '0700000000',
      role: UserRole.administrator,
    );
  }
}
