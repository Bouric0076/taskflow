import 'package:alarm/alarm.dart';

import '../../../data/database/app_database.dart';

/// Service to restore alarms that were active before app was closed
class AlarmRestorationService {
  const AlarmRestorationService(this.database);

  final AppDatabase database;

  /// Restore all alarms that were active when the app was last closed
  Future<void> restoreAlarms() async {
    try {
      final tasksWithAlarms = await database.getTasksWithActiveAlarms();

      for (final task in tasksWithAlarms) {
        // Only restore if the alarm time is still in the future
        if (task.alarmAt != null && task.alarmAt!.isAfter(DateTime.now())) {
          await _scheduleAlarmForTask(task);
        } else {
          // Mark as not scheduled if time has passed
          await database.markAlarmCancelled(task.id);
        }
      }
    } catch (e) {
      // Handle error silently - alarms will be re-scheduled on task update
    }
  }

  /// Schedule an alarm for a specific task
  Future<void> _scheduleAlarmForTask(Task task) async {
    if (task.alarmAt == null || task.alarmMode.index == 0) {
      // AlarmMode.none == 0
      return;
    }

    try {
      final alarmSettings = AlarmSettings(
        id: task.id,
        dateTime: task.alarmAt!,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 6),
        ),
        notificationSettings: NotificationSettings(
          title: 'Task: ${task.title}',
          body: task.description ?? 'Time to focus!',
          stopButton: 'Stop',
        ),
        warningNotificationOnKill: true,
        allowAlarmOverlap: false,
        payload: 'task:${task.id}',
      );

      await Alarm.set(alarmSettings: alarmSettings);
      await database.markAlarmScheduled(task.id);
    } catch (e) {
      // Silently fail - will be re-scheduled on next sync
    }
  }

  /// Cancel alarm for a specific task
  Future<void> cancelAlarmForTask(int taskId) async {
    try {
      await Alarm.stop(taskId);
      await database.markAlarmCancelled(taskId);
    } catch (e) {
      // Silently fail
    }
  }

  /// Cancel all alarms
  Future<void> cancelAllAlarms() async {
    try {
      await Alarm.stopAll();
      final tasksWithAlarms = await database.getTasksWithActiveAlarms();
      for (final task in tasksWithAlarms) {
        await database.markAlarmCancelled(task.id);
      }
    } catch (e) {
      // Silently fail
    }
  }
}
