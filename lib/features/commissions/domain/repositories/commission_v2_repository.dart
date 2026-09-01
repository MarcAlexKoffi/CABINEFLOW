import 'package:cabine_flow/features/commissions/domain/models/commission_v2_models.dart';

abstract interface class CommissionV2Repository {
  Stream<CommissionV2Snapshot> watchAgent(String agentId);

  Stream<CommissionV2Snapshot> watchAdmin();

  Stream<CommissionV2Snapshot> watchAdminAgent(String agentId);
}
