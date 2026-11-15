import 'package:cabine_flow/app/domain/entities/finance/network_finance_models.dart';

abstract class NetworkFinanceRepository {
  Stream<List<NetworkTransaction>> watchTransactions();
}
