import 'package:cabine_flow/features/finances/domain/models/financial_reconciliation_models.dart';

abstract class FinancialReconciliationRepository {
  Future<List<FinancialReconciliationResult>> load();
}
