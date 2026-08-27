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

    eligible.sort(
      (AutomaticAssignmentAgent first, AutomaticAssignmentAgent second) =>
          _compareAgents(order, first, second),
    );
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
    QueueOrder order,
    AutomaticAssignmentAgent first,
    AutomaticAssignmentAgent second,
  ) {
    // Une fois l'éligibilité métier validée, on privilégie une rotation
    // équitable entre les agents disponibles. L'agent jamais affecté passe
    // avant un agent déjà utilisé, puis l'affectation la plus ancienne passe
    // avant la plus récente. Cela évite qu'un même agent reçoive toutes les
    // nouvelles commandes alors qu'un autre agent est également apte.
    final DateTime? firstLast = first.lastAssignedAt;
    final DateTime? secondLast = second.lastAssignedAt;
    if (firstLast == null && secondLast != null) return -1;
    if (firstLast != null && secondLast == null) return 1;
    if (firstLast != null && secondLast != null) {
      final int last = firstLast.compareTo(secondLast);
      if (last != 0) return last;
    }

    // Si les deux agents ont la même ancienneté d'affectation, on conserve
    // les critères de charge déjà validés en 9E.
    final int active = first.activeAssignmentCount.compareTo(
      second.activeAssignmentCount,
    );
    if (active != 0) return active;

    final int today = first.todayAssignmentCount.compareTo(
      second.todayAssignmentCount,
    );
    if (today != 0) return today;

    final int todayAmount = first.todayAssignedAmount.compareTo(
      second.todayAssignedAmount,
    );
    if (todayAmount != 0) return todayAmount;

    // À égalité complète, garder la plus grande capacité réellement
    // disponible sur le réseau de la commande.
    final int availableCapacity = second
        .availableCapacityFor(order.network)
        .compareTo(first.availableCapacityFor(order.network));
    if (availableCapacity != 0) return availableCapacity;

    return first.agentId.compareTo(second.agentId);
  }
}
