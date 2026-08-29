import 'package:cabine_flow/features/audit/domain/models/order_audit_entry.dart';

abstract class OrderAuditRepository {
  Stream<List<OrderAuditEntry>> watchForOrder({required String orderId});
}
