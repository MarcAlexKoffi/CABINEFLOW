import 'package:cabine_flow/features/orders/domain/models/automatic_assignment.dart';
import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

class AutomaticAssignmentSelector {
  const AutomaticAssignmentSelector();

  List<AutomaticAssignmentAgent> rankEligible({
    required QueueOrder order,
    required Iterable<AutomaticAssignmentAgent> agents,
  }) {
    final List<AutomaticAssignmentAgent> eligible = agents
        .where(
          (AutomaticAssignmentAgent agent) => agent.canReceive(order: order),
        )
        .toList(growable: false);

    eligible.sort(_compareAgents);
    return List<AutomaticAssignmentAgent>.unmodifiable(eligible);
  }

  AutomaticAssignmentAgent? select({
    required QueueOrder order,
    required Iterable<AutomaticAssignmentAgent> agents,
  }) {
    final List<AutomaticAssignmentAgent> ranked = rankEligible(
      order: order,
      agents: agents,
    );
    return ranked.isEmpty ? null : ranked.first;
  }

  int _compareAgents(
    AutomaticAssignmentAgent first,
    AutomaticAssignmentAgent second,
  ) {
    final int active = first.activeAssignmentCount.compareTo(
      second.activeAssignmentCount,
    );
    if (active != 0) return active;

    final int today = first.todayAssignmentCount.compareTo(
      second.todayAssignmentCount,
    );
    if (today != 0) return today;

    final DateTime? firstLast = first.lastAssignedAt;
    final DateTime? secondLast = second.lastAssignedAt;
    if (firstLast == null && secondLast != null) return -1;
    if (firstLast != null && secondLast == null) return 1;
    if (firstLast != null && secondLast != null) {
      final int last = firstLast.compareTo(secondLast);
      if (last != 0) return last;
    }

    return first.agentId.compareTo(second.agentId);
  }
}
