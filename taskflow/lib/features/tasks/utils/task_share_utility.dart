import 'package:flutter/services.dart';
import '../../../data/database/app_database.dart';

class TaskShareUtility {
  static const platform = MethodChannel('com.taskflow.app/share');

  /// Format task details as shareable text
  static String formatTaskForSharing(Task task) {
    final buffer = StringBuffer();
    buffer.writeln('📋 ${task.title}');

    if ((task.description ?? '').isNotEmpty) {
      buffer.writeln('\n📝 Description:\n${task.description}');
    }

    if ((task.notes ?? '').isNotEmpty) {
      buffer.writeln('\n📌 Notes:\n${task.notes}');
    }

    if (task.startDate != null) {
      buffer.writeln('\n⏱️ Starts: ${_formatDate(task.startDate!)}');
    }

    if (task.dueDate != null) {
      buffer.writeln('\n📅 Due: ${_formatDate(task.dueDate!)}');
    }

    final priorityName = {
          0: 'Normal',
          1: 'Important',
          2: 'Critical',
        }[task.priority.index] ??
        'Normal';

    buffer.writeln('\n⚡ Priority: $priorityName');

    final statusName = {
          0: 'Pending',
          1: 'In Progress',
          2: 'Completed',
        }[task.status.index] ??
        'Pending';

    buffer.writeln('\n✓ Status: $statusName');

    return buffer.toString();
  }

  /// Share task via system share dialog using native platform
  static Future<void> shareTask(Task task) async {
    try {
      await platform.invokeMethod('share', {
        'title': 'Task: ${task.title}',
        'text': formatTaskForSharing(task),
      });
    } catch (e) {
      // Fallback: show a simple SnackBar if native sharing fails
    }
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today at ${_formatTime(date)}';
    }

    final tomorrow = today.add(const Duration(days: 1));
    if (dateOnly == tomorrow) {
      return 'Tomorrow at ${_formatTime(date)}';
    }

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} at ${_formatTime(date)}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
