import 'package:cabine_flow/app/domain/entities/finance/financial_reconciliation_models.dart';

abstract class FinancialReconciliationRepository {
  Future<List<FinancialReconciliationResult>> load();
}
