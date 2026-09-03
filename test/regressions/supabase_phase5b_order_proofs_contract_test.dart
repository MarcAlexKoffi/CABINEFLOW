import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  test('les nouvelles preuves utilisent Supabase Storage et metadata SQL', () {
    final String repository = read(
      'lib/features/orders/data/repositories/supabase_order_proof_repository.dart',
    );

    expect(repository, contains("tableName = 'phase5_order_proofs'"));
    expect(repository, contains("bucketName = 'order-proofs'"));
    expect(repository, contains('maximumProofBytes = 750000'));
    expect(repository, contains('.uploadBinary('));
    expect(repository, contains("onConflict: 'order_id'"));
    expect(repository, contains('.download(storagePath)'));
  });

  test('le depot hybride necrit plus les nouvelles preuves dans Firestore', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );

    final int saveStart = hybrid.indexOf('Future<OrderProof> saveOrderProof');
    final int successStart = hybrid.indexOf(
      'Future<QueueOrder> markAgentSuccessful',
      saveStart,
    );
    expect(saveStart, greaterThanOrEqualTo(0));
    expect(successStart, greaterThan(saveStart));
    final String saveBlock = hybrid.substring(saveStart, successStart);

    expect(saveBlock, contains('_proofs.saveProof('));
    expect(saveBlock, isNot(contains('_firestore.saveOrderProof(')));
    expect(hybrid, contains('requireFirestoreProof: false'));
    expect(hybrid, contains('_proofs.fetchProof(orderId: orderId)'));
  });

  test(
    'la finalisation cree un pont Firestore uniquement pour la regle legacy',
    () {
      final String hybrid = read(
        'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
      );

      final int successStart = hybrid.indexOf(
        'Future<QueueOrder> markAgentSuccessful',
      );
      final int failedStart = hybrid.indexOf(
        'Future<QueueOrder> markAgentFailed',
        successStart,
      );
      expect(successStart, greaterThanOrEqualTo(0));
      expect(failedStart, greaterThan(successStart));
      final String successBlock = hybrid.substring(successStart, failedStart);

      expect(successBlock, contains('[Phase5B1][proof-bridge]'));
      expect(successBlock, contains('_proofs.fetchProof('));
      expect(successBlock, contains('orderId: orderId'));
      expect(successBlock, contains('_firestore.fetchOrderProof('));
      expect(successBlock, contains('_firestore.saveOrderProof('));
      expect(successBlock, contains('_firestore.markAgentSuccessful('));
    },
  );

  test('les anciennes preuves Firestore restent lisibles en transition', () {
    final String hybrid = read(
      'lib/features/orders/data/repositories/hybrid_orders_repository.dart',
    );

    expect(hybrid, contains('Compatibilite historique uniquement'));
    expect(hybrid, contains('_firestore.fetchOrderProof(orderId: orderId)'));
  });

  test('le rapprochement financier reconnait aussi les preuves Supabase', () {
    final String reconciliation = read(
      'lib/features/finances/data/repositories/'
      'firestore_financial_reconciliation_repository.dart',
    );

    expect(reconciliation, contains('SupabaseOrderProofRepository'));
    expect(reconciliation, contains('fetchProofOrderIdsForStaff()'));
    expect(reconciliation, contains('proofOrderIds.addAll('));
  });

  test('Firestore garde son controle de preuve hors du depot hybride', () {
    final String firestore = read(
      'lib/features/orders/data/repositories/firestore_orders_repository.dart',
    );

    expect(firestore, contains('bool requireFirestoreProof = true'));
    expect(firestore, contains('final bool _requireFirestoreProof'));
    expect(firestore, contains('if (_requireFirestoreProof'));
  });
}
