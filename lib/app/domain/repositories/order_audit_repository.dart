import 'package:cabine_flow/app/domain/entities/audit/order_audit_entry.dart';

abstract class OrderAuditRepository {
  Stream<List<OrderAuditEntry>> watchForOrder({required String orderId});
}
