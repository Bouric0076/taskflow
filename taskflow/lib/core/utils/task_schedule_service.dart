import 'package:alarm/alarm.dart';
import '../../data/database/app_database.dart';
import '../../data/models/task_model.dart' as model;
import '../constants/app_constants.dart';
import 'notification_service.dart';

class TaskScheduleService {
  TaskScheduleService(this._notificationService, {AppDatabase? database})
      : _database = database;

  final NotificationService _notificationService;
  final AppDatabase? _database;

  static const _maxReminderSlots = 6;

  static int reminderNotificationId(int taskId, int slot) =>
      (taskId * 100) + (slot + 1);

  static int alarmId(int taskId) => (taskId * 100) + 99;

  DateTime? resolveAlarmAnchor(Task task) {
    switch (task.alarmMode) {
      case model.AlarmMode.none:
        return null;
      case model.AlarmMode.atStart:
        return task.startDate ?? task.dueDate;
      case model.AlarmMode.atDue:
        return task.dueDate ?? task.startDate;
      case model.AlarmMode.customTime:
        return task.alarmAt ?? task.startDate ?? task.dueDate;
    }
  }

  List<int> _parseReminderOffsets(Task task) {
    if ((task.reminderOffsets ?? '').trim().isNotEmpty) {
      final values = task.reminderOffsets!
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .where((e) => e > 0)
          .toSet()
          .toList()
        ..sort();

      if (values.isNotEmpty) return values;
    }

    if (task.reminderMinutes != null && task.reminderMinutes! > 0) {
      return [task.reminderMinutes!];
    }

    return [AppConstants.defaultReminderMinutes];
  }

  Future<void> _cancelReminderNotifications(int taskId) async {
    for (var slot = 0; slot < _maxReminderSlots; slot++) {
      await _notificationService.cancelNotification(
        reminderNotificationId(taskId, slot),
      );
    }
  }

  Future<void> syncForTask(Task task) async {
    if (task.status == model.TaskStatus.completed || !task.hasAlarm) {
      await cancelForTask(task.id);
      return;
    }

    final alarmAnchor = resolveAlarmAnchor(task);
    if (alarmAnchor == null) {
      await cancelForTask(task.id);
      return;
    }

    final offsets = _parseReminderOffsets(task);

    await _cancelReminderNotifications(task.id);

    for (var slot = 0;
        slot < offsets.length && slot < _maxReminderSlots;
        slot++) {
      final minutes = offsets[slot];
      final reminderDate = alarmAnchor.subtract(Duration(minutes: minutes));
      if (!reminderDate.isAfter(DateTime.now())) continue;

      await _notificationService.scheduleTaskReminder(
        id: reminderNotificationId(task.id, slot),
        title: 'Upcoming task',
        body: '${task.title} in $minutes min',
        scheduledDate: reminderDate,
      );
    }

    await Alarm.stop(alarmId(task.id));

    if (!alarmAnchor.isAfter(DateTime.now())) {
      await _database?.markAlarmCancelled(task.id);
      return;
    }

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId(task.id),
        dateTime: alarmAnchor,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 6),
        ),
        notificationSettings: NotificationSettings(
          title: 'Task time reached',
          body: task.title,
          stopButton: 'Stop',
        ),
        warningNotificationOnKill: true,
        allowAlarmOverlap: false,
        payload: 'task:${task.id}',
      ),
    );

    // Mark alarm as scheduled in database for persistence
    await _database?.markAlarmScheduled(task.id);
  }

  Future<void> cancelForTask(int taskId) async {
    await _cancelReminderNotifications(taskId);
    await Alarm.stop(alarmId(taskId));
    // Mark alarm as cancelled in database
    await _database?.markAlarmCancelled(taskId);
  }
}
