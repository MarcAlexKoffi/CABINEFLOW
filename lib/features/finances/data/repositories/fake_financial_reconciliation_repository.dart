import 'package:cabine_flow/features/finances/domain/models/financial_reconciliation_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/financial_reconciliation_repository.dart';

class FakeFinancialReconciliationRepository
    implements FinancialReconciliationRepository {
  FakeFinancialReconciliationRepository({
    List<FinancialReconciliationResult> results =
        const <FinancialReconciliationResult>[],
  }) : _results = results;

  final List<FinancialReconciliationResult> _results;

  @override
  Future<List<FinancialReconciliationResult>> load() async =>
      List<FinancialReconciliationResult>.unmodifiable(_results);
}
