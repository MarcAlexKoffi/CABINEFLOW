import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('Flutter expose Manager avec alias supervisor sans toucher aux rules', () {
    final String model = File(
      'lib/features/auth/domain/models/app_user.dart',
    ).readAsStringSync();
    final String auth = compact(
      File(
        'lib/features/auth/data/repositories/firebase_auth_repository.dart',
      ).readAsStringSync(),
    );
    final String permissions = File(
      'lib/features/auth/domain/permissions/user_permissions.dart',
    ).readAsStringSync();

    expect(model, contains('manager'));
    expect(model, contains("return 'Manager';"));
    expect(auth, contains("case 'manager': return UserRole.manager;"));
    expect(auth, contains("case 'supervisor':"));
    expect(permissions, contains('firestoreCompatibilityRole'));
    expect(permissions, contains("return 'supervisor';"));
  });

  test('repository Firestore garde uniquement les roles deja publies', () {
    final String orders = File(
      'lib/features/orders/data/repositories/firestore_orders_repository.dart',
    ).readAsStringSync();

    expect(orders, contains("{'operator', 'supervisor', 'admin'}"));
    expect(
      orders,
      isNot(contains("{'operator', 'manager', 'supervisor', 'admin'}")),
    );
  });

  test('audit affiche supervisor et manager comme Manager', () {
    final String audit = File(
      'lib/features/audit/domain/models/order_audit_entry.dart',
    ).readAsStringSync();

    expect(audit, contains("case 'manager':"));
    expect(audit, contains("case 'supervisor':"));
    expect(audit, contains("return 'Manager';"));
  });
}
