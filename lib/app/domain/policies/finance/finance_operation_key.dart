import 'dart:math';

/// One key per user intention. Keep it when retrying an uncertain response.
String createFinanceOperationKey() {
  final Random random = Random.secure();
  final String entropy = List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  return 'finance-$entropy';
}
