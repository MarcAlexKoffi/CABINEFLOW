import 'dart:async';
import 'package:cabine_flow/features/auth/domain/models/app_user.dart';
import 'package:cabine_flow/features/auth/presentation/widgets/session_access_boundary.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(
    id: 'target',
    name: 'Test',
    phoneNumber: '',
    role: UserRole.manager,
  );
  testWidgets(
    'only confirmed role/status changes invalidate the session once',
    (tester) async {
      final records = StreamController<SessionAccessRecord>();
      var invalidations = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SessionAccessBoundary(
            user: user,
            accessRecords: records.stream,
            onAccessChanged: () async {
              invalidations++;
            },
            child: const Text('Session'),
          ),
        ),
      );
      records.add(const SessionAccessRecord(role: 'supervisor', active: true));
      await tester.pump();
      expect(invalidations, 0);
      records.add(
        const SessionAccessRecord(
          role: 'manager',
          active: false,
          serverConfirmed: false,
        ),
      );
      await tester.pump();
      expect(invalidations, 0);
      records.add(const SessionAccessRecord(role: 'agent', active: true));
      await tester.pump(const Duration(milliseconds: 10));
      expect(invalidations, 1);
      records.add(const SessionAccessRecord(role: 'manager', active: false));
      await tester.pump(const Duration(milliseconds: 10));
      expect(invalidations, 1);
      await records.close();
    },
  );
  testWidgets(
    'network errors do not fabricate a revocation, confirmed disable does',
    (tester) async {
      final records = StreamController<SessionAccessRecord>();
      var invalidations = 0;
      await tester.pumpWidget(
        SessionAccessBoundary(
          user: user,
          accessRecords: records.stream,
          onAccessChanged: () async {
            invalidations++;
          },
          child: const SizedBox(),
        ),
      );
      records.addError(StateError('offline'));
      await tester.pump();
      expect(invalidations, 0);
      records.add(const SessionAccessRecord(role: 'manager', active: false));
      await tester.pump(const Duration(milliseconds: 10));
      expect(invalidations, 1);
      await records.close();
    },
  );
  test('canonical aliases retain the same authorization meaning', () {
    expect(
      const SessionAccessRecord(role: 'administrator', active: true).allows(
        const AppUser(
          id: 'a',
          name: 'A',
          phoneNumber: '',
          role: UserRole.administrator,
        ),
      ),
      true,
    );
    expect(
      const SessionAccessRecord(role: 'partner', active: true).allows(
        const AppUser(
          id: 'p',
          name: 'P',
          phoneNumber: '',
          role: UserRole.cabiniste,
        ),
      ),
      true,
    );
    expect(
      const SessionAccessRecord(role: 'operator', active: true).allows(user),
      false,
    );
  });
}
