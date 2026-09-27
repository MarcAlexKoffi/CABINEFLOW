import 'package:cabine_flow/features/orders/domain/models/queue_order.dart';

/// Règle d'affichage de la file de travail Agent.
///
/// Une commande payée depuis plus longtemps est prioritaire. On utilise la
/// confirmation de paiement comme horloge métier principale, puis `paidAt`,
/// `assignedAt` et enfin `createdAt` pour rester compatible avec les anciens
/// documents qui ne possèdent pas tous les timestamps récents.
class AgentOrderPriorityPolicy {
  const AgentOrderPriorityPolicy._();

  static DateTime prioritySince(QueueOrder order) {
    return order.paymentConfirmedAt ??
        order.paidAt ??
        order.assignedAt ??
        order.createdAt;
  }

  static List<QueueOrder> sortActiveQueue(Iterable<QueueOrder> source) {
    final List<QueueOrder> result = source.toList(growable: false);
    result.sort((QueueOrder first, QueueOrder second) {
      final int byPriority = prioritySince(
        first,
      ).compareTo(prioritySince(second));
      if (byPriority != 0) return byPriority;

      final int byCreation = first.createdAt.compareTo(second.createdAt);
      if (byCreation != 0) return byCreation;

      return first.reference.compareTo(second.reference);
    });
    return List<QueueOrder>.unmodifiable(result);
  }

  static List<QueueOrder> sortCompleted(Iterable<QueueOrder> source) {
    final List<QueueOrder> result = source.toList(growable: false);
    result.sort((QueueOrder first, QueueOrder second) {
      final DateTime firstDate =
          first.completedAt ?? first.assignedAt ?? first.createdAt;
      final DateTime secondDate =
          second.completedAt ?? second.assignedAt ?? second.createdAt;
      final int byCompletion = secondDate.compareTo(firstDate);
      if (byCompletion != 0) return byCompletion;
      return second.reference.compareTo(first.reference);
    });
    return List<QueueOrder>.unmodifiable(result);
  }
}
