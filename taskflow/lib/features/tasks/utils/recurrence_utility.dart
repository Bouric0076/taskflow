const Map<int, String> _weekdayShortLabels = {
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

const Set<int> _allWeekdays = {
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
};

Set<int> parseWeeklyRecurrenceRule(String? rule) {
  if (rule == null || rule.trim().isEmpty) return <int>{};

  return rule
      .split(',')
      .map((value) => int.tryParse(value.trim()))
      .whereType<int>()
      .where(
          (weekday) => weekday >= DateTime.monday && weekday <= DateTime.sunday)
      .toSet();
}

String? serializeWeeklyRecurrenceRule(Iterable<int> weekdays) {
  final values = weekdays
      .where(
          (weekday) => weekday >= DateTime.monday && weekday <= DateTime.sunday)
      .toSet()
      .toList()
    ..sort();

  if (values.isEmpty) return null;
  return values.join(',');
}

String formatWeeklyRecurrenceRule(String? rule) {
  final weekdays = parseWeeklyRecurrenceRule(rule).toList()..sort();
  if (weekdays.isEmpty) return 'Does not repeat';
  if (weekdays.length == 7) return 'Every day';

  return weekdays
      .map((weekday) => _weekdayShortLabels[weekday] ?? weekday.toString())
      .join(', ');
}

DateTime nextWeeklyOccurrenceAfter(
  DateTime anchor,
  Set<int> weekdays, {
  DateTime? after,
}) {
  final normalizedWeekdays = weekdays.isEmpty ? _allWeekdays : weekdays;
  final pivot = after ?? DateTime.now();
  final searchStart =
      DateTime(pivot.year, pivot.month, pivot.day).add(const Duration(days: 1));

  for (var offset = 0; offset < 14; offset++) {
    final candidateDay = searchStart.add(Duration(days: offset));
    if (!normalizedWeekdays.contains(candidateDay.weekday)) continue;

    return DateTime(
      candidateDay.year,
      candidateDay.month,
      candidateDay.day,
      anchor.hour,
      anchor.minute,
      anchor.second,
      anchor.millisecond,
      anchor.microsecond,
    );
  }

  return anchor.add(const Duration(days: 7));
}
