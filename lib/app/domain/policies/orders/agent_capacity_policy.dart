class AgentCapacityPolicy {
  const AgentCapacityPolicy._();

  static int remainingAfterSuccess({
    required int currentCapacity,
    required int operationAmount,
  }) {
    if (currentCapacity <= 0) return 0;
    if (operationAmount <= 0) return currentCapacity;

    final int remaining = currentCapacity - operationAmount;
    return remaining > 0 ? remaining : 0;
  }
}
