/// Temporary server projection. Its monotonic lease also expires while offline.
class OfferBonus {
  OfferBonus({
    required this.baseVolumeMb,
    required this.totalVolumeMb,
    required this.kind,
    required this.value,
    required Duration lease,
    Duration Function()? elapsed,
  }) : _lease = lease,
       _elapsed = elapsed ?? (Stopwatch()..start()).elapsedDuration;

  final num baseVolumeMb, totalVolumeMb, value;
  final String kind;
  final Duration _lease;
  final Duration Function() _elapsed;
  bool _invalidated = false;
  void invalidate() => _invalidated = true;
  Duration get remaining => _lease - _elapsed();
  bool get visible => !_invalidated && remaining > Duration.zero;
  String get badge => switch (kind) {
    'percentage' => '+${_number(value)} % de bonus',
    'added_mb' => '+${volume(value)} offerts',
    _ => 'Volume garanti',
  };
  static String _number(num n) =>
      (n == n.roundToDouble() ? n.toInt().toString() : n.toString()).replaceAll(
        '.',
        ',',
      );
  static String volume(num mb) => mb >= 1000
      ? '${(mb / 1000).toStringAsFixed(2).replaceAll('.', ',')} Go'
      : '${_number(mb)} Mo';
  factory OfferBonus.fromJson(
    Map<String, dynamic> row,
    DateTime serverNow, {
    Duration transportBudget = Duration.zero,
  }) {
    final until = DateTime.parse(row['valid_until'] as String);
    final lease = until.difference(serverNow) - transportBudget;
    return OfferBonus(
      baseVolumeMb: row['base_volume_mb'] as num,
      totalVolumeMb: row['total_volume_mb'] as num,
      kind: row['bonus_kind'] as String,
      value: row['bonus_value'] as num,
      lease: lease > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : lease,
    );
  }
}

extension on Stopwatch {
  Duration elapsedDuration() => elapsed;
}
