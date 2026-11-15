import 'package:cabine_flow/app/domain/entities/auth/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le rôle agent possède son libellé', () {
    const AppUser user = AppUser(
      id: 'AG-001',
      name: 'Agent Test',
      phoneNumber: '0700000000',
      role: UserRole.agent,
    );

    expect(user.roleLabel, 'Agent');
  });
}
