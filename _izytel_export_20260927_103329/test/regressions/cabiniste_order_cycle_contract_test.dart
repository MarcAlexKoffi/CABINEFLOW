import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('cabiniste repository uses dedicated partner RPCs', () {
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    expect(repository, contains("'phase4_partner_action'"));
    expect(repository, contains("'phase4_partner_processing_action'"));
    expect(repository, contains("'phase5_upsert_partner_order_proof'"));
    expect(repository, contains("'phase5_finalize_partner_order_success'"));
    expect(repository, contains("'izytel_update_own_partner_operations'"));
  });

  test('cabiniste proof remains private and namespaced', () {
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );

    expect(repository, contains("proofBucket = 'order-proofs'"));
    expect(repository, contains("'partners/\$uid/\$cleanedOrderId/proof.jpg'"));
    expect(repository, contains('maximumProofBytes = 750000'));
    expect(repository, contains("contentType: 'image/jpeg'"));
  });

  test('cabiniste economics stay server derived', () {
    final String repository = source(
      'lib/features/partners/data/repositories/supabase_partner_order_repository.dart',
    );
    final String models = source(
      'lib/features/partners/domain/models/partner_order_models.dart',
    );

    expect(repository, isNot(contains('partner_margin_share_bps')));
    expect(repository, isNot(contains('telecom_margin_bps')));
    expect(repository, contains("row['cabiniste_margin_amount']"));
    expect(repository, contains("row['izytel_gross_gain']"));
    expect(models, contains('cabinisteSettlementAmount'));
  });
}
