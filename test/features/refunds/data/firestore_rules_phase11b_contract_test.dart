import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'les règles 11B sécurisent les remboursements sans casser la baseline 9E',
    () {
      final String rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /refunds/{refundId}'));
      expect(rules, contains('hasValidRefundValues'));
      expect(rules, contains('isValidAdminRefundCreation'));
      expect(rules, contains('refundImmutableFieldsArePreserved'));
      expect(rules, contains('isValidRefundApproval'));
      expect(rules, contains('isValidRefundRejection'));
      expect(rules, contains('isValidRefundCompletion'));
      expect(rules, contains('isValidRefundCustomerNotification'));
      expect(rules, contains('isValidRefundReconciliation'));
      expect(
        rules,
        contains("request.resource.data.status == 'pendingApproval'"),
      );
      expect(rules, contains("request.resource.data.status == 'approved'"));
      expect(rules, contains("request.resource.data.status == 'refunded'"));
      expect(rules, contains("request.resource.data.status == 'reconciled'"));
      expect(rules, contains("request.resource.data.status == 'rejected'"));
      expect(rules, contains("order.paymentStatus == 'confirmed'"));
      expect(rules, contains('refundId == orderId'));
      expect(rules, contains('allow get, list: if isAdmin();'));
      expect(rules, contains('allow delete: if false;'));

      // Phase 13A ajoute un getAfter unidirectionnel networkTransaction -> order
      // sans modifier les garde-fous 9E ni les flux précédents.
      expect(RegExp(r'getAfter\(').allMatches(rules), hasLength(25));
      expect(rules, contains('hasMatchingAutomaticAssignmentArtifacts'));
      expect(rules, contains('autoAssignmentRefusedAgentIds'));
      expect(rules, contains('manualAssignmentRequired'));
      expect(rules, contains('match /orderRecoveryKeys/{recoveryKey}'));
    },
  );
}
