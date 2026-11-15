import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum IzyTelPeriodPreset {
  all,
  today,
  last7Days,
  last30Days,
  currentMonth,
  custom,
}

@immutable
class IzyTelPeriodFilterValue {
  const IzyTelPeriodFilterValue({
    this.preset = IzyTelPeriodPreset.all,
    this.customRange,
  });

  final IzyTelPeriodPreset preset;
  final DateTimeRange? customRange;

  bool get isActive => preset != IzyTelPeriodPreset.all;

  IzyTelPeriodFilterValue copyWith({
    IzyTelPeriodPreset? preset,
    DateTimeRange? customRange,
    bool clearCustomRange = false,
  }) {
    return IzyTelPeriodFilterValue(
      preset: preset ?? this.preset,
      customRange: clearCustomRange ? null : customRange ?? this.customRange,
    );
  }

  DateTimeRange? resolvedRange({DateTime? now}) {
    final DateTime anchor = (now ?? DateTime.now()).toLocal();
    final DateTime today = DateTime(anchor.year, anchor.month, anchor.day);
    switch (preset) {
      case IzyTelPeriodPreset.all:
        return null;
      case IzyTelPeriodPreset.today:
        return DateTimeRange(start: today, end: _endOfDay(today));
      case IzyTelPeriodPreset.last7Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: _endOfDay(today),
        );
      case IzyTelPeriodPreset.last30Days:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: _endOfDay(today),
        );
      case IzyTelPeriodPreset.currentMonth:
        return DateTimeRange(
          start: DateTime(today.year, today.month),
          end: _endOfDay(today),
        );
      case IzyTelPeriodPreset.custom:
        final DateTimeRange? range = customRange;
        if (range == null) return null;
        return DateTimeRange(
          start: _startOfDay(range.start),
          end: _endOfDay(range.end),
        );
    }
  }

  bool contains(DateTime? value, {DateTime? now}) {
    if (value == null) return false;
    final DateTimeRange? range = resolvedRange(now: now);
    if (range == null) return true;
    final DateTime local = value.toLocal();
    return !local.isBefore(range.start) && !local.isAfter(range.end);
  }

  String get label {
    switch (preset) {
      case IzyTelPeriodPreset.all:
        return 'Toutes les périodes';
      case IzyTelPeriodPreset.today:
        return 'Aujourd’hui';
      case IzyTelPeriodPreset.last7Days:
        return '7 jours';
      case IzyTelPeriodPreset.last30Days:
        return '30 jours';
      case IzyTelPeriodPreset.currentMonth:
        return 'Ce mois';
      case IzyTelPeriodPreset.custom:
        final DateTimeRange? range = customRange;
        if (range == null) return 'Calendrier';
        return '${_shortDate(range.start)} → ${_shortDate(range.end)}';
    }
  }

  static DateTime _startOfDay(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime _endOfDay(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      23,
      59,
      59,
      999,
      999,
    );
  }

  static String _shortDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

class IzyTelPeriodFilterBar extends StatelessWidget {
  const IzyTelPeriodFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
    this.firstCalendarDate,
    this.lastCalendarDate,
    this.calendarHelpText = 'Choisir une période',
  });

  final IzyTelPeriodFilterValue value;
  final ValueChanged<IzyTelPeriodFilterValue> onChanged;
  final bool compact;
  final DateTime? firstCalendarDate;
  final DateTime? lastCalendarDate;
  final String calendarHelpText;

  static const List<IzyTelPeriodPreset> _quickPresets = <IzyTelPeriodPreset>[
    IzyTelPeriodPreset.all,
    IzyTelPeriodPreset.today,
    IzyTelPeriodPreset.last7Days,
    IzyTelPeriodPreset.last30Days,
    IzyTelPeriodPreset.currentMonth,
  ];

  Future<void> _pickCustomRange(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime lastDate = lastCalendarDate ?? DateTime(now.year, now.month, now.day);
    final DateTime firstDate = firstCalendarDate ?? DateTime(2000, 1, 1);
    DateTimeRange? initial = value.customRange;
    if (initial != null) {
      DateTime start = initial.start;
      DateTime end = initial.end;
      if (start.isBefore(firstDate)) start = firstDate;
      if (end.isAfter(lastDate)) end = lastDate;
      if (end.isBefore(start)) end = start;
      initial = DateTimeRange(start: start, end: end);
    }

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initial,
      initialEntryMode: DatePickerEntryMode.calendar,
      helpText: calendarHelpText,
      cancelText: 'Annuler',
      confirmText: 'Appliquer',
      saveText: 'Appliquer',
      fieldStartHintText: 'JJ/MM/AAAA',
      fieldEndHintText: 'JJ/MM/AAAA',
    );
    if (picked == null) return;
    onChanged(
      IzyTelPeriodFilterValue(
        preset: IzyTelPeriodPreset.custom,
        customRange: picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final List<Widget> children = <Widget>[
      for (final IzyTelPeriodPreset preset in _quickPresets)
        ChoiceChip(
          label: Text(_presetLabel(preset)),
          selected: value.preset == preset,
          onSelected: (_) => onChanged(
            IzyTelPeriodFilterValue(
              preset: preset,
              customRange: value.customRange,
            ),
          ),
        ),
      ActionChip(
        avatar: const Icon(Symbols.calendar_month_rounded, size: 18),
        label: Text(
          value.preset == IzyTelPeriodPreset.custom
              ? value.label
              : 'Calendrier',
        ),
        onPressed: () => _pickCustomRange(context),
        side: BorderSide(
          color: value.preset == IzyTelPeriodPreset.custom
              ? primary.withValues(alpha: .45)
              : Theme.of(context).dividerColor,
        ),
        backgroundColor: value.preset == IzyTelPeriodPreset.custom
            ? primary.withValues(alpha: .08)
            : null,
      ),
    ];

    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: children
              .map(
                (Widget child) => Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: child,
                ),
              )
              .toList(growable: false),
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: children);
  }

  static String _presetLabel(IzyTelPeriodPreset preset) {
    return switch (preset) {
      IzyTelPeriodPreset.all => 'Tout',
      IzyTelPeriodPreset.today => 'Aujourd’hui',
      IzyTelPeriodPreset.last7Days => '7 jours',
      IzyTelPeriodPreset.last30Days => '30 jours',
      IzyTelPeriodPreset.currentMonth => 'Ce mois',
      IzyTelPeriodPreset.custom => 'Calendrier',
    };
  }
}
