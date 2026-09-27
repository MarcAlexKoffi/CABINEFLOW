import 'package:cabine_flow/backoffice/domain/models/backoffice_finance_snapshot.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

abstract class BackofficeFinanceRepository {
  Stream<BackofficeFinanceSnapshot> watchSnapshot();
  Future<BackofficeFinanceSnapshot> fetchSnapshot();

  Future<void> setWaveOpening({required int amount, String? note});

  Future<String> saveSupplier({
    String? supplierId,
    required String name,
    required String phoneNumber,
    String? note,
  });

  Future<void> setSupplierActive({required String supplierId, required bool isActive});
  Future<void> deleteSupplier(String supplierId);

  Future<String> recordSupplierRecharge({
    required String supplierId,
    required String agentId,
    required String agentName,
    required String network,
    required int principal,
    required int bonus,
    required int amountOwed,
    String? note,
    required String staffName,
  });

  Future<String> recordSupplierPayment({
    required String supplierId,
    required int amount,
    required String channel,
    required String reference,
    String? note,
    required String staffName,
  });

  Future<String> recordCommissionPayout({
    required String agentId,
    required String agentName,
    required int amount,
    required String reference,
    String? note,
    required String staffName,
  });

  Future<Map<String, dynamic>> recordCabinistePayout({
    required String partnerId,
    required int amount,
    required String channel,
    required String reference,
    String? note,
    String? periodId,
  });

  Future<Map<String, dynamic>> fetchCabinisteFinanceHistory({
    required String partnerId,
    int limit = 50,
  });

  /// Autorise atomiquement une commande pré-paiement comme vente à crédit
  /// dans Supabase, sans écriture opérationnelle de secours dans Firestore.
  Future<String> authorizeCreditOrder({
    required QueueOrder order,
    String? note,
  });

  Future<String> createCredit({
    String? creditId,
    required String orderId,
    required String orderReference,
    required String clientName,
    required String clientWhatsappPhone,
    required int amount,
    String? note,
  });

  Future<String> settleCredit({
    required String creditId,
    required int amount,
    required String channel,
    required String reference,
    String? note,
  });

  Future<String> recordExpense({
    required String category,
    required int amount,
    required String description,
    required String channel,
    String? reference,
  });

  Future<String> createClosing(Map<String, dynamic> payload);
}
