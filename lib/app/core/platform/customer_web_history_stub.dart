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

  CustomerWebHistoryEntry? _currentEntry;
  CustomerWebHistoryEntry? get currentEntry => _currentEntry;

  void replace(CustomerWebHistoryEntry entry) {
    _currentEntry = entry;
  }

  void push(CustomerWebHistoryEntry entry) {
    _currentEntry = entry;
  }

  void back() {}

  void dispose() {}
}

CustomerWebHistoryController createCustomerWebHistory({
  required CustomerWebHistoryPopCallback onPop,
}) {
  return CustomerWebHistoryController(onPop: onPop);
}
