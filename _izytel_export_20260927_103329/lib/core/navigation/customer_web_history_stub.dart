class CustomerWebHistoryEntry {
  const CustomerWebHistoryEntry({
    required this.location,
    required this.step,
  });

  final String location;
  final int step;

  bool matches(CustomerWebHistoryEntry other) {
    return location == other.location && step == other.step;
  }
}

typedef CustomerWebHistoryPopCallback = void Function(
  CustomerWebHistoryEntry? entry,
);

class CustomerWebHistoryController {
  CustomerWebHistoryController({required this.onPop});

  final CustomerWebHistoryPopCallback onPop;

  bool get supported => false;

  void replace(CustomerWebHistoryEntry entry) {}

  void push(CustomerWebHistoryEntry entry) {}

  void back() {}

  void dispose() {}
}

CustomerWebHistoryController createCustomerWebHistory({
  required CustomerWebHistoryPopCallback onPop,
}) {
  return CustomerWebHistoryController(onPop: onPop);
}
