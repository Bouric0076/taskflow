import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import 'task_provider.dart';

class ProductivityStats {
  const ProductivityStats({
    required this.completedToday,
    required this.completedThisWeek,
    required this.currentStreak,
    required this.last7DaysCompletions,
  });

  final int completedToday;
  final int completedThisWeek;
  final int currentStreak;
  final List<int> last7DaysCompletions;

  factory ProductivityStats.fromTasks(
    List<Task> tasks, {
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    final completedDays = <DateTime>[];
    for (final task in tasks) {
      final completedAt = task.completedAt;
      if (completedAt == null) continue;
      completedDays.add(
        DateTime(completedAt.year, completedAt.month, completedAt.day),
      );
    }

    var completedToday = 0;
    for (final day in completedDays) {
      if (day == today) completedToday++;
    }

    var completedThisWeek = 0;
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    for (final day in completedDays) {
      if (!day.isBefore(weekStart) && !day.isAfter(today)) {
        completedThisWeek++;
      }
    }

    final last7DaysCompletions = <int>[];
    for (var i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      var count = 0;
      for (final completedDay in completedDays) {
        if (completedDay == day) count++;
      }
      last7DaysCompletions.add(count);
    }

    final completedSet = completedDays.toSet();
    final yesterday = today.subtract(const Duration(days: 1));
    DateTime? streakCursor;

    if (completedSet.contains(today)) {
      streakCursor = today;
    } else if (completedSet.contains(yesterday)) {
      streakCursor = yesterday;
    }

    var streak = 0;
    while (streakCursor != null && completedSet.contains(streakCursor)) {
      streak++;
      streakCursor = streakCursor.subtract(const Duration(days: 1));
    }

    return ProductivityStats(
      completedToday: completedToday,
      completedThisWeek: completedThisWeek,
      currentStreak: streak,
      last7DaysCompletions: last7DaysCompletions,
    );
  }
}

final productivityStatsProvider = Provider<ProductivityStats>((ref) {
  final allTasksAsync = ref.watch(allTasksProvider);
  final tasks = allTasksAsync.asData?.value ?? const <Task>[];
  return ProductivityStats.fromTasks(tasks);
});
