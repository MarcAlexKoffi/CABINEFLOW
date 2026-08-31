import 'dart:async';

import 'package:cabine_flow/features/finances/domain/models/network_finance_models.dart';
import 'package:cabine_flow/features/finances/domain/repositories/network_finance_repository.dart';

class FakeNetworkFinanceRepository implements NetworkFinanceRepository {
  FakeNetworkFinanceRepository({List<NetworkTransaction>? transactions})
    : _transactions = List<NetworkTransaction>.from(
        transactions ?? const <NetworkTransaction>[],
      ) {
    _controller.add(_snapshot());
  }

  final List<NetworkTransaction> _transactions;
  final StreamController<List<NetworkTransaction>> _controller =
      StreamController<List<NetworkTransaction>>.broadcast();

  @override
  Stream<List<NetworkTransaction>> watchTransactions() async* {
    yield _snapshot();
    yield* _controller.stream;
  }

  Future<void> dispose() => _controller.close();

  List<NetworkTransaction> _snapshot() {
    final List<NetworkTransaction> values =
        List<NetworkTransaction>.from(_transactions)..sort(
          (NetworkTransaction a, NetworkTransaction b) =>
              b.createdAt.compareTo(a.createdAt),
        );
    return List<NetworkTransaction>.unmodifiable(values);
  }
}
