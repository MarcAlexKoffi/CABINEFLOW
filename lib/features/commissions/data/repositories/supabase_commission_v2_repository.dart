import 'dart:async';

import 'package:cabine_flow/core/supabase/supabase_bootstrap.dart';

import 'package:cabine_flow/features/commissions/domain/models/commission_models.dart';
import 'package:cabine_flow/features/commissions/domain/models/commission_v2_models.dart';
import 'package:cabine_flow/features/commissions/domain/repositories/commission_v2_repository.dart';
import 'package:cabine_flow/features/finances/data/repositories/supabase_phase5_finance_repository.dart';

/// Uses the same canonical, server-authorized register as commission payments.
class SupabaseCommissionV2Repository implements CommissionV2Repository {
  SupabaseCommissionV2Repository({SupabasePhase5FinanceRepository? repository})
    : _repository = repository;

  final SupabasePhase5FinanceRepository? _repository;

  @override
  Stream<CommissionV2Snapshot> watchAdmin() => _watch();

  @override
  Stream<CommissionV2Snapshot> watchAgent(String agentId) => _forAgent(agentId);

  @override
  Stream<CommissionV2Snapshot> watchAdminAgent(String agentId) =>
      _forAgent(agentId);

  Stream<CommissionV2Snapshot> _forAgent(String agentId) {
    final String id = agentId.trim();
    if (id.isEmpty) {
      return Stream<CommissionV2Snapshot>.error(
        ArgumentError.value(agentId, 'agentId', 'Agent ID is required.'),
      );
    }
    return _watch(agentId: id);
  }

  Stream<CommissionV2Snapshot> _watch({String? agentId}) {
    if (_repository == null && !SupabaseBootstrap.isInitialized) {
      return Stream<CommissionV2Snapshot>.error(
        StateError('Supabase est indisponible pour les commissions.'),
      );
    }
    final source = _repository ?? SupabasePhase5FinanceRepository();
    late final StreamController<CommissionV2Snapshot> controller;
    final List<StreamSubscription<dynamic>> subscriptions = [];
    List<CommissionEntry>? commissions;
    List<CommissionPayout>? payouts;
    List<CommissionAccount>? accounts;

    void emit() {
      if (controller.isClosed ||
          commissions == null ||
          payouts == null ||
          accounts == null) {
        return;
      }
      controller.add(
        CommissionV2Snapshot(
          commissions: commissions!
              .map(
                (value) => CommissionV2Entry(
                  id: value.id,
                  orderId: value.orderId,
                  orderReference: value.orderReference,
                  agentId: value.agentId,
                  agentName: value.agentName,
                  network: value.network.name,
                  orderAmount: value.orderAmount,
                  commissionAmount: value.commissionAmount,
                  policyId: value.policyId,
                  policyType: value.policyType.name,
                  rate: value.rate,
                  earnedAt: value.earnedAt,
                ),
              )
              .toList(growable: false),
          payouts: payouts!
              .map(
                (value) => CommissionPayoutV2Entry(
                  id: value.id,
                  agentId: value.agentId,
                  agentName: value.agentName,
                  amount: value.amount,
                  paymentChannel: value.paymentChannel,
                  paymentReference: value.paymentReference,
                  paidAt: value.paidAt,
                  note: value.note,
                  createdByName: value.createdByName,
                ),
              )
              .toList(growable: false),
          accounts: accounts!
              .map(
                (value) => CommissionAccountV2(
                  agentId: value.agentId,
                  agentName: value.agentName,
                  earnedTotal: value.earnedTotal,
                  paidTotal: value.paidTotal,
                  earnedTransactions: value.earnedTransactions,
                  updatedAt: value.updatedAt,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    controller = StreamController<CommissionV2Snapshot>(
      onListen: () {
        subscriptions.add(
          source.watchCommissions(agentId: agentId).listen((values) {
            commissions = values;
            emit();
          }, onError: controller.addError),
        );
        subscriptions.add(
          source.watchCommissionPayouts(agentId: agentId).listen((values) {
            payouts = values;
            emit();
          }, onError: controller.addError),
        );
        subscriptions.add(
          source.watchCommissionAccounts(agentId: agentId).listen((values) {
            accounts = values;
            emit();
          }, onError: controller.addError),
        );
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      },
    );
    return controller.stream;
  }
}
