import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';

abstract class NetworkFinanceRepository {
  Stream<List<NetworkTransaction>> watchTransactions();
}
