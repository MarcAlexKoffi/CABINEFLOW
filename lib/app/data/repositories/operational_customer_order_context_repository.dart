import 'package:cabine_flow/app/data/sources/supabase_bootstrap.dart';
import 'package:cabine_flow/app/data/repositories/fake_customer_order_context_repository.dart';
import 'package:cabine_flow/app/data/repositories/supabase_customer_order_context_repository.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_order_context.dart';
import 'package:cabine_flow/app/domain/entities/customer/customer_order_receipt.dart';
import 'package:cabine_flow/app/domain/repositories/customer_order_context_repository.dart';
import 'package:firebase_core/firebase_core.dart';

CustomerOrderContextRepository createOperationalCustomerOrderContextRepository() {
  if (SupabaseBootstrap.isInitialized) {
    return SupabaseCustomerOrderContextRepository();
  }
  if (Firebase.apps.isEmpty) {
    return FakeCustomerOrderContextRepository();
  }
  return const _UnavailableCustomerOrderContextRepository();
}

class _UnavailableCustomerOrderContextRepository
    implements CustomerOrderContextRepository {
  const _UnavailableCustomerOrderContextRepository();

  @override
  Future<void> registerContext({
    required CustomerOrderReceipt order,
    required CustomerOrderContextDraft context,
  }) {
    return Future<void>.error(
      StateError(
        'Supabase est indisponible. Le contexte client ne bascule pas vers Firestore.',
      ),
    );
  }
}
